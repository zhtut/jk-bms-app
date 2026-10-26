import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol/frames.dart';

/// flutter_blue_plus 封装: 连接 JK BMS、发现 FFE0/FFE1、订阅通知、写命令。
///
/// 说明:
/// - 新蓝牙模块 (MAC 20:21:11:xx): FFE1 有两个实例, handle 3 可写 / handle 5 可通知
/// - 旧蓝牙模块 (MAC C8:47:8C:xx): 单个 FFE1 同时可写+通知
/// 因此按"属性"选择特征, 不硬编码 handle。
class BleService {
  final _rx = StreamController<List<int>>.broadcast();
  final _connEvents = StreamController<bool>.broadcast();

  /// 通知特征收到的原始字节流 (未组帧)
  Stream<List<int>> get received => _rx.stream;

  /// 连接状态变化 (true=已连接 false=已断开)
  Stream<bool> get connectionEvents => _connEvents.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool get isConnected => _device?.isConnected ?? false;

  /// 连接并完成 GATT 发现 + 订阅通知
  Future<void> connectToDevice(BluetoothDevice device) async {
    _device = device;
    await device.connect(
      license: License.nonprofit, // 个人/非商业用途 (FlutterBluePlus License)
      timeout: const Duration(seconds: 20),
      mtu: null, // 桌面端不支持 requestMtu; 分包由帧组装器处理
    );
    _connSub = device.connectionState.listen((s) {
      _connEvents.add(s == BluetoothConnectionState.connected);
    });

    final services = await device.discoverServices();
    BluetoothService? svc;
    for (final s in services) {
      if (s.uuid == Guid(JkProto.serviceUuid)) {
        svc = s;
        break;
      }
    }
    if (svc == null) {
      throw Exception('未找到 JK BMS 服务 (0xFFE0), 该设备可能不是极空保护板');
    }

    for (final c in svc.characteristics) {
      if (c.uuid != Guid(JkProto.charUuid)) continue;
      final p = c.properties;
      if ((p.notify || p.indicate) && _notifyChar == null) _notifyChar = c;
      if ((p.write || p.writeWithoutResponse) && _writeChar == null) {
        _writeChar = c;
      }
    }
    if (_notifyChar == null) {
      throw Exception('未找到通知特征 (0xFFE1)');
    }

    await _notifyChar!.setNotifyValue(true);
    _notifySub = _notifyChar!.onValueReceived.listen((v) => _rx.add(v));
  }

  /// 写 20 字节命令帧。优先 writeWithoutResponse (与官方 App / esphome 行为一致),
  /// 特征不支持时回退 writeWithResponse。
  Future<void> writeCommand(List<int> bytes) async {
    final w = _writeChar ?? _notifyChar;
    if (w == null) throw Exception('无可写特征');
    await w.write(bytes, withoutResponse: w.properties.writeWithoutResponse);
  }

  Future<int?> readRssi() async {
    try {
      return await _device?.readRssi();
    } catch (_) {
      return null; // Web / 部分平台不支持
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _notifySub = null;
    _connSub = null;
    try {
      await _notifyChar?.setNotifyValue(false);
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _writeChar = null;
    _notifyChar = null;
  }

  void dispose() {
    disconnect();
    _rx.close();
    _connEvents.close();
  }
}
