import 'package:flutter/material.dart';

import '../../theme.dart';

/// 大电池电量表 (仿极空 App 主界面): 电池图形 + SOC% + 充放电状态
class BatteryGauge extends StatelessWidget {
  const BatteryGauge({
    super.key,
    required this.soc,
    required this.charging,
    required this.discharging,
    this.powerW,
    this.current,
  });

  final int? soc; // %
  final bool charging;
  final bool discharging;
  final double? powerW;
  final double? current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = charging
        ? AppColors.green
        : discharging
            ? AppColors.orange
            : AppColors.primary;
    final statusText = charging
        ? '充电中'
        : discharging
            ? '放电中'
            : '空闲';
    final statusIcon = charging
        ? Icons.arrow_upward_rounded
        : discharging
            ? Icons.arrow_downward_rounded
            : Icons.power_settings_new_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 96,
          child: CustomPaint(
            painter: _BatteryPainter(
              soc: (soc ?? 0) / 100.0,
              fillColor: fillColor,
              outlineColor: isDark ? Colors.white54 : const Color(0xFF5A6675),
            ),
            child: SizedBox(
              width: 190,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    soc == null ? '--' : '$soc%',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212B36),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fillColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: fillColor),
                  const SizedBox(width: 4),
                  Text(statusText,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: fillColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${fmtNum(powerW, 1)} W',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '电流 ${current == null ? '--' : '${current! > 0 ? '+' : ''}${current!.toStringAsFixed(2)}'} A',
          style: TextStyle(
              fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
        ),
      ],
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({
    required this.soc,
    required this.fillColor,
    required this.outlineColor,
  });

  final double soc; // 0..1
  final Color fillColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const capW = 10.0;
    final bodyW = w - capW - 4;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.08, bodyW, h * 0.84),
      const Radius.circular(10),
    );

    // 外框
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = outlineColor;
    canvas.drawRRect(bodyRect, outline);

    // 正极帽
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyW + 5, h * 0.32, capW, h * 0.36),
      const Radius.circular(3),
    );
    canvas.drawRRect(capRect, Paint()..color = outlineColor);

    // 电量填充
    final inner = Rect.fromLTWH(6, h * 0.08 + 6, bodyW - 12, h * 0.84 - 12);
    final fillW = inner.width * soc.clamp(0.0, 1.0);
    if (fillW > 2) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, fillW, inner.height),
        const Radius.circular(5),
      );
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [fillColor.withValues(alpha: 0.75), fillColor],
        ).createShader(fillRect.outerRect);
      canvas.drawRRect(fillRect, fill);
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) =>
      old.soc != soc || old.fillColor != fillColor;
}
