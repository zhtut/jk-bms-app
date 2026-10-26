import 'dart:typed_data';

import '../models.dart';
import 'frames.dart';

/// 帧解码结果 (一次 decode 只会有一个非空字段)
class JkDecodeResult {
  JkSnapshot? snapshot;
  JkDeviceInfo? deviceInfo;
  JkSettings? settings;
  List<JkLogEntry>? logbook;

  /// 本次解码使用的变体 (电芯/参数帧)
  JkVariant? variant;
  bool variantJustDetected = false;
}

/// JK BMS 新版 BLE 协议解码器 (300 字节帧, 帧头 55 AA EB 90)。
///
/// 支持三种帧变体并自动探测:
/// - JK02_24S: 电芯电压 u16 mV, 24 串布局
/// - JK02_32S: 电芯电压 u16 mV, 32 串布局 (字段整体后移 16/32 字节, PB 储能系列)
/// - JK04:     电芯电压 IEEE754 float32 (新款硬件)
///
/// 解码表逐字节移植自 syssi/esphome-jk-bms (main) components/jk_bms_ble。
class JkDecoder {
  /// 手动覆盖变体 (null = 自动探测)
  JkVariant? variantOverride;

  /// 自动探测结果 (粘滞: 探测一次后不再改变, 除非手动覆盖)
  JkVariant? detectedVariant;

  JkVariant? get effectiveVariant => variantOverride ?? detectedVariant;

  void reset() {
    detectedVariant = null;
  }

  /// 解码一个已通过 CRC 校验的 300 字节帧
  JkDecodeResult decode(Uint8List frame) {
    final res = JkDecodeResult();
    if (frame.length < JkProto.frameSize) return res;
    final bd = ByteData.sublistView(frame);
    switch (frame[4]) {
      case JkProto.frameCellInfo:
        JkVariant v;
        if (effectiveVariant != null) {
          v = effectiveVariant!;
        } else {
          v = detectCellInfoVariant(bd);
          detectedVariant = v;
          res.variantJustDetected = true;
        }
        res.variant = v;
        res.snapshot = v == JkVariant.jk04
            ? _decodeJk04CellInfo(bd, frame[5])
            : _decodeJk02CellInfo(bd, v, frame[5]);
      case JkProto.frameDeviceInfo:
        res.deviceInfo = _decodeDeviceInfo(bd);
      case JkProto.frameSettings:
        JkVariant v;
        if (effectiveVariant != null) {
          v = effectiveVariant!;
        } else if (_isJk04Settings(bd)) {
          // JK04 float 特征是强信号, 可直接确定变体
          v = JkVariant.jk04;
          detectedVariant = v;
          res.variantJustDetected = true;
        } else {
          // JK02 参数帧 24S/32S 布局一致, 此处不粘滞探测结果, 等电芯帧再判定
          v = JkVariant.jk02_24s;
        }
        res.variant = v;
        res.settings = v == JkVariant.jk04
            ? _decodeJk04Settings(bd)
            : _decodeJk02Settings(bd);
      case JkProto.frameLogbook:
        res.logbook = _decodeLogbook(bd);
    }
    return res;
  }

  // ---------------------------------------------------------------- 变体探测

  /// 根据电芯信息帧内容探测变体 (多因子打分)。
  static JkVariant detectCellInfoVariant(ByteData bd) {
    // 1) JK04: 电芯电压为 float32, 合理区间 [1.5, 5.0] V
    int okFloats = 0;
    for (int i = 0; i < 24; i++) {
      final v = bd.getFloat32(6 + i * 4, Endian.little);
      if (v.isFinite && v >= 1.5 && v <= 5.0) okFloats++;
    }
    if (okFloats >= 4) return JkVariant.jk04;

    // 2) JK02_24S vs JK02_32S 打分
    final s24 = _scoreJk02(bd, false);
    final s32 = _scoreJk02(bd, true);
    if (s32 > s24) return JkVariant.jk02_32s;
    return JkVariant.jk02_24s;
  }

