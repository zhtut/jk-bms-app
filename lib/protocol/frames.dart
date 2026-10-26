import 'dart:typed_data';

/// JK BMS 新版 BLE 协议常量与帧处理。
///
/// 协议参考: syssi/esphome-jk-bms (main) components/jk_bms_ble
/// - 命令帧 (App -> BMS): 20 字节, 帧头 AA 55 90 EB, 求和 CRC
/// - 响应帧 (BMS -> App): 300 字节, 帧头 55 AA EB 90, CRC 位于 byte[299]
class JkProto {
  JkProto._();

  /// BLE 服务 UUID (16-bit 0xFFE0)
  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';

  /// BLE 特征 UUID (16-bit 0xFFE1), 写命令与通知共用此 UUID
  static const String charUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // 命令字
  static const int cmdCellInfo = 0x96; // 请求/订阅电芯信息帧
  static const int cmdDeviceInfo = 0x97; // 请求设备信息帧
  static const int cmdLogbook = 0xA1; // 请求日志帧

  // 响应帧类型 (byte[4])
  static const int frameSettings = 0x01;
  static const int frameCellInfo = 0x02;
  static const int frameDeviceInfo = 0x03;
  static const int frameLogbook = 0x05;

  static const int frameSize = 300;
  static const List<int> respPreamble = [0x55, 0xAA, 0xEB, 0x90];
}

/// 求和校验: sum(bytes[0..len-1]) mod 256
int jkCrc(List<int> data, [int len = -1]) {
  final n = len < 0 ? data.length : len;
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = (s + data[i]) & 0xFF;
  }
  return s;
}

/// 构造 20 字节命令帧 (AA 55 90 EB + 命令字 + 长度 + u32 LE 值 + CRC)
Uint8List jkBuildCommand(int address, {int value = 0, int length = 0}) {
  final f = Uint8List(20);
  f[0] = 0xAA;
  f[1] = 0x55;
  f[2] = 0x90;
  f[3] = 0xEB;
  f[4] = address & 0xFF;
  f[5] = length & 0xFF;
  f[6] = value & 0xFF;
  f[7] = (value >> 8) & 0xFF;
  f[8] = (value >> 16) & 0xFF;
  f[9] = (value >> 24) & 0xFF;
  f[19] = jkCrc(f, 19);
  return f;
}

/// 帧组装器: BLE 通知为分包数据 (20~512 字节/包), 需重组为完整 300 字节帧。
///
/// 策略与 esphome-jk-bms 一致并做了增强:
/// - 分包开头出现帧头 55 AA EB 90 时清空残留缓冲 (防脏数据累积)
/// - 缓冲内滑动查找帧头, 凑满 300 字节后校验 CRC
/// - CRC 失败时跳过该帧头继续扫描 (而不是丢弃全部缓冲)
/// - 缓冲超过 4KB 强制清空 (防泄漏)
class JkFrameAssembler {
  static const int _maxBuf = 4096;
  final List<int> _buf = [];

  /// 喂入一个通知分包, 返回本次组装出的完整帧 (0..n 个)
  List<Uint8List> feed(List<int> chunk) {
    final out = <Uint8List>[];
    if (chunk.length >= 4 &&
        chunk[0] == 0x55 &&
        chunk[1] == 0xAA &&
        chunk[2] == 0xEB &&
        chunk[3] == 0x90) {
      _buf.clear();
    }
    _buf.addAll(chunk);
    if (_buf.length > _maxBuf) {
      _buf.clear();
      return out;
    }
    while (true) {
      final idx = _findPreamble();
      if (idx < 0) {
        // 无帧头: 仅保留末尾 3 字节 (帧头可能跨包被截断)
        if (_buf.length > 3) {
          _buf.removeRange(0, _buf.length - 3);
        }
        break;
      }
      if (idx > 0) {
        _buf.removeRange(0, idx);
        continue;
      }
      if (_buf.length < JkProto.frameSize) break; // 等待更多分包
      if (jkCrc(_buf, JkProto.frameSize - 1) == _buf[JkProto.frameSize - 1]) {
        out.add(Uint8List.fromList(_buf.sublist(0, JkProto.frameSize)));
        _buf.removeRange(0, JkProto.frameSize);
        // 继续循环: 缓冲中可能粘连了下一帧 (部分设备发 320 字节, 尾部 20 字节垃圾
        // 会在下一次帧头查找时被丢弃)
      } else {
        // CRC 失败: 该"帧头"是数据中的巧合, 跳过 4 字节重新扫描
        _buf.removeRange(0, 4);
      }
    }
    return out;
  }

  void reset() => _buf.clear();

  int get bufferedBytes => _buf.length;

  int _findPreamble() {
    for (int i = 0; i + 3 < _buf.length; i++) {
      if (_buf[i] == 0x55 &&
          _buf[i + 1] == 0xAA &&
          _buf[i + 2] == 0xEB &&
          _buf[i + 3] == 0x90) {
        return i;
      }
    }
    return -1;
  }
}
