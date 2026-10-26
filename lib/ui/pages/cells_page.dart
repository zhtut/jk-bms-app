import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme.dart';
import '../widgets/cell_bars.dart';
import '../widgets/common.dart';

/// 电芯明细页: 条形图 + 每串电压/内阻/偏差表
class CellsPage extends StatelessWidget {
  const CellsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final s = c.snapshot;
    if (s == null) {
      return const Center(
          child: Text('等待数据...', style: TextStyle(color: AppColors.gray)));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avg = s.avgCellVoltage;

    final rows = <Widget>[];
    for (int i = 0; i < s.cellVoltages.length; i++) {
      final v = s.cellVoltages[i];
      if (v == null || v <= 0) continue;
      final dev = avg == null ? null : v - avg; // 偏离均值 (V)
      final isMax = s.maxCellNumber == i + 1;
      final isMin = s.minCellNumber == i + 1;
      final r = i < s.cellResistances.length ? s.cellResistances[i] : null;
      rows.add(_CellRow(
        index: i + 1,
        volts: v,
        deviationV: dev,
        resistance: r,
        // 极空配色: 最高=蓝, 最低=红
        highlight: isMax
            ? AppColors.blue
            : isMin
                ? AppColors.red
                : null,
        warn: dev != null && dev.abs() > 0.05,
        isDark: isDark,
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '电芯电压分布',
            child: CellBarsChart(voltages: s.cellVoltages, height: 210),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '单体明细 (${rows.length} 串)',
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      _headCell('编号', 60),
                      _headCell('电压', 90),
                      _headCell('偏离均值', 100),
                      _headCell('内阻', 100),
                      const Spacer(),
                      _LegendDot(color: AppColors.blue, label: '最高'),
                      const SizedBox(width: 10),
                      _LegendDot(color: AppColors.red, label: '最低'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...rows,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headCell(String text, double width) => SizedBox(
        width: width,
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.gray, fontWeight: FontWeight.w500)),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
        ],
      );
}

class _CellRow extends StatelessWidget {
  const _CellRow({
    required this.index,
    required this.volts,
    required this.deviationV,
    required this.resistance,
    required this.highlight,
    required this.warn,
    required this.isDark,
  });

  final int index;
  final double volts;
  final double? deviationV;
  final double? resistance;
  final Color? highlight;
  final bool warn;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = highlight ?? (isDark ? Colors.white : const Color(0xFF212B36));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: highlight != null
          ? BoxDecoration(color: highlight!.withValues(alpha: 0.06))
          : null,
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text('#$index',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500))),
          SizedBox(
              width: 90,
              child: Text('${volts.toStringAsFixed(3)} V',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontFeatures: const [FontFeature.tabularFigures()]))),
          SizedBox(
              width: 100,
              child: Text(
                deviationV == null
                    ? '--'
                    : '${deviationV! > 0 ? '+' : ''}${deviationV!.toStringAsFixed(3)} V',
                style: TextStyle(
                  fontSize: 12.5,
                  color: warn
                      ? AppColors.orange
                      : (isDark ? Colors.white54 : Colors.black54),
                  fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
                ),
              )),
          SizedBox(
              width: 100,
              child: Text(
                resistance == null || resistance == 0
                    ? '--'
                    : '${(resistance! * 1000).round()} mΩ',
                style: TextStyle(
                    fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black54),
              )),
          const Spacer(),
          // 迷你条
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                height: 6,
                width: 100,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (volts % 1).clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (highlight ?? AppColors.green).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