  static int _scoreJk02(ByteData bd, bool is32) {
    final o1 = is32 ? 16 : 0; // 电芯区偏移
    final o2 = is32 ? 32 : 0; // 数据区偏移
    final slots = is32 ? 32 : 24;
    int score = 0;

    // 使能位掩码应为从 bit0 起的连续 1
    final mask = bd.getUint32(54 + o1, Endian.little);
    final n = _popcount(mask);
    final contiguous =
        n > 0 && n <= slots && mask == (n >= 32 ? 0xFFFFFFFF : ((1 << n) - 1));
    score += contiguous ? 3 : -3;

    // 前 n 串电压应在 500..4500 mV
    int ok = 0;
    int sumMv = 0;
    for (int i = 0; i < n && i < slots; i++) {
      final mv = bd.getUint16(6 + i * 2, Endian.little);
      if (mv >= 500 && mv <= 4500) {
        ok++;
        sumMv += mv;
      }
    }
    if (n > 0 && ok == n) {
      score += 2;
    } else {
      score -= 2;
    }

    // 总压字段应与电芯之和一致 (±5%)
    final total = bd.getUint32(118 + o2, Endian.little);
    if (n > 0 && total > 0 && sumMv > 0) {
      final rel = (total - sumMv).abs() / total;
      score += rel < 0.05 ? 3 : -2;
    }

    // SOC / SOH 应 <= 100
    score += bd.getUint8(141 + o2) <= 100 ? 1 : -1;
    score += bd.getUint8(158 + o2) <= 100 ? 1 : -1;
    return score;
  }

  /// 参数帧变体探测: JK04 为 float32 (电芯过压 ~2.5-4.5V), JK02 为 u32 mV
  static bool _isJk04Settings(ByteData bd) {
    final f = bd.getFloat32(18, Endian.little);
    if (f.isFinite && f >= 2.5 && f <= 4.5) return true;
    // 两种特征都不匹配时按 JK02 处理 (布局兼容性更好)
    return false;
  }

  static int _popcount(int v) {
    int c = 0;
    for (int i = 0; i < 32; i++) {
      c += (v >> i) & 1;
    }
    return c;
  }

  // ------------------------------------------------------------ 电芯信息帧

