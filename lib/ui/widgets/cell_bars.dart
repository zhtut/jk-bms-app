import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// 电芯电压柱状图 (仿极空 App): 每串一节电池形状, 标注编号与电压,
/// 最高蓝色 / 最低红色 / 其余绿色, 平均电压虚线。
///
/// 柱高按电压绝对比例计算 (最高电压 = 满高), 避免小压差被放大成
/// 悬殊的视觉高度差。
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

  /// 正极凸头高度 (逻辑像素)
  static const double _nubHeight = 4.0;

  /// 正极凸头宽度占柱宽比例
  static const double _nubWidthFactor = 0.42;

  /// 柱体最小高度比例 (保证接近 0V 的异常电芯仍可见)
  static const double _minHeightFactor = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final active = <int, double>{};
    for (int i = 0; i < voltages.length; i++) {
      final v = voltages[i];
      if (v != null && v > 0) active[i] = v;
    }
    if (active.isEmpty) return;

    final values = active.values.toList();
    final vmin = values.reduce(math.min);
    final vmax = values.reduce(math.max);
    final avg = values.reduce((a, b) => a + b) / values.length;

    final n = voltages.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.56, 30.0);
    const bottomLabelH = 16.0;
    // 电压标签水平绘制 (桌面端空间充足), 按槽宽自适应字号
    final labelSize = slot >= 52 ? 10.0 : (slot >= 38 ? 9.0 : 7.5);
    final topLabelH = labelSize + 8 + _nubHeight;
    final chartH = size.height - bottomLabelH - topLabelH;

    // 柱高 = 电压 / 最高电压, 最高串占满绘图区
    double bodyHeightOf(double v) =>
        chartH * (v / vmax).clamp(_minHeightFactor, 1.0);
    final bottom = topLabelH + chartH;

    final maxIdx = active.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final minIdx = active.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    final spreadSmall = (vmax - vmin) < 0.010; // 压差 <10mV 全绿

    // 平均虚线 (位于平均电压对应的柱高处)
    final avgY = bottom - bodyHeightOf(avg);
    final dashPaint = Paint()
      ..color = (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashPaint);
    }

    for (final entry in active.entries) {
      final i = entry.key;
      final v = entry.value;
      final cx = slot * i + slot / 2;
      final bodyH = bodyHeightOf(v);
      final top = bottom - bodyH;

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

      // 电池造型: 顶部正极凸头 + 圆角柱体
      final paint = Paint()..color = color.withValues(alpha: 0.85);
      final nubW = barW * _nubWidthFactor;
      final nub = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - nubW / 2, top - _nubHeight, cx + nubW / 2, top + 1),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(nub, paint);

      final body = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(body, paint);

      // 电压标注 (V, 3 位小数), 水平绘制, 位于凸头上方
      final tp = _text(v.toStringAsFixed(3), labelSize,
          isDark ? Colors.white70 : Colors.black54,
          bold: i == maxIdx || i == minIdx,
          colorOverride: i == maxIdx && !spreadSmall
              ? AppColors.blue
              : (i == minIdx && !spreadSmall ? AppColors.red : null));
      canvas.save();
      canvas.translate(cx, top - _nubHeight - 3);
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
