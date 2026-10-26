import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms_app/models.dart';
import 'package:jk_bms_app/protocol/decoder.dart';
import 'package:jk_bms_app/protocol/errors.dart';
import 'package:jk_bms_app/protocol/frames.dart';

import 'fixtures.dart';

// ---------------------------------------------------------------------------
// 真实抓包 fixture: test/fixtures.dart 由 tools/gen_fixtures.dart 从
// syssi/esphome-jk-bms jk_bms_ble.cpp 注释中的真实设备响应帧自动提取,
// 全部通过 CRC 校验 (证明字节级正确)。
// ---------------------------------------------------------------------------

Uint8List _parseHex(String s) {
  final clean = s.replaceAll('.', ' ').replaceAll('0x', ' ');
  final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final bytes = tokens.map((t) => int.parse(t, radix: 16)).toList();
  return Uint8List.fromList(bytes);
}

void _setU16(Uint8List f, int i, int v) =>
    ByteData.sublistView(f).setUint16(i, v, Endian.little);
void _setU32(Uint8List f, int i, int v) =>
    ByteData.sublistView(f).setUint32(i, v, Endian.little);
void _setI32(Uint8List f, int i, int v) =>
    ByteData.sublistView(f).setInt32(i, v, Endian.little);

/// 合成 JK02_32S 电芯帧 (16 串 x 3300mV, 放电 -2.5A, SOC 66)
Uint8List _build32sFrame() {
  final f = Uint8List(300);
  f.setAll(0, [0x55, 0xAA, 0xEB, 0x90]);
  f[4] = JkProto.frameCellInfo;
  f[5] = 0x77;
  for (int i = 0; i < 16; i++) {
    _setU16(f, 6 + i * 2, 3300);
  }
  _setU32(f, 70, 0x0000FFFF); // 使能位掩码: 16 串
  _setU16(f, 144, 250); // MOS 温度 25.0°C
  _setU32(f, 150, 52800); // 总压 52.800V
  _setI32(f, 158, -2500); // 电流 -2.5A (放电)
  _setU16(f, 162, 210); // 温度1 21.0
  _setU16(f, 164, 211); // 温度2 21.1
  _setU32(f, 166, 0x20); // 告警 bit5 电池组过压
  _setU16(f, 170, 100); // 均衡电流 0.1A
  f[172] = 1; // 充电均衡
  f[173] = 66; // SOC
  _setU32(f, 174, 50000); // 剩余 50Ah
  _setU32(f, 178, 100000); // 标称 100Ah
  _setU32(f, 182, 42); // 循环 42
  _setU32(f, 186, 1234); // 循环容量 1.234Ah
  f[190] = 99; // SOH
  _setU32(f, 194, 3600); // 运行 1h
  f[198] = 1; // 充电 MOS
  f[199] = 1; // 放电 MOS
  f[200] = 0; // 预充
  f[201] = 1; // 均衡中
  _setU16(f, 214, 0); // 温度传感器掩码
  f[215] = 0; // 加热
  _setU16(f, 254, 100); // 温度5 10.0
  _setU16(f, 256, 101); // 温度4 10.1
  _setU16(f, 258, 102); // 温度3 10.2
  f[275] = 0; // LFP
  _setU16(f, 278, 600); // 充电阶段时长
  f[280] = 2; // 浮充
  f[281] = 0x02; // 干接点1
  f[299] = jkCrc(f, 299);
  return f;
}

/// 合成 JK02 参数帧
Uint8List _buildSettingsFrame() {
  final f = Uint8List(300);
  f.setAll(0, [0x55, 0xAA, 0xEB, 0x90]);
  f[4] = JkProto.frameSettings;
  _setU32(f, 10, 2500); // UVP 2.5V
  _setU32(f, 14, 2800); // UVP 恢复 2.8V
  _setU32(f, 18, 3650); // OVP 3.65V
  _setU32(f, 22, 3400); // OVP 恢复 3.4V
  _setU32(f, 50, 20000); // 最大充电 20A
  _setU32(f, 62, 40000); // 最大放电 40A
  f[114] = 16; // 串数
  f[118] = 1; // 充电开关
  f[122] = 1; // 放电开关
  f[126] = 0; // 均衡开关关
  _setU32(f, 130, 100000); // 标称 100Ah
  _setU16(f, 282, 0x0041); // 控制位: bit0 加热使能 + bit6 智能休眠
  f[284] = 0xFB; // 加热启动 -5°C (int8)
  f[285] = 10; // 加热停止 10°C
  f[299] = jkCrc(f, 299);
  return f;
}