  /// JK02 (24S/32S) 电芯信息帧。o1: 电芯区偏移, o2: 数据区偏移。
  JkSnapshot _decodeJk02CellInfo(ByteData bd, JkVariant v, int counter) {
    final is32 = v == JkVariant.jk02_32s;
    final o1 = is32 ? 16 : 0;
    final o2 = is32 ? 32 : 0;
    final slots = is32 ? 32 : 24;
    final s = JkSnapshot(
      ts: DateTime.now(),
      variant: v,
    )..frameCounter = counter;

    // 温度传感器缺失掩码 (bit0=MOS, bit1..5=传感器1..5)。
    // 与 esphome 行为一致: 仅记录掩码, 温度值照常解析展示。
    s.tempSensorsMissingMask = bd.getUint16(182 + o2, Endian.little);
    double tempAt(int offset) => bd.getInt16(offset, Endian.little) * 0.1;

    // 电芯电压 / 内阻
    double min = double.infinity, max = double.negativeInfinity, sum = 0;
    int minNo = 0, maxNo = 0, active = 0;
    for (int i = 0; i < slots; i++) {
      final mv = bd.getUint16(6 + i * 2, Endian.little);
      final volts = mv > 0 ? mv * 0.001 : null;
      s.cellVoltages.add(volts);
      final rM = bd.getUint16(64 + o1 + i * 2, Endian.little);
      s.cellResistances.add(rM * 0.001);
      if (volts != null) {
        active++;
        sum += volts;
        if (volts < min) {
          min = volts;
          minNo = i + 1;
        }
        if (volts > max) {
          max = volts;
          maxNo = i + 1;
        }
      }
    }
    s.activeCellCount = active;
    if (active > 0) {
      s.minCellVoltage = min;
      s.maxCellVoltage = max;
      s.avgCellVoltage = sum / active;
      s.deltaCellVoltage = max - min;
      s.minCellNumber = minNo;
      s.maxCellNumber = maxNo;
    }

    s.totalVoltage = bd.getUint32(118 + o2, Endian.little) * 0.001;
    // 电流 i32 mA, 正=充电 (不使用 122 处的无符号功率字段)
    s.current = bd.getInt32(126 + o2, Endian.little) * 0.001;
    s.power = (s.totalVoltage ?? 0) * (s.current ?? 0);
    s.temp1 = tempAt(130 + o2);
    s.temp2 = tempAt(132 + o2);
    if (is32) {
      s.errorsBitmask = bd.getUint32(134 + o2, Endian.little);
      s.mosTemp = tempAt(112 + o2); // 绝对位置 144
      s.temp5 = tempAt(222 + o2);
      s.temp4 = tempAt(224 + o2);
      s.temp3 = tempAt(226 + o2);
      s.batteryTypeId = bd.getUint8(243 + o2);
      s.chargeStatusSeconds = bd.getUint16(246 + o2, Endian.little);
      s.chargeStatusId = bd.getUint8(248 + o2);
      final dry = bd.getUint8(249 + o2);
      s.dryContact1 = (dry & 0x02) != 0;
      s.dryContact2 = (dry & 0x04) != 0;
    } else {
      s.mosTemp = tempAt(134);
      s.errorsBitmask = bd.getUint16(136, Endian.little);
    }
    s.balanceCurrent = bd.getInt16(138 + o2, Endian.little) * 0.001;
    s.balanceAction = bd.getUint8(140 + o2);
    s.soc = bd.getUint8(141 + o2);
    s.remainingCapacityAh = bd.getUint32(142 + o2, Endian.little) * 0.001;
    s.nominalCapacityAh = bd.getUint32(146 + o2, Endian.little) * 0.001;
    s.cycleCount = bd.getUint32(150 + o2, Endian.little);
    s.cycleCapacityAh = bd.getUint32(154 + o2, Endian.little) * 0.001;
    s.soh = bd.getUint8(158 + o2);
    s.runtimeSeconds = bd.getUint32(162 + o2, Endian.little);
    s.chargeMosOn = bd.getUint8(166 + o2) != 0;
    s.dischargeMosOn = bd.getUint8(167 + o2) != 0;
    s.precharging = bd.getUint8(168 + o2) != 0;
    s.balancerWorking = bd.getUint8(169 + o2) != 0;
    s.heating = bd.getUint8(183 + o2) != 0;
    s.emergencyCountdown = bd.getUint16(186 + o2, Endian.little);
    s.heatingCurrent = bd.getInt16(204 + o2, Endian.little) * 0.001;
    s.chargerConnected = bd.getUint8(213 + o2) != 0;
    return s;
  }

  /// JK04 电芯信息帧 (float32 布局)。
  /// 注: 电流/温度/SOC 等字段社区尚未完全逆向, 保留 null; 可用调试页原始帧继续分析。
  JkSnapshot _decodeJk04CellInfo(ByteData bd, int counter) {
    final s = JkSnapshot(ts: DateTime.now(), variant: JkVariant.jk04)
      ..frameCounter = counter;
    double min = double.infinity, max = double.negativeInfinity, sum = 0;
    int minNo = 0, maxNo = 0, active = 0;
    for (int i = 0; i < 24; i++) {
      final v = bd.getFloat32(6 + i * 4, Endian.little);
      final volts = v.isFinite && v > 0.01 && v < 100 ? v : null;
      s.cellVoltages.add(volts);
      final r = bd.getFloat32(102 + i * 4, Endian.little);
      s.cellResistances.add(r.isFinite && r >= 0 && r < 1000 ? r : null);
      if (volts != null) {
        active++;
        sum += volts;
        if (volts < min) {
          min = volts;
          minNo = i + 1;
        }
        if (volts > max) {
          max = volts;
          maxNo = i + 1;
        }
      }
    }
    s.activeCellCount = active;
    if (active > 0) {
      s.minCellVoltage = min;
      s.maxCellVoltage = max;
      s.avgCellVoltage = sum / active;
      s.deltaCellVoltage = max - min;
      s.minCellNumber = minNo;
      s.maxCellNumber = maxNo;
      s.totalVoltage = sum; // JK04 帧无总压字段, 取电芯之和
    }
    s.balanceAction = bd.getUint8(220);
    final bc = bd.getFloat32(222, Endian.little);
    s.balanceCurrent = bc.isFinite ? bc : null;
    s.runtimeSeconds = bd.getUint32(286, Endian.little);
    return s;
  }

