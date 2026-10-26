/// 告警位掩码与日志事件码对照表 (中英双语)。
///
/// 来源: syssi/esphome-jk-bms components/jk_bms_ble/__init__.py (DEFAULT_ERRORS_JK02)
/// 与 jk_bms_ble.cpp (LOGBOOK_CODES)。
library;

/// 告警位 (电芯信息帧 errors bitmask, bit0..bit31)
class JkErrorBits {
  JkErrorBits._();

  static const List<String> zh = [
    '线阻异常', // bit 0
    'MOS 过温', // bit 1
    '电芯数量与设置不符', // bit 2
    '', // bit 3
    '电池已充满', // bit 4
    '电池组过压', // bit 5
    '充电过流', // bit 6
    '充电短路', // bit 7
    '充电过温', // bit 8
    '充电低温', // bit 9
    '协处理器通信异常', // bit 10
    '电芯欠压', // bit 11
    '电池组欠压', // bit 12
    '放电过流', // bit 13
    '放电短路', // bit 14
    '放电过温', // bit 15
    '充电 MOS 异常', // bit 16
    '放电 MOS 异常', // bit 17
    'GPS 断连', // bit 18
    '请及时修改密码', // bit 19
    '放电开启失败', // bit 20
    '电池过温', // bit 21
    '温度传感器异常', // bit 22
    'PL 模块异常', // bit 23
    '短路保护释放失败', // bit 24
    '放电过流 II 级', // bit 25
    '放电过流 III 级', // bit 26
    '放电低温告警', // bit 27
    'GPS 远程锁定', // bit 28
    '', // bit 29
    '', // bit 30
    '', // bit 31
  ];

  static const List<String> en = [
    'Wire resistance', // 0
    'MOSFET overtemperature', // 1
    'Cell count is not equal to settings', // 2
    '', // 3
    'Battery is fully charged', // 4
    'Battery pack overvoltage', // 5
    'Charge overcurrent', // 6
    'Charge short circuit', // 7
    'Charge overtemperature', // 8
    'Charge undertemperature', // 9
    'Coprocessor communication error', // 10
    'Cell undervoltage', // 11
    'Battery pack undervoltage', // 12
    'Discharge overcurrent', // 13
    'Discharge short circuit', // 14
    'Discharge overtemperature', // 15
    'Charging MOSFET abnormal', // 16
    'Discharging MOSFET abnormal', // 17
    'GPS disconnected', // 18
    'Modify password in time', // 19
    'Discharge on failed', // 20
    'Battery overtemperature', // 21
    'Temperature sensor anomaly', // 22
    'PL module anomaly', // 23
    'SCP release failed', // 24
    'Discharge OCP II', // 25
    'Discharge OCP III', // 26
    'Discharge undertemperature alarm', // 27
    'GPS remote lock', // 28
    '', // 29
    '', // 30
    '', // 31
  ];

  /// 提取置位的告警 bit 列表
  static List<int> activeBits(int bitmask, {int maxBit = 31}) {
    final bits = <int>[];
    for (int i = 0; i <= maxBit && i < 32; i++) {
      if ((bitmask >> i) & 1 == 1) bits.add(i);
    }
    return bits;
  }

  static String labelZh(int bit) =>
      bit >= 0 && bit < zh.length && zh[bit].isNotEmpty
          ? zh[bit]
          : '未知告警 (bit $bit)';

  static String labelEn(int bit) =>
      bit >= 0 && bit < en.length && en[bit].isNotEmpty
          ? en[bit]
          : 'Unknown (bit $bit)';
}

/// 日志事件码 (0x01..0x49 + 电芯保护 0x64..0x83 / 0xC8..0xE7)
class JkLogbookCodes {
  JkLogbookCodes._();

