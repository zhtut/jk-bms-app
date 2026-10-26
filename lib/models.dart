/// 数据模型: 解码结果、历史采样、调试帧记录。
library;

enum JkVariant { jk02_24s, jk02_32s, jk04 }

extension JkVariantLabel on JkVariant {
  String get label => switch (this) {
        JkVariant.jk02_24s => 'JK02-24S',
        JkVariant.jk02_32s => 'JK02-32S',
        JkVariant.jk04 => 'JK04',
      };
}

enum ConnState {
  idle, // 未连接
  scanning, // 扫描中
  connecting, // 连接中
  waitingData, // 已连接, 等待数据帧
  running, // 数据接收中
  error, // 出错
}

/// 电芯信息帧 (0x02) 解码结果。
/// 可空字段 = 当前协议变体不提供该数据 (如 JK04 无电流/温度/SOC)。
class JkSnapshot {
  JkSnapshot({required this.ts, required this.variant});

  final DateTime ts;
  final JkVariant variant;
  int? frameCounter;

  /// 电芯电压 (V), 下标 0 = 电芯 1; 长度 24 (JK02_24S/JK04) 或 32 (JK02_32S)
  List<double?> cellVoltages = [];

  /// 电芯内阻 (Ω)
  List<double?> cellResistances = [];

  int activeCellCount = 0;
  double? minCellVoltage; // V
  double? maxCellVoltage; // V
  double? avgCellVoltage; // V
  double? deltaCellVoltage; // V
  int? minCellNumber; // 1-based
  int? maxCellNumber; // 1-based

  double? totalVoltage; // V
  double? current; // A, 正=充电 负=放电
  double? power; // W (= totalVoltage * current)
  double? balanceCurrent; // A

  /// 0=无 1=充电均衡 2=放电均衡
  int balanceAction = 0;

  double? temp1; // °C
  double? temp2;
  double? temp3;
  double? temp4;
  double? temp5;
  double? mosTemp;

  /// 温度传感器缺失掩码 (bit0=MOS, bit1..5=传感器1..5), 仅 JK02
  int? tempSensorsMissingMask;

  int errorsBitmask = 0;

  int? soc; // %
  int? soh; // %
  double? remainingCapacityAh;
  double? nominalCapacityAh;
  int? cycleCount;
  double? cycleCapacityAh;

  bool? chargeMosOn;
  bool? dischargeMosOn;
  bool? precharging;
  bool? heating;
  bool? balancerWorking;
  bool? chargerConnected;
  double? heatingCurrent; // A
  int? runtimeSeconds;
  int? emergencyCountdown; // s, >0 表示应急模式激活

  int? batteryTypeId; // 0=LFP 1=三元 2=LTO (仅 JK02_32S)
  int? chargeStatusId; // 0=恒流 1=恒压 2=浮充 (仅 JK02_32S)
  int? chargeStatusSeconds;
  bool? dryContact1;
  bool? dryContact2;

  bool get isCharging => (current ?? 0) > 0.05;
  bool get isDischarging => (current ?? 0) < -0.05;

  String get batteryTypeText => switch (batteryTypeId) {
        0 => '磷酸铁锂 (LFP)',
        1 => '三元锂 (Li-ion)',
        2 => '钛酸锂 (LTO)',
        _ => '--',
      };

  String get chargeStatusText => switch (chargeStatusId) {
        0 => '恒流 (Bulk)',
        1 => '恒压 (Absorption)',
        2 => '浮充 (Float)',
        _ => '--',
      };

  /// 全部有效温度 (含 MOS)
  List<double> get allTemps => [temp1, temp2, temp3, temp4, temp5, mosTemp]
      .whereType<double>()
      .toList();

  double? get maxTemp =>
      allTemps.isEmpty ? null : allTemps.reduce((a, b) => a > b ? a : b);

  double? get minTemp =>
      allTemps.isEmpty ? null : allTemps.reduce((a, b) => a < b ? a : b);
}