  // ---------------------------------------------------------------- 设备信息

  JkDeviceInfo _decodeDeviceInfo(ByteData bd) {
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    final d = JkDeviceInfo()
      ..model = _ascii(bytes, 6, 16)
      ..hwVersion = _ascii(bytes, 22, 8)
      ..swVersion = _ascii(bytes, 30, 8)
      ..uptimeSeconds = bd.getUint32(38, Endian.little)
      ..powerOnCount = bd.getUint32(42, Endian.little)
      ..name = _ascii(bytes, 46, 16)
      ..passcode = _ascii(bytes, 62, 16);
    // 注意: 部分固件批次在 byte 78 之后的字段存在 1 字节偏移
    // (真实抓包显示生产日期在 79、序列号在 87, esphome 参考实现取 78/86)。
    // 这里对候选偏移逐一尝试, 取有效内容。
    final mfg = _firstNonEmpty(bytes, [78, 79], 6, digitsOnly: true);
    d.mfgDate = mfg.isEmpty ? '' : '20$mfg';
    d.serial = _firstNonEmpty(bytes, [86, 87], 11, digitsOnly: true);
    d.userData = _firstNonEmpty(bytes, [102, 103], 16);
    return d;
  }

  static String _ascii(Uint8List data, int start, int len) {
    final end = data.indexOf(0, start);
    final stop = (end == -1 || end > start + len) ? start + len : end;
    if (stop <= start) return '';
    return String.fromCharCodes(data.sublist(start, stop)).trim();
  }

  static String _firstNonEmpty(Uint8List data, List<int> candidates, int len,
      {bool digitsOnly = false}) {
    for (final off in candidates) {
      final s = _ascii(data, off, len);
      if (s.isEmpty) continue;
      if (digitsOnly && !RegExp(r'^[0-9]+$').hasMatch(s)) continue;
      return s;
    }
    return '';
  }

  // ---------------------------------------------------------------- 参数帧