  static const Map<int, String> _zh = {
    0x01: '开机',
    0x02: '关机',
    0x03: 'APP 关闭充电',
    0x04: 'APP 开启充电',
    0x05: 'APP 关闭放电',
    0x06: 'APP 开启放电',
    0x07: '远程关闭充电',
    0x08: '远程开启充电',
    0x09: '远程关闭放电',
    0x0A: '远程开启放电',
    0x0B: 'MOS 过温保护',
    0x0C: 'MOS 过温保护释放',
    0x0D: '电流传感器异常',
    0x0E: '电流传感器异常恢复',
    0x0F: '协处理器通信异常',
    0x10: '协处理器通信异常恢复',
    0x11: '电芯过充保护',
    0x12: '电芯过充保护释放',
    0x13: '电池组过充保护',
    0x14: '电池组过充保护释放',
    0x15: '充电过流保护',
    0x16: '充电过流保护释放',
    0x17: '充电短路保护',
    0x18: '充电短路保护释放',
    0x19: '充电过温保护',
    0x1A: '充电过温保护释放',
    0x1B: '充电低温保护',
    0x1C: '充电低温保护释放',
    0x1D: '电芯欠压保护',
    0x1E: '电芯欠压保护释放',
    0x1F: '电池组欠压保护',
    0x20: '电池组欠压保护释放',
    0x21: '放电过流保护',
    0x22: '放电过流保护释放',
    0x23: '放电短路保护',
    0x24: '放电短路保护释放',
    0x25: '放电过温保护',
    0x26: '放电过温保护释放',
    0x27: '看门狗复位',
    0x28: '放电 II 级短路保护',
    0x29: '手动开启应急模式',
    0x2A: '手动关闭应急模式',
    0x2B: '自动关闭应急模式',
    0x2C: 'APP 关机',
    0x2D: '按键关机',
    0x2E: '放电开启失败',
    0x2F: 'RS485 断电',
    0x30: 'CAN 关闭充电',
    0x31: 'CAN 开启充电',
    0x32: 'CAN 关闭放电',
    0x33: 'CAN 开启放电',
    0x34: 'RS485 关闭充电',
    0x35: 'RS485 开启充电',
    0x36: 'RS485 关闭放电',
    0x37: 'RS485 开启放电',
    0x38: '进入休眠',
    0x39: '充电 MOS 异常',
    0x3A: '放电 MOS 异常',
    0x3B: '时间校准',
    0x3C: '电芯数量错误',
    0x3D: '按键应急开启',
    0x3E: '按键应急关闭',
    0x3F: '按键强制加热',
    0x40: '放电过流 II 级',
    0x41: '放电过流 III 级',
    0x42: '短路保护释放失败',
    0x43: '恢复出厂设置 (三元锂)',
    0x44: '恢复出厂设置 (磷酸铁锂)',
    0x45: '恢复出厂设置 (钛酸锂)',
    0x46: '远程应急开启',
    0x47: '远程应急关闭',
    0x48: '放电低温保护',
    0x49: '放电低温保护释放',
  };

