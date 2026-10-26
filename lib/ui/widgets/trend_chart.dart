import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

enum TrendMetric {
  voltage('总电压', 'V', AppColors.primary),
  current('电流', 'A', AppColors.orange),
  power('功率', 'W', Color(0xFF8E24AA)),
  soc('SOC', '%', AppColors.green),
  deltaCell('电芯压差', 'V', AppColors.red),
  maxTemp('最高温度', '°C', Color(0xFF00897B));

  const TrendMetric(this.label, this.unit, this.color);
  final String label;
  final String unit;
  final Color color;
}

/// 历史趋势折线图 (最近 ~1 小时, 2s 采样)
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.samples});

  final List<HistorySample> samples;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  TrendMetric _metric = TrendMetric.voltage;

  double? _valueOf(HistorySample s) => switch (_metric) {
        TrendMetric.voltage => s.totalVoltage,
        TrendMetric.current => s.current,
        TrendMetric.power => s.power,
        TrendMetric.soc => s.soc,
        TrendMetric.deltaCell => s.deltaCellVoltage,
        TrendMetric.maxTemp => s.maxTemp,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pts = <FlSpot>[];
    if (widget.samples.isNotEmpty) {
      final t0 = widget.samples.first.t.millisecondsSinceEpoch.toDouble();
      for (final s in widget.samples) {
        final v = _valueOf(s);
        if (v != null && v.isFinite) {
          pts.add(FlSpot(
              (s.t.millisecondsSinceEpoch - t0) / 60000.0, v.toDouble()));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: TrendMetric.values.map((m) {
            final selected = m == _metric;
            return ChoiceChip(
              label: Text('${m.label}${m.unit.isNotEmpty ? ' (${m.unit})' : ''}',
                  style: const TextStyle(fontSize: 11.5)),
              selected: selected,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _metric = m),
              selectedColor: m.color.withValues(alpha: 0.18),
              side: BorderSide(
                  color: selected ? m.color : Colors.transparent, width: 1),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: pts.length < 2
              ? Center(
                  child: Text('采集中... 连接后自动记录 (2s/次)',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : Colors.black38)),
                )
              : LineChart(_buildData(pts, isDark)),
        ),
      ],
    );
  }

  LineChartData _buildData(List<FlSpot> pts, bool isDark) {
    final color = _metric.color;
    double minY = pts.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    double maxY = pts.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    if (maxY - minY < 1e-6) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }
    final maxX = pts.last.x;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white38 : Colors.black45;

    return LineChartData(
      minY: minY,
      maxY: maxY,
      minX: 0,
      maxX: maxX,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 4,
        getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: (maxY - minY) / 4,
            getTitlesWidget: (v, meta) => Text(
              _metric == TrendMetric.soc
                  ? v.round().toString()
                  : (v.abs() >= 100
                      ? v.round().toString()
                      : v.toStringAsFixed(v.abs() < 10 ? 2 : 1)),
              style: TextStyle(fontSize: 10, color: labelColor),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: maxX > 0 ? _niceInterval(maxX / 4) : 1,
            getTitlesWidget: (v, meta) {
              final m = v.round();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m >= 60 ? '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}' : '${m}m',
                    style: TextStyle(fontSize: 10, color: labelColor)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) =>
              (isDark ? const Color(0xFF2A323D) : const Color(0xFF303A45))
                  .withValues(alpha: 0.95),
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${s.x.round()} 分钟前\n${s.y.toStringAsFixed(3)} ${_metric.unit}',
                    const TextStyle(color: Colors.white, fontSize: 11.5),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: pts,
          isCurved: false,
          barWidth: 2,
          color: color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }

  static double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final pow = _pow10(raw);
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (raw <= m * pow) return m * pow;
    }
    return 10 * pow;
  }

  static double _pow10(double v) {
    double p = 1;
    while (v > p * 10) {
      p *= 10;
    }
    return p;
  }
}
