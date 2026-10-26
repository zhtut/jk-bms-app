import '../models.dart';

/// 历史数据环形缓冲 (内存, 约 1 小时 @2s) + CSV 导出。
class HistoryBuffer {
  static const int maxSamples = 1800;
  static const Duration _minInterval = Duration(seconds: 2);

  final List<HistorySample> samples = [];
  DateTime? _lastAdd;

  /// 从快照采样 (节流: >=2s 一次)
  void addFromSnapshot(JkSnapshot s) {
    final now = DateTime.now();
    if (_lastAdd != null && now.difference(_lastAdd!) < _minInterval) return;
    _lastAdd = now;
    samples.add(HistorySample.fromSnapshot(s));
    if (samples.length > maxSamples) {
      samples.removeRange(0, samples.length - maxSamples);
    }
  }

  void clear() {
    samples.clear();
    _lastAdd = null;
  }

  String toCsv() {
    final sb = StringBuffer();
    sb.writeln('时间,SOC(%),总电压(V),电流(A),功率(W),平均电芯(V),最低电芯(V),'
        '最高电芯(V),压差(V),最高温度(°C),均衡电流(A)');
    String f(double? v, [int d = 3]) => v == null ? '' : v.toStringAsFixed(d);
    for (final s in samples) {
      sb.writeln([
        s.t.toIso8601String(),
        f(s.soc, 0),
        f(s.totalVoltage, 2),
        f(s.current),
        f(s.power, 1),
        f(s.avgCellVoltage, 4),
        f(s.minCellVoltage, 4),
        f(s.maxCellVoltage, 4),
        f(s.deltaCellVoltage, 4),
        f(s.maxTemp, 1),
        f(s.balanceCurrent, 4),
      ].join(','));
    }
    return sb.toString();
  }
}
