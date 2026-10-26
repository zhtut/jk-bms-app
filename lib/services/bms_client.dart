import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models.dart';
import '../protocol/decoder.dart';
import '../protocol/frames.dart';
import 'ble_service.dart';

/// BmsClient 事件
sealed class BmsEvent {}

class SnapshotEvent extends BmsEvent {
  SnapshotEvent(this.snapshot);
  final JkSnapshot snapshot;
}

class DeviceInfoEvent extends BmsEvent {
  DeviceInfoEvent(this.info);
  final JkDeviceInfo info;
}

class SettingsEvent extends BmsEvent {
  SettingsEvent(this.settings);
  final JkSettings settings;
}

class LogbookEvent extends BmsEvent {
  LogbookEvent(this.entries);
  final List<JkLogEntry> entries;
}

class VariantEvent extends BmsEvent {
  VariantEvent(this.variant);
  final JkVariant variant;
}

class RawFrameEvent extends BmsEvent {
  RawFrameEvent(this.direction, this.label, this.bytes);
  final String direction; // rx / tx / drop
  final String label;
  final List<int> bytes;
}

class DisconnectedEvent extends BmsEvent {}

class StalledEvent extends BmsEvent {
  StalledEvent(this.message);
  final String message;
}

/// BMS 会话编排: 握手、请求重试、断流看门狗、帧组装、解码、事件分发。
class BmsClient {
  BmsClient({BleService? ble, JkDecoder? decoder})
      : ble = ble ?? BleService(),
        decoder = decoder ?? JkDecoder();

  final BleService ble;
  final JkDecoder decoder;
  final _assembler = JkFrameAssembler();
  final _events = StreamController<BmsEvent>.broadcast();

  Stream<BmsEvent> get events => _events.stream;

  StreamSubscription<List<int>>? _rxSub;
  StreamSubscription<bool>? _connSub;
  Timer? _retryTimer;
  Timer? _watchdogTimer;
  Timer? _logbookTimer;
  Timer? _settingsTimer1;
  Timer? _settingsTimer2;

  DateTime? _lastFrameAt;
  int _cellInfoRequests = 0;
  bool _gotCellInfo = false;
  bool _gotSettings = false;
  bool _stopped = false;

  /// 连接并开始会话
  Future<void> start(BluetoothDevice device) async {
    _stopped = false;
    _gotCellInfo = false;
    _cellInfoRequests = 0;
    _lastFrameAt = null;
    _assembler.reset();
    decoder.reset();

    await ble.connectToDevice(device);

    _rxSub = ble.received.listen(_onBytes);
    _connSub = ble.connectionEvents.listen((up) {
      if (!up && !_stopped) {
        _events.add(DisconnectedEvent());
      }
    });

    // 握手: 设备信息 -> 电芯信息
    await _send(JkProto.cmdDeviceInfo, '请求设备信息');
    await _send(JkProto.cmdCellInfo, '请求电芯数据');
    _cellInfoRequests = 1;

    // 重试: 未收到电芯帧前每 2.5s 重发 0x96 (最多 12 次)
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (_stopped || _gotCellInfo) {
        _retryTimer?.cancel();
        return;
      }
      if (_cellInfoRequests < 12) {
        _cellInfoRequests++;
        _send(JkProto.cmdCellInfo, '请求电芯数据(重试$_cellInfoRequests)');
      } else {
        _retryTimer?.cancel();
        _events.add(StalledEvent(
            '连接成功但长时间未收到数据帧。请在"设备"页尝试切换协议变体, 或在"调试"页查看原始字节。'));
      }
    });

    // 看门狗: 数据流中断 >15s 时重新请求
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_stopped || !_gotCellInfo) return;
      final last = _lastFrameAt;
      if (last != null && DateTime.now().difference(last) > const Duration(seconds: 15)) {
        _send(JkProto.cmdCellInfo, '看门狗重发数据请求');
      }
    });

    // 3s 后请求一次日志 (部分固件不支持, 失败忽略)
    _logbookTimer?.cancel();
    _logbookTimer = Timer(const Duration(seconds: 3), () {
      if (!_stopped) _send(JkProto.cmdLogbook, '请求日志');
    });

    // 参数帧 (0x01) 需要在数据流建立后再次发送 0x96 才会返回
    // (batmon-ha 实测行为: 流期间 0x96 的应答为 0x01 设置帧)
    _settingsTimer1?.cancel();
    _settingsTimer2?.cancel();
    _settingsTimer1 = Timer(const Duration(milliseconds: 1500), () {
      if (!_stopped && !_gotSettings) _send(JkProto.cmdCellInfo, '查询参数帧');
    });
    _settingsTimer2 = Timer(const Duration(seconds: 5), () {
      if (!_stopped && !_gotSettings) _send(JkProto.cmdCellInfo, '查询参数帧(重试)');
    });
  }

  Future<void> requestLogbook() => _send(JkProto.cmdLogbook, '手动请求日志');

  /// 手动请求参数帧 (流期间发 0x96, 应答 0x01)
  Future<void> requestSettings() => _send(JkProto.cmdCellInfo, '手动查询参数帧');

  /// 变体切换后主动重新请求电芯数据帧
  Future<void> requestCellInfo() =>
      _send(JkProto.cmdCellInfo, '重新请求电芯数据');

  Future<void> _send(int cmd, String label) async {
    final frame = jkBuildCommand(cmd);
    try {
      await ble.writeCommand(frame);
      _events.add(RawFrameEvent('tx', label, frame));
    } catch (e) {
      _events.add(RawFrameEvent('drop', '$label 失败: $e', frame));
    }
  }

  void _onBytes(List<int> chunk) {
    _lastFrameAt = DateTime.now();
    final frames = _assembler.feed(chunk);
    if (frames.isEmpty && chunk.isNotEmpty) {
      // 分包中间数据, 不逐包记录避免刷屏; 组装失败丢弃时由 assembler 内部处理
      return;
    }
    for (final f in frames) {
      final type = f[4];
      final label = switch (type) {
        JkProto.frameSettings => '参数帧(0x01)',
        JkProto.frameCellInfo => '电芯信息帧(0x02)',
        JkProto.frameDeviceInfo => '设备信息帧(0x03)',
        JkProto.frameLogbook => '日志帧(0x05)',
        _ => '未知帧(0x${type.toRadixString(16)})',
      };
      _events.add(RawFrameEvent('rx', label, f));

      final res = decoder.decode(f);
      if (res.variantJustDetected && res.variant != null) {
        _events.add(VariantEvent(res.variant!));
      }
      if (res.snapshot != null) {
        _gotCellInfo = true;
        _events.add(SnapshotEvent(res.snapshot!));
      }
      if (res.deviceInfo != null) _events.add(DeviceInfoEvent(res.deviceInfo!));
      if (res.settings != null) {
        _gotSettings = true;
        _events.add(SettingsEvent(res.settings!));
      }
      if (res.logbook != null) _events.add(LogbookEvent(res.logbook!));
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _retryTimer?.cancel();
    _watchdogTimer?.cancel();
    _logbookTimer?.cancel();
    _settingsTimer1?.cancel();
    _settingsTimer2?.cancel();
    await _rxSub?.cancel();
    await _connSub?.cancel();
    _rxSub = null;
    _connSub = null;
    await ble.disconnect();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}