/// 设备信息帧 (0x03) 解码结果
class JkDeviceInfo {
  String model = '';
  String name = '';
  String hwVersion = '';
  String swVersion = '';
  String serial = '';
  String mfgDate = ''; // YYYYMMDD 或空
  String passcode = '';
  String userData = '';
  int uptimeSeconds = 0;
  int powerOnCount = 0;
}

/// 参数帧 (0x01) 解码结果 (只读展示)
class JkSettings {
  JkVariant? variant;

  // 电芯电压保护 (V)
  double? cellOvp;
  double? cellOvpRecovery;
  double? cellUvp;
  double? cellUvpRecovery;

  // 均衡
  double? balanceStartVoltage; // V
  double? balanceTriggerVoltage; // V (JK02: 触发压差电压 / JK04: 触发压差)
  double? maxBalanceCurrent; // A
  bool? balancerSwitch;

  // SOC 校准 (V)
  double? soc100Voltage;
  double? soc0Voltage;
  double? requestChargeVoltage;
  double? requestFloatVoltage;
  double? powerOffVoltage;
  double? smartSleepVoltage;

  // 电流保护
  double? maxChargeCurrent; // A
  int? chargeOcpDelaySeconds;
  int? chargeOcpRecoverySeconds;
  double? maxDischargeCurrent; // A
  int? dischargeOcpDelaySeconds;
  int? dischargeOcpRecoverySeconds;
  int? shortCircuitRecoverySeconds;
  int? shortCircuitDelayMicros;

  // 温度保护 (°C)
  double? chargeOtp;
  double? chargeOtpRecovery;
  double? dischargeOtp;
  double? dischargeOtpRecovery;
  double? chargeUtp;
  double? chargeUtpRecovery;
  double? mosOtp;
  double? mosOtpRecovery;
  double? dischargeUtp;
  double? dischargeUtpRecovery;

  // 基本参数
  int? cellCount;
  bool? chargeSwitch;
  bool? dischargeSwitch;
  double? nominalCapacityAh;
  List<double>? wireResistances; // Ω, 32 路
  int? deviceAddress;
  int? prechargeTimeSeconds;
  int? controlsBitmask;
  int? heatingStartTempC;
  int? heatingStopTempC;
  int? smartSleepHours;
  double? voltageCalibration; // JK04
}

/// 日志帧 (0x05) 单条记录
class JkLogEntry {
  JkLogEntry({
    required this.code,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int code;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  /// 设备相对时间 (自开机)
  String get timeLabel =>
      '$days天 ${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 历史采样 (趋势图 / CSV 导出)
class HistorySample {
  HistorySample({
    required this.t,
    this.soc,
    this.totalVoltage,
    this.current,
    this.power,
    this.avgCellVoltage,
    this.minCellVoltage,
    this.maxCellVoltage,
    this.deltaCellVoltage,
    this.maxTemp,
    this.balanceCurrent,
  });

  final DateTime t;
  final double? soc;
  final double? totalVoltage;
  final double? current;
  final double? power;
  final double? avgCellVoltage;
  final double? minCellVoltage;
  final double? maxCellVoltage;
  final double? deltaCellVoltage;
  final double? maxTemp;
  final double? balanceCurrent;

  factory HistorySample.fromSnapshot(JkSnapshot s) => HistorySample(
        t: s.ts,
        soc: s.soc?.toDouble(),
        totalVoltage: s.totalVoltage,
        current: s.current,
        power: s.power,
        avgCellVoltage: s.avgCellVoltage,
        minCellVoltage: s.minCellVoltage,
        maxCellVoltage: s.maxCellVoltage,
        deltaCellVoltage: s.deltaCellVoltage,
        maxTemp: s.maxTemp,
        balanceCurrent: s.balanceCurrent,
      );
}

/// 调试页原始帧记录
class RawFrameEntry {
  RawFrameEntry({
    required this.ts,
    required this.direction,
    required this.label,
    required this.bytes,
  });

  final DateTime ts;

  /// 'rx' 接收 / 'tx' 发送 / 'drop' 丢弃
  final String direction;
  final String label;
  final List<int> bytes;
}
