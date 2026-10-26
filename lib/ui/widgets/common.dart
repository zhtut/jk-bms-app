import 'package:flutter/material.dart';

import '../../theme.dart';

/// 指标卡片: 标签 + 大数值 + 单位 (仿极空 App 网格卡片)
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.color,
    this.icon,
    this.digits = 2,
  });

  final String label;

  /// 传 double 自动格式化; 传 String 原样显示; null 显示 '--'
  final Object? value;
  final String unit;
  final Color? color;
  final IconData? icon;
  final int digits;

  String get _text => switch (value) {
        null => '--',
        double d => d.isFinite ? d.toStringAsFixed(digits) : '--',
        int i => '$i',
        String s => s.isEmpty ? '--' : s,
        _ => value.toString(),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black45),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    _text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color ??
                          (isDark ? Colors.white : const Color(0xFF212B36)),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 带标题的分区卡片
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 15,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 状态指示灯 + 标签 (MOS / 均衡 / 加热等只读状态)
class StatusLamp extends StatelessWidget {
  const StatusLamp({
    super.key,
    required this.label,
    required this.on,
    this.onColor = AppColors.green,
    this.sublabel,
  });

  final String label;
  final bool? on;
  final Color onColor;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color lampColor = on == null
        ? AppColors.gray
        : on!
            ? onColor
            : (isDark ? Colors.white24 : const Color(0xFFD5DBE3));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: lampColor,
            shape: BoxShape.circle,
            boxShadow: on == true
                ? [
                    BoxShadow(
                      color: onColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
        if (sublabel != null)
          Text(sublabel!,
              style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : Colors.black38)),
        Text(
          on == null ? '--' : (on! ? '开启' : '关闭'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: on == true ? onColor : AppColors.gray,
          ),
        ),
      ],
    );
  }
}

/// 键值行 (设备信息 / 参数页)
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : Colors.black54)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: valueColor ??
                    (isDark ? Colors.white : const Color(0xFF212B36)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