  static const Map<int, String> _en = {
    0x01: 'Boot',
    0x02: 'Shutdown',
    0x03: 'APP close charge',
    0x04: 'APP open charge',
    0x05: 'APP close discharge',
    0x06: 'APP open discharge',
    0x07: 'Remote close charge',
    0x08: 'Remote open charge',
    0x09: 'Remote close discharge',
    0x0A: 'Remote open discharge',
    0x0B: 'MOS over temperature protection',
    0x0C: 'MOS over-temperature protection released',
    0x0D: 'Abnormal current sensor',
    0x0E: 'Current sensor anomaly released',
    0x0F: 'Abnormal coprocessor communication',
    0x10: 'Coprocessor communication restored',
    0x11: 'Cell overcharge protection',
    0x12: 'Cell overcharge protection released',
    0x13: 'Battery overcharge protection',
    0x14: 'Battery overcharge protection released',
    0x15: 'Charge overcurrent protection',
    0x16: 'Charge overcurrent protection released',
    0x17: 'Charge short circuit protection',
    0x18: 'Charge short circuit protection released',
    0x19: 'Charge over temperature protection',
    0x1A: 'Charge over temperature protection released',
    0x1B: 'Charge low temperature protection',
    0x1C: 'Charge low temperature protection released',
    0x1D: 'Cell undervoltage protection',
    0x1E: 'Cell undervoltage protection released',
    0x1F: 'Battery undervoltage protection',
    0x20: 'Battery undervoltage protection released',
    0x21: 'Discharge overcurrent protection',
    0x22: 'Discharge overcurrent protection released',
    0x23: 'Discharge short circuit protection',
    0x24: 'Discharge short circuit protection released',
    0x25: 'Discharge over temperature protection',
    0x26: 'Discharge over temperature protection released',
    0x27: 'Reset Watch-Dog',
    0x28: 'Discharge level 2 short circuit protection',
    0x29: 'Manually enable the emergency mode',
    0x2A: 'Manually turn off the emergency mode',
    0x2B: 'Turn off the emergency mode automatically',
    0x2C: 'APP to turn it off',
    0x2D: 'Button to turn it off',
    0x2E: 'Discharge On Failed',
    0x2F: 'RS485 power off',
    0x30: 'CAN charge off',
    0x31: 'CAN charge on',
    0x32: 'CAN discharge off',
    0x33: 'CAN discharge on',
    0x34: 'RS485 charge off',
    0x35: 'RS485 charge on',
    0x36: 'RS485 discharge off',
    0x37: 'RS485 discharge on',
    0x38: 'Enter sleep',
    0x39: 'Charge MOS abnormal',
    0x3A: 'Discharge MOS abnormal',
    0x3B: 'Time calibration',
    0x3C: 'Cells count incorrect',
    0x3D: 'Button emergency on',
    0x3E: 'Button emergency off',
    0x3F: 'Button forced heating',
    0x40: 'Discharge OCP II',
    0x41: 'Discharge OCP III',
    0x42: 'SCP release failed',
    0x43: 'Factory setting LION',
    0x44: 'Factory setting LFP',
    0x45: 'Factory setting LTO',
    0x46: 'Remote emergency on',
    0x47: 'Remote emergency off',
    0x48: 'Discharge under temperature protection',
    0x49: 'Discharge under temperature protection released',
  };

  static String zh(int code) {
    if (_zh.containsKey(code)) return _zh[code]!;
    if (code >= 0x64 && code <= 0x83) {
      return '电芯 ${code - 0x64 + 1} 过充保护';
    }
    if (code >= 0xC8 && code <= 0xE7) {
      return '电芯 ${code - 0xC8 + 1} 过放保护';
    }
    return '未知事件 (0x${code.toRadixString(16).toUpperCase()})';
  }

  static String en(int code) {
    if (_en.containsKey(code)) return _en[code]!;
    if (code >= 0x64 && code <= 0x83) {
      return 'Cell ${code - 0x64 + 1} over charge protection';
    }
    if (code >= 0xC8 && code <= 0xE7) {
      return 'Cell ${code - 0xC8 + 1} over discharge protection';
    }
    return 'Unknown (0x${code.toRadixString(16).toUpperCase()})';
  }
}

/// 参数帧控制位掩码 (bytes 282-283)
class JkControlsBits {
  JkControlsBits._();
  static const List<String> zh = [
    '加热使能', // bit0
    '禁用温度传感器', // bit1
    'GPS 心跳', // bit2
    '端口切换 (1:RS485 / 0:CAN)', // bit3
    '常亮显示', // bit4
    '特殊充电器', // bit5
    '智能休眠', // bit6
    '禁用 PCL 模块', // bit7
    '定时存储数据', // bit8
    '充电浮充模式', // bit9
  ];

  static List<String> active(int mask) {
    final out = <String>[];
    for (int i = 0; i < zh.length; i++) {
      if ((mask >> i) & 1 == 1) out.add(zh[i]);
    }
    return out;
  }
}