  JkSettings _decodeJk02Settings(ByteData bd) {
    final s = JkSettings()
      ..variant = JkVariant.jk02_24s
      ..smartSleepVoltage = bd.getUint32(6, Endian.little) * 0.001
      ..cellUvp = bd.getUint32(10, Endian.little) * 0.001
      ..cellUvpRecovery = bd.getUint32(14, Endian.little) * 0.001
      ..cellOvp = bd.getUint32(18, Endian.little) * 0.001
      ..cellOvpRecovery = bd.getUint32(22, Endian.little) * 0.001
      ..balanceTriggerVoltage = bd.getUint32(26, Endian.little) * 0.001
      ..soc100Voltage = bd.getUint32(30, Endian.little) * 0.001
      ..soc0Voltage = bd.getUint32(34, Endian.little) * 0.001
      ..requestChargeVoltage = bd.getUint32(38, Endian.little) * 0.001
      ..requestFloatVoltage = bd.getUint32(42, Endian.little) * 0.001
      ..powerOffVoltage = bd.getUint32(46, Endian.little) * 0.001
      ..maxChargeCurrent = bd.getUint32(50, Endian.little) * 0.001
      ..chargeOcpDelaySeconds = bd.getUint32(54, Endian.little)
      ..chargeOcpRecoverySeconds = bd.getUint32(58, Endian.little)
      ..maxDischargeCurrent = bd.getUint32(62, Endian.little) * 0.001
      ..dischargeOcpDelaySeconds = bd.getUint32(66, Endian.little)
      ..dischargeOcpRecoverySeconds = bd.getUint32(70, Endian.little)
      ..shortCircuitRecoverySeconds = bd.getUint32(74, Endian.little)
      ..maxBalanceCurrent = bd.getUint32(78, Endian.little) * 0.001
      ..chargeOtp = bd.getUint32(82, Endian.little) * 0.1
      ..chargeOtpRecovery = bd.getUint32(86, Endian.little) * 0.1
      ..dischargeOtp = bd.getUint32(90, Endian.little) * 0.1
      ..dischargeOtpRecovery = bd.getUint32(94, Endian.little) * 0.1
      ..chargeUtp = bd.getInt32(98, Endian.little) * 0.1
      ..chargeUtpRecovery = bd.getInt32(102, Endian.little) * 0.1
      ..mosOtp = bd.getInt32(106, Endian.little) * 0.1
      ..mosOtpRecovery = bd.getInt32(110, Endian.little) * 0.1
      ..cellCount = bd.getUint8(114)
      ..chargeSwitch = bd.getUint8(118) != 0
      ..dischargeSwitch = bd.getUint8(122) != 0
      ..balancerSwitch = bd.getUint8(126) != 0
      ..nominalCapacityAh = bd.getUint32(130, Endian.little) * 0.001
      ..shortCircuitDelayMicros = bd.getUint32(134, Endian.little)
      ..balanceStartVoltage = bd.getUint32(138, Endian.little) * 0.001
      ..deviceAddress = bd.getUint8(270)
      ..prechargeTimeSeconds = bd.getUint8(274)
      ..controlsBitmask = bd.getUint16(282, Endian.little)
      ..heatingStartTempC = bd.getInt8(284)
      ..heatingStopTempC = bd.getInt8(285)
      ..smartSleepHours = bd.getUint8(286)
      ..dischargeUtp = bd.getInt8(296).toDouble()
      ..dischargeUtpRecovery = bd.getInt8(297).toDouble();

    final wires = <double>[];
    for (int i = 0; i < 32; i++) {
      wires.add(bd.getUint32(142 + i * 4, Endian.little) * 0.001);
    }
    s.wireResistances = wires;
    return s;
  }

  JkSettings _decodeJk04Settings(ByteData bd) {
    return JkSettings()
      ..variant = JkVariant.jk04
      ..cellCount = bd.getUint8(34)
      ..powerOffVoltage = bd.getFloat32(38, Endian.little)
      ..voltageCalibration = bd.getFloat32(74, Endian.little)
      ..balanceStartVoltage = bd.getFloat32(98, Endian.little)
      ..balanceTriggerVoltage = bd.getFloat32(106, Endian.little)
      ..maxBalanceCurrent = bd.getFloat32(110, Endian.little)
      ..balancerSwitch = bd.getUint8(114) != 0;
  }

  // ---------------------------------------------------------------- 日志帧

  List<JkLogEntry> _decodeLogbook(ByteData bd) {
    final count = bd.getUint32(6, Endian.little);
    final out = <JkLogEntry>[];
    final n = count > 50 ? 50 : count;
    for (int i = 0; i < n; i++) {
      final base = 11 + i * 5;
      if (base + 5 > 300) break;
      final ts = bd.getUint32(base, Endian.little);
      final code = bd.getUint8(base + 4);
      final d = ts ~/ 86400;
      final rem = ts % 86400;
      out.add(JkLogEntry(
        code: code,
        days: d,
        hours: rem ~/ 3600,
        minutes: (rem % 3600) ~/ 60,
        seconds: rem % 60,
      ));
    }
    return out;
  }
}
