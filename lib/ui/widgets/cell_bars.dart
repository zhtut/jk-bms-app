import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// 电芯电压条形图 (仿极空 App): 每串一根竖条, 标注编号与电压,
/// 最高红色 / 最低蓝色 / 其余绿色, 平均电压虚线。
class CellBarsChart extends StatelessWidget {
  const CellBarsChart({super.key, required this.voltages, this.height = 190});

  /// 电芯电压列表 (V), null = 未启用
  final List<double?> voltages;
  final double height;

  @override
  Widget build(BuildContext context) {
    final active = voltages.whereType<double>().toList();
    if (active.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
            child: Text('暂无电芯数据', style: TextStyle(color: AppColors.gray))),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CellBarsPainter(
          voltages: voltages,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _CellBarsPainter extends CustomPainter {
  _CellBarsPainter({required this.voltages, required this.isDark});

  final List<double?> voltages;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final active = <int, double>{};
    for (int i = 0; i < voltages.length; i++) {
      final v = voltages[i];
      if (v != null && v > 0) active[i] = v;
    }
    if (active.isEmpty) return;

    final values = active.values.toList();
    double vmin = values.reduce(math.min);
    double vmax = values.reduce(math.max);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final span = math.max(vmax - vmin, 0.008); // 最小显示跨度 8mV
    // 纵向显示范围: 均值居中, 上下各留 2.5 倍跨度 + 边距
    final lo = vmin - span * 1.2;
    final hi = vmax + span * 1.2;

    final n = voltages.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.62, 34.0);
    final bottomLabelH = 16.0;
    // 电压标签水平绘制 (桌面端空间充足), 按槽宽自适应字号
    final labelSize = slot >= 52 ? 10.0 : (slot >= 38 ? 9.0 : 7.5);
    final topLabelH = labelSize + 8;
    final chartH = size.height - bottomLabelH - topLabelH;

    double yOf(double v) =>
        topLabelH + chartH * (1 - (v - lo) / (hi - lo));

    // 平均虚线
    final avgY = yOf(avg);
    final dashPaint = Paint()
      ..color = (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashPaint);
    }

    final maxIdx = active.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final minIdx = active.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    final spreadSmall = (vmax - vmin) < 0.010; // 压差 <10mV 全绿

    for (final entry in active.entries) {
      final i = entry.key;
      final v = entry.value;
      final cx = slot * i + slot / 2;
      final top = yOf(v);
      final bottom = topLabelH + chartH;

      // 极空配色: 最高电压=蓝, 最低电压=红, 其余=绿
      Color color;
      if (spreadSmall) {
        color = AppColors.green;
      } else if (i == maxIdx) {
        color = AppColors.blue;
      } else if (i == minIdx) {
        color = AppColors.red;
      } else {
        color = AppColors.green;
      }

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.85));

      // 电压标注 (V, 3 位小数), 水平绘制
      final tp = _text(v.toStringAsFixed(3), labelSize,
          isDark ? Colors.white70 : Colors.black54,
          bold: i == maxIdx || i == minIdx,
          colorOverride: i == maxIdx && !spreadSmall
              ? AppColors.blue
              : (i == minIdx && !spreadSmall ? AppColors.red : null));
      canvas.save();
      canvas.translate(cx, top - 3);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height));
      canvas.restore();

      // 编号
      final noTp = _text('${i + 1}', 9.5,
          isDark ? Colors.white38 : Colors.black38);
      noTp.paint(canvas, Offset(cx - noTp.width / 2, bottom + 2));
    }

    // 右侧: 压差摘要 (V)
    final sumTp = _text(
      'Δ ${(vmax - vmin).toStringAsFixed(3)} V',
      10.5,
      (vmax - vmin) > 0.1
          ? AppColors.red
          : (isDark ? Colors.white54 : Colors.black45),
      bold: true,
    );
    sumTp.paint(canvas, Offset(size.width - sumTp.width - 2, 0));
  }

  TextPainter _text(String text, double size, Color color,
      {bool bold = false, Color? colorOverride}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: colorOverride ?? color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  @override
  bool shouldRepaint(_CellBarsPainter old) =>
      old.voltages != voltages || old.isDark != isDark;
}
