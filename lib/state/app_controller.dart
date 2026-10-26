import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models.dart';
import '../protocol/frames.dart';
import '../services/bms_client.dart';
import '../services/history.dart';

/// 全局应用状态 (ChangeNotifier + provider)
class AppController extends ChangeNotifier {
  BmsClient? _client;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BmsEvent>? _eventSub;
  Timer? _rssiTimer;
  Timer? _reconnectTimer;

  // ---------- 连接状态 ----------
  ConnState state = ConnState.idle;
  String statusText = '';
  List<ScanResult> scanResults = [];

  /// 首次发现顺序 (稳定排序: 同设备不因 RSSI 波动而跳动)
  final Map<String, ScanResult> _seenDevices = {};
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  BluetoothDevice? targetDevice;
  String? targetName;
  int? rssi;

  /// 正在连接的设备 ID (仅该设备显示转圈)
  String? connectingId;

  /// UI 刷新节流: 数值至少间隔 5s 才推送给界面 (避免频繁闪动)
  static const Duration uiRefreshInterval = Duration(seconds: 5);
  DateTime? _lastUiNotify;

  /// 自动重连 (默认开启)
  bool autoReconnect = true;
  int _reconnectTries = 0;
  bool _userDisconnected = false;

  // ---------- 数据 ----------
  JkSnapshot? snapshot;
  JkDeviceInfo? deviceInfo;
  JkSettings? settings;
  List<JkLogEntry> logbook = [];
  final HistoryBuffer history = HistoryBuffer();

  /// 协议变体 (自动探测或手动覆盖后的生效值)
  JkVariant? variant;
  JkVariant? variantOverride;

  // ---------- 调试 ----------
  static const int maxRawFrames = 200;
  final List<RawFrameEntry> rawFrames = [];