/// 合成日志帧
Uint8List _buildLogbookFrame() {
  final f = Uint8List(300);
  f.setAll(0, [0x55, 0xAA, 0xEB, 0x90]);
  f[4] = JkProto.frameLogbook;
  _setU32(f, 6, 2); // 2 条
  _setU32(f, 11, 90061); // 1天01:01:01
  f[15] = 0x11; // 电芯过充保护
  _setU32(f, 16, 176722); // 2天01:05:22
  f[20] = 0xC9; // 电芯 2 过放保护
  f[299] = jkCrc(f, 299);
  return f;
}

void main() {
  group('CRC 与命令帧', () {
    test('jkCrc = sum mod 256', () {
      expect(jkCrc([0x01, 0x02, 0xFF]), 0x02);
    });

    test('构造 0x97 设备信息命令帧', () {
      final cmd = jkBuildCommand(JkProto.cmdDeviceInfo);
      expect(cmd.length, 20);
      expect(cmd.sublist(0, 4), [0xAA, 0x55, 0x90, 0xEB]);
      expect(cmd[4], 0x97);
      expect(cmd[5], 0x00);
      expect(cmd[19], 0x11); // (AA+55+90+EB+97) mod 256
    });

    test('真实抓包帧 CRC 自校验', () {
      for (final hex in [jk02CellInfoHex, jk04CellInfoHex, deviceInfoHex]) {
        final f = _parseHex(hex);
        expect(f.length, JkProto.frameSize, reason: '帧长应为 300');
        expect(jkCrc(f, 299), f[299], reason: '真实帧 CRC 应通过 (验证转录无误)');
      }
    });
  });

  group('帧组装器', () {
    test('20 字节分包重组出完整帧', () {
      final f = _parseHex(jk02CellInfoHex);
      final asm = JkFrameAssembler();
      final out = <Uint8List>[];
      for (int i = 0; i < f.length; i += 20) {
        out.addAll(asm.feed(f.sublist(i, (i + 20).clamp(0, f.length))));
      }
      expect(out.length, 1);
      expect(out[0], f);
    });

    test('前置脏数据被丢弃', () {
      final f = _parseHex(jk02CellInfoHex);
      final asm = JkFrameAssembler();
      final out = <Uint8List>[];
      final dirty = Uint8List.fromList([0x01, 0x02, 0x03, 0x55, 0xAA, 0x00, 0x00] + f);
      for (int i = 0; i < dirty.length; i += 37) {
        out.addAll(asm.feed(dirty.sublist(i, (i + 37).clamp(0, dirty.length))));
      }
      expect(out.length, 1);
      expect(out[0], f);
    });

    test('粘帧: 两帧连发全部解出', () {
      final f = _parseHex(jk02CellInfoHex);
      final asm = JkFrameAssembler();
      final both = Uint8List.fromList(f + f);
      final out = asm.feed(both);
      expect(out.length, 2);
    });

    test('新帧头到达时清空残留缓冲 (320 字节设备)', () {
      final f = _parseHex(jk02CellInfoHex);
      final asm = JkFrameAssembler();
      // 模拟 320 字节帧: 300 有效 + 20 垃圾尾, 随后下一帧
      final padded = Uint8List.fromList(f + List.filled(20, 0xEE) + f);
      final out1 = asm.feed(padded.sublist(0, 160));
      expect(out1.length, 0); // 还没收完第一帧
      final out2 = <Uint8List>[];
      for (int i = 160; i < padded.length; i += 20) {
        out2.addAll(asm.feed(padded.sublist(i, (i + 20).clamp(0, padded.length))));
      }
      // 第一帧 + 垃圾尾被跳过后第二帧 (feed 内部先解出第一帧, 垃圾在下一次帧头对齐时被丢弃)
      expect(out1.length + out2.length, 2);
    });
  });

  group('JK02_24S 真实帧解码', () {
    final f = _parseHex(jk02CellInfoHex);
    final decoder = JkDecoder();
    final res = decoder.decode(f);
    final s = res.snapshot!;

    test('变体自动探测为 JK02_24S', () {
      expect(res.variant, JkVariant.jk02_24s);
      expect(decoder.detectedVariant, JkVariant.jk02_24s);
    });

    test('电芯电压 / 串数', () {
      expect(s.activeCellCount, 16);
      expect(s.cellVoltages[0], closeTo(3.327, 1e-9));
      expect(s.cellVoltages[1], closeTo(3.329, 1e-9));
      expect(s.minCellVoltage, closeTo(3.327, 1e-9));
      expect(s.maxCellVoltage, closeTo(3.329, 1e-9));
      expect(s.deltaCellVoltage, closeTo(0.002, 1e-9));
      expect(s.cellVoltages[16], isNull); // 未启用
    });

    test('总压 / 电流 / SOC / 容量', () {
      expect(s.totalVoltage, closeTo(53.251, 1e-9));
      expect(s.current, 0.0);
      expect(s.soc, 84);
      expect(s.soh, 100);
      expect(s.remainingCapacityAh, closeTo(68.494, 1e-9));
      expect(s.nominalCapacityAh, closeTo(81.0, 1e-9));
      expect(s.runtimeSeconds, 1049546);
    });

    test('温度与状态位', () {
      expect(s.temp1, closeTo(19.0, 1e-9));
      expect(s.temp2, closeTo(19.1, 1e-9));
      expect(s.mosTemp, closeTo(21.0, 1e-9));
      expect(s.tempSensorsMissingMask, 0x0007);
      expect(s.chargeMosOn, true);
      expect(s.dischargeMosOn, true);
      expect(s.errorsBitmask, 0);
    });
  });

  group('JK04 真实帧解码', () {
    final f = _parseHex(jk04CellInfoHex);
    final decoder = JkDecoder();
    final s = decoder.decode(f).snapshot!;

    test('变体自动探测为 JK04', () {
      expect(decoder.detectedVariant, JkVariant.jk04);
    });

    test('float32 电芯电压', () {
      expect(s.activeCellCount, 16);
      expect(s.cellVoltages[0]!, closeTo(3.3497, 0.001));
      expect(s.cellVoltages[14]!, closeTo(3.3512, 0.001));
      expect(s.cellVoltages[16], isNull);
      // 总压 = 电芯之和 ≈ 53.6V
      expect(s.totalVoltage!, closeTo(53.6, 0.05));
      expect(s.deltaCellVoltage!, lessThan(0.01));
    });

    test('运行时间', () {
      expect(s.runtimeSeconds, 1873491);
    });
  });

  group('设备信息帧解码', () {
    final f = _parseHex(deviceInfoHex);
    final d = JkDecoder().decode(f).deviceInfo!;

    test('字符串字段', () {
      expect(d.model, 'JK_PB2A16S15P');
      expect(d.hwVersion, '14.XA');
      expect(d.swVersion, '14.20');
      expect(d.name, 'JK_PB2A16S15P');
      expect(d.passcode, '1234');
      expect(d.mfgDate, '20231118');
      expect(d.serial, '3092572134');
    });

    test('数值字段', () {
      expect(d.uptimeSeconds, 124500);
      expect(d.powerOnCount, 156);
    });
  });

  group('JK02_32S 合成帧解码', () {
    final f = _build32sFrame();
    final decoder = JkDecoder();
    final res = decoder.decode(f);
    final s = res.snapshot!;

    test('变体自动探测为 JK02_32S', () {
      expect(res.variant, JkVariant.jk02_32s);
    });

    test('数据区偏移 (+32) 字段全部正确', () {
      expect(s.activeCellCount, 16);
      expect(s.totalVoltage, closeTo(52.8, 1e-9));
      expect(s.current, closeTo(-2.5, 1e-9));
      expect(s.isDischarging, true);
      expect(s.power, closeTo(-132.0, 1e-6));
      expect(s.soc, 66);
      expect(s.soh, 99);
      expect(s.temp1, closeTo(21.0, 1e-9));
      expect(s.temp2, closeTo(21.1, 1e-9));
      expect(s.temp3, closeTo(10.2, 1e-9));
      expect(s.temp4, closeTo(10.1, 1e-9));
      expect(s.temp5, closeTo(10.0, 1e-9));
      expect(s.mosTemp, closeTo(25.0, 1e-9));
      expect(s.errorsBitmask, 0x20);
      expect(JkErrorBits.activeBits(s.errorsBitmask), [5]);
      expect(JkErrorBits.labelZh(5), '电池组过压');
      expect(s.balanceCurrent, closeTo(0.1, 1e-9));
      expect(s.balanceAction, 1);
      expect(s.remainingCapacityAh, closeTo(50.0, 1e-9));
      expect(s.nominalCapacityAh, closeTo(100.0, 1e-9));
      expect(s.cycleCount, 42);
      expect(s.runtimeSeconds, 3600);
      expect(s.chargeMosOn, true);
      expect(s.dischargeMosOn, true);
      expect(s.balancerWorking, true);
      expect(s.batteryTypeId, 0);
      expect(s.batteryTypeText, contains('LFP'));
      expect(s.chargeStatusId, 2);
      expect(s.dryContact1, true);
      expect(s.dryContact2, false);
    });
  });

  group('参数帧解码', () {
    final f = _buildSettingsFrame();
    final st = JkDecoder().decode(f).settings!;

    test('JK02 参数 (u32 定标)', () {
      expect(st.cellOvp, closeTo(3.65, 1e-9));
      expect(st.cellOvpRecovery, closeTo(3.4, 1e-9));
      expect(st.cellUvp, closeTo(2.5, 1e-9));
      expect(st.maxChargeCurrent, closeTo(20.0, 1e-9));
      expect(st.maxDischargeCurrent, closeTo(40.0, 1e-9));
      expect(st.cellCount, 16);
      expect(st.chargeSwitch, true);
      expect(st.balancerSwitch, false);
      expect(st.nominalCapacityAh, closeTo(100.0, 1e-9));
      expect(st.heatingStartTempC, -5);
      expect(st.heatingStopTempC, 10);
      expect(JkControlsBits.active(st.controlsBitmask!), ['加热使能', '智能休眠']);
    });
  });

  group('日志帧解码', () {
    final f = _buildLogbookFrame();
    final entries = JkDecoder().decode(f).logbook!;

    test('条目与相对时间', () {
      expect(entries.length, 2);
      expect(entries[0].days, 1);
      expect(entries[0].hours, 1);
      expect(entries[0].minutes, 1);
      expect(entries[0].seconds, 1);
      expect(JkLogbookCodes.zh(entries[0].code), '电芯过充保护');
      expect(JkLogbookCodes.zh(entries[1].code), '电芯 2 过放保护');
      expect(JkLogbookCodes.en(entries[1].code),
          'Cell 2 over discharge protection');
    });
  });

  group('用户真机帧 (储能 300A 板, JK02_32S)', () {
    const hex =
        '55 AA EB 90 02 1A 92 0C 92 0C 92 0C 92 0C 93 0C '
        '92 0C 92 0C 8F 0C 92 0C 92 0C 93 0C 93 0C 93 0C '
        '92 0C 92 0C 92 0C 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 FF FF 00 00 92 0C 04 00 04 07 '
        '45 00 43 00 45 00 43 00 45 00 43 00 45 00 43 00 '
        '45 00 43 00 44 00 43 00 46 00 46 00 47 00 45 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '32 01 00 00 00 00 21 C9 00 00 00 00 00 00 00 00 '
        '00 00 23 01 2D 01 00 00 08 00 00 00 00 01 90 03 '
        '00 00 F4 64 01 00 00 00 00 00 06 97 04 00 1D 00 '
        '00 00 D2 E4 02 00 01 01 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 FF 00 01 00 00 00 02 00 00 00 '
        '01 00 AD 0E 3F 40 00 00 00 00 1C 14 00 00 00 01 '
        '01 01 00 06 01 00 9B C1 1C 00 00 00 00 00 32 01 '
        '2E 01 29 01 01 00 89 19 D4 0C 2E 00 00 00 80 51 '
        '01 00 00 00 02 00 00 00 00 00 00 00 00 00 00 FE '
        'FF 7F DD 2F 01 21 B0 0F 07 00 00 B5';
    final f = _parseHex(hex);
    final s = JkDecoder().decode(f).snapshot!;

    test('帧完整且变体正确', () {
      expect(f.length, 300);
      expect(jkCrc(f, 299), f[299]);
      expect(s.variant, JkVariant.jk02_32s);
    });

    test('核心遥测', () {
      expect(s.activeCellCount, 16);
      expect(s.cellVoltages[0], closeTo(3.218, 1e-9));
      expect(s.totalVoltage, closeTo(51.489, 1e-9));
      expect(s.current, 0.0);
      expect(s.temp1, closeTo(29.1, 1e-9));
      expect(s.temp2, closeTo(30.1, 1e-9));
      expect(s.mosTemp, closeTo(30.6, 1e-9));
      expect(s.chargeMosOn, true);
      expect(s.dischargeMosOn, true);
      expect(s.runtimeSeconds, 189650);
    });

    test('容量区字段 (学习值, 非配置标称容量)', () {
      expect(s.soc, 1);
      expect(s.soh, 29);
      // 电芯帧 178 字节处为 BMS 学习满充容量 (91.38Ah),
      // 配置标称容量在参数帧 0x01, 界面优先展示参数帧值
      expect(s.nominalCapacityAh, closeTo(91.38, 0.01));
      expect(s.remainingCapacityAh, closeTo(0.912, 0.001));
      expect(s.cycleCapacityAh, closeTo(300.806, 0.001));
      expect(s.cycleCount, 0);
    });

    test('告警位 bit19 (请及时修改密码)', () {
      expect(s.errorsBitmask, 0x00080000);
      expect(JkErrorBits.activeBits(s.errorsBitmask), [19]);
    });
  });

  group('变体手动覆盖', () {
    test('override 优先于自动探测', () {
      final f = _parseHex(jk02CellInfoHex);
      final decoder = JkDecoder()..variantOverride = JkVariant.jk02_32s;
      final res = decoder.decode(f);
      expect(res.variant, JkVariant.jk02_32s);
      expect(res.snapshot!.variant, JkVariant.jk02_32s);
    });
  });
}
