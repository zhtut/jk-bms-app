import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../protocol/errors.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// 告警页: 当前告警位 + 设备事件日志
class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final s = c.snapshot;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bits = JkErrorBits.activeBits(s?.errorsBitmask ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '当前告警',
            child: s == null
                ? const Text('等待数据...',
                    style: TextStyle(color: AppColors.gray, fontSize: 13))
                : bits.isEmpty
                    ? Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                color: AppColors.green, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('系统正常',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.green)),
                              const SizedBox(height: 2),
                              Text(
                                '告警位掩码: 0x${s.errorsBitmask.toRadixString(16).toUpperCase().padLeft(8, '0')}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white38 : Colors.black38),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: bits
                            .map((b) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.red.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_rounded,
                                          size: 18, color: AppColors.red),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(JkErrorBits.labelZh(b),
                                                style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.red)),
                                            Text(
                                                '${JkErrorBits.labelEn(b)} (bit $b)',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.black38)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '设备事件日志',
            trailing: TextButton.icon(
              onPressed: () => c.refreshLogbook(),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('刷新', style: TextStyle(fontSize: 12)),
            ),
            child: c.logbook.isEmpty
                ? Text(
                    '暂无日志 (点击"刷新"向设备请求; 部分固件不支持日志读取)',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white38 : Colors.black38),
                  )
                : Column(
                    children: [
                      for (final e in c.logbook)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(e.timeLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontFeatures: const [FontFeature.tabularFigures()])),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(JkLogbookCodes.zh(e.code),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                        '${JkLogbookCodes.en(e.code)} (0x${e.code.toRadixString(16).toUpperCase().padLeft(2, '0')})',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark
                                                ? Colors.white30
                                                : Colors.black38)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