  AppController() {
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      adapterState = s;
      notifyListeners();
    });
  }

  bool get isWeb => kIsWeb;

  bool get isConnected =>
      state == ConnState.waitingData || state == ConnState.running;

  // ---------------------------------------------------------------- 扫描

  Future<void> startScan() async {
    if (state == ConnState.scanning) return;
    state = ConnState.scanning;
    statusText = '';
    scanResults = [];
    _seenDevices.clear();
    notifyListeners();
    try {
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        // 保持首次发现顺序, 仅原地更新 RSSI -> 列表不会上下跳动
        for (final r in results) {
          _seenDevices[r.device.remoteId.str] = r;
        }
        _refreshScanList();
      });
      await FlutterBluePlus.startScan(
        // Web Bluetooth 必须带过滤器; 桌面端不过滤, 由 UI 筛选
        withServices: kIsWeb ? [Guid(JkProto.serviceUuid)] : [],
        timeout: kIsWeb ? null : const Duration(seconds: 12),
      );
      // 桌面端: 超时结束; Web: 用户在浏览器弹窗中选择/取消后结束
      if (state == ConnState.scanning) {
        state = ConnState.idle;
        notifyListeners();
      }
    } catch (e) {
      state = ConnState.error;
      statusText = '扫描失败: $e';
      notifyListeners();
    }
  }

  /// 桌面端"显示所有设备"开关 (非极空特征设备也列出)
  bool showAllDevices = false;

  void setShowAllDevices(bool v) {
    showAllDevices = v;
    _refreshScanList();
  }

  void _refreshScanList() {
    scanResults = _seenDevices.values
        .where((r) => kIsWeb || showAllDevices || isLikelyJkDevice(r))
        .toList();
    notifyListeners();
  }

  /// 极空设备识别规则 (默认过滤):
  /// 1. 广播名含 JK / BMS / JIKONG
  /// 2. 序列号式广播名 (如 6060489600004938-01, 储能系列常见)
  /// 3. 已知极空蓝牙模块 MAC 前缀 (esphome-jk-bms 实测: 旧 C8:47:8C / 新 20:21:11)
  /// 4. 广播中包含服务 UUID 0xFFE0
  /// 5. 广播厂商 ID = 0x4B4A ("JK") 或 0x0B65 (aiobmsble jikong 匹配器规则)
  static bool isLikelyJkDevice(ScanResult r) {
    final name = deviceNameOf(r).toUpperCase().trim();
    if (name.contains('JK') || name.contains('BMS') || name.contains('JIKONG')) {
      return true;
    }
    if (RegExp(r'^\d{10,}(-\d{1,2})?$').hasMatch(name)) return true;
    final mac = r.device.remoteId.str.toUpperCase();
    if (mac.startsWith('C8:47:8C') || mac.startsWith('20:21:11')) return true;
    final adv = r.advertisementData;
    if (adv.serviceUuids.contains(Guid(JkProto.serviceUuid))) return true;
    for (final id in adv.manufacturerData.keys) {
      if (id == 0x4B4A || id == 0x0B65) return true;
    }
    return false;
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (state == ConnState.scanning) {
      state = ConnState.idle;
      notifyListeners();
    }
  }

  static String deviceNameOf(ScanResult r) {
    final adv = r.advertisementData.advName;
    if (adv.isNotEmpty) return adv;
    final p = r.device.platformName;
    return p.isNotEmpty ? p : r.device.remoteId.str;
  }

  // ---------------------------------------------------------------- 连接

  Future<void> connectTo(ScanResult result) async {
    await stopScan();
    targetDevice = result.device;
    targetName = deviceNameOf(result);
    _userDisconnected = false;
    _reconnectTries = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    final device = targetDevice;
    if (device == null) return;
    state = ConnState.connecting;
    connectingId = device.remoteId.str;
    statusText = '正在连接 $targetName ...';
    _clearSessionData();
    notifyListeners();

    final client = BmsClient();
    client.decoder.variantOverride = variantOverride;
    _client = client;
    _eventSub?.cancel();
    _eventSub = client.events.listen(_onEvent);

    try {
      await client.start(device);
      connectingId = null;
      state = ConnState.waitingData;
      statusText = '已连接, 等待数据...';
      notifyListeners();
      _startRssiPolling();
    } catch (e) {
      connectingId = null;
      state = ConnState.error;
      statusText = '连接失败: ${_friendlyError(e)} (已停止, 可重新点击连接)';
      notifyListeners();
      await _cleanupClient();
      // 首次连接失败不自动重试: 停在当前页面由用户决定
    }
  }

  /// 取消正在进行的连接
  Future<void> cancelConnect() async {
    _userDisconnected = true;
    _reconnectTimer?.cancel();
    connectingId = null;
    await _cleanupClient();
    state = ConnState.idle;
    statusText = '';
    notifyListeners();
  }

  void _onEvent(BmsEvent e) {
    switch (e) {
      case SnapshotEvent(:final snapshot):
        this.snapshot = snapshot;
        variant = _client?.decoder.effectiveVariant;
        history.addFromSnapshot(snapshot);
        _reconnectTries = 0;
        final now = DateTime.now();
        final firstFrame = state != ConnState.running;
        if (firstFrame) {
          state = ConnState.running;
          statusText = '';
          _lastUiNotify = now;
          notifyListeners();
        } else if (now.difference(_lastUiNotify ?? now) >= uiRefreshInterval) {
          // 节流: 界面数值 5s 刷新一次, 避免频繁闪动 (历史采样仍按 2s 记录)
          _lastUiNotify = now;
          notifyListeners();
        }
      case DeviceInfoEvent(:final info):
        deviceInfo = info;
        notifyListeners();
      case SettingsEvent(:final settings):
        this.settings = settings;
        notifyListeners();
      case LogbookEvent(:final entries):
        logbook = entries;
        notifyListeners();
      case VariantEvent(:final variant):
        this.variant = variant;
        notifyListeners();
      case RawFrameEvent():
        rawFrames.add(RawFrameEntry(
          ts: DateTime.now(),
          direction: e.direction,
          label: e.label,
          bytes: List<int>.from(e.bytes),
        ));
        if (rawFrames.length > maxRawFrames) {
          rawFrames.removeRange(0, rawFrames.length - maxRawFrames);
        }
        notifyListeners();
      case DisconnectedEvent():
        final wasRunning = state == ConnState.running;
        connectingId = null;
        state = ConnState.idle;
        statusText = '连接已断开';
        notifyListeners();
        // 仅"连上后意外断开"才自动重连; 连接阶段的失败不重试
        if (wasRunning) _scheduleReconnect();
      case StalledEvent(:final message):
        statusText = message;
        notifyListeners();
    }
  }

  void _scheduleReconnect() {
    if (!autoReconnect || _userDisconnected || targetDevice == null) return;
    if (_reconnectTries >= 8) {
      state = ConnState.error;
      statusText = '自动重连失败 (已尝试 $_reconnectTries 次), 请手动重新连接';
      notifyListeners();
      return;
    }
    _reconnectTries++;
    final delay = switch (_reconnectTries) {
      1 => const Duration(seconds: 1),
      2 => const Duration(seconds: 2),
      <= 5 => const Duration(seconds: 5),
      _ => const Duration(seconds: 10),
    };
    state = ConnState.connecting;
    statusText = '连接断开, ${delay.inSeconds}s 后自动重连 (第 $_reconnectTries 次)...';
    notifyListeners();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_userDisconnected) _doConnect();
    });
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnectTimer?.cancel();
    _rssiTimer?.cancel();
    await _cleanupClient();
    state = ConnState.idle;
    statusText = '';
    targetDevice = null;
    targetName = null;
    connectingId = null;
    rssi = null;
    _clearSessionData();
    notifyListeners();
  }

  Future<void> _cleanupClient() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _client?.dispose();
    _client = null;
  }

  void _clearSessionData() {
    snapshot = null;
    deviceInfo = null;
    settings = null;
    logbook = [];
    variant = variantOverride;
  }

  void _startRssiPolling() {
    _rssiTimer?.cancel();
    if (kIsWeb) return;
    _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final r = await _client?.ble.readRssi();
      if (r != null && r != rssi) {
        rssi = r;
        notifyListeners();
      }
    });
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('not available') || s.contains('Adapter')) {
      return '蓝牙不可用, 请检查系统蓝牙是否开启';
    }
    if (s.contains('timeout') || s.contains('Timeout')) return '连接超时, 请靠近设备重试';
    if (s.contains('user canceled') || s.contains('UserCanceled')) {
      return '已取消选择设备';
    }
    return s;
  }

  // ---------------------------------------------------------------- 操作

  /// 手动切换协议变体 (null = 恢复自动探测)
  void setVariantOverride(JkVariant? v) {
    variantOverride = v;
    if (_client != null) {
      _client!.decoder.variantOverride = v;
      _client!.decoder.reset();
    }
    snapshot = null;
    settings = null;
    variant = v;
    notifyListeners();
    // 主动重新请求一次数据帧 (按新变体解码)
    _client?.requestCellInfo();
  }

  Future<void> refreshLogbook() async {
    await _client?.requestLogbook();
  }

  Future<void> refreshSettings() async {
    await _client?.requestSettings();
  }

  /// 说明设备为何被判定为"疑似极空" (无广播名设备的列表提示)
  static String jkMatchReason(ScanResult r) {
    final name = deviceNameOf(r).toUpperCase().trim();
    if (name.contains('JK') || name.contains('BMS') || name.contains('JIKONG')) {
      return '广播名含 JK/BMS';
    }
    if (RegExp(r'^\d{10,}(-\d{1,2})?$').hasMatch(name)) return '序列号式广播名';
    final mac = r.device.remoteId.str.toUpperCase();
    if (mac.startsWith('C8:47:8C') || mac.startsWith('20:21:11')) {
      return '极空蓝牙模块 MAC';
    }
    if (r.advertisementData.serviceUuids.contains(Guid(JkProto.serviceUuid))) {
      return '广播含服务 FFE0';
    }
    for (final id in r.advertisementData.manufacturerData.keys) {
      if (id == 0x4B4A || id == 0x0B65) return '极空厂商 ID';
    }
    return '';
  }

  void setAutoReconnect(bool v) {
    autoReconnect = v;
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  void clearRawFrames() {
    rawFrames.clear();
    notifyListeners();
  }

  /// 导出历史 CSV, 返回保存路径 (取消/失败返回 null)
  Future<String?> exportCsv() async {
    final csv = history.toCsv();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    try {
      final location = await getSaveLocation(
        suggestedName: 'jk_bms_history_$stamp.csv',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv'])
        ],
      );
      if (location == null) return null;
      // BOM 前缀保证 Excel 正确识别 UTF-8 中文
      final bytes = Uint8List.fromList(utf8.encode('﻿$csv'));
      if (kIsWeb) {
        final name = 'jk_bms_history_$stamp.csv';
        final file =
            XFile.fromData(bytes, mimeType: 'text/csv', name: name);
        await file.saveTo(location.path);
        return name;
      }
      await File(location.path).writeAsBytes(bytes);
      return location.path;
    } catch (e) {
      statusText = 'CSV 导出失败: $e';
      notifyListeners();
      return null;
    }
  }

  String get platformHint {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'other';
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _rssiTimer?.cancel();
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _client?.dispose();
    super.dispose();
  }
}
