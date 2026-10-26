import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// 设备页: 设备信息 + 协议变体 + 数据导出 + 连接选项
class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final d = c.deviceInfo;
    final s = c.snapshot;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '设备信息',
            child: Column(
              children: [
                InfoRow(
                    label: '蓝牙地址',
                    value: c.targetDevice?.remoteId.str ?? '--'),
                InfoRow(label: '广播名称', value: c.targetName ?? '--'),
                InfoRow(label: '设备型号', value: d?.model ?? '--'),
                InfoRow(label: '设备名称', value: d?.name ?? '--'),
                InfoRow(label: '硬件版本', value: d?.hwVersion ?? '--'),
                InfoRow(label: '软件版本', value: d?.swVersion ?? '--'),
                InfoRow(label: '序列号', value: d?.serial ?? '--'),
                InfoRow(label: '生产日期', value: d?.mfgDate ?? '--'),
                InfoRow(
                    label: '本次开机时长',
                    value: d == null ? '--' : fmtDuration(d.uptimeSeconds)),
                InfoRow(
                    label: '上电次数',
                    value: d == null ? '--' : '${d.powerOnCount}'),
                InfoRow(
                    label: '累计运行时间',
                    value: fmtDuration(s?.runtimeSeconds)),
                InfoRow(
                  label: '学习满充容量',
                  value: s?.nominalCapacityAh == null
                      ? '--'
                      : '${s!.nominalCapacityAh!.toStringAsFixed(1)} Ah (BMS 自学习值, 新板不准)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '协议',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(
                  label: '当前变体',
                  value: (c.variant ?? c.variantOverride)?.label ?? '探测中...',
                ),
                const SizedBox(height: 8),
                Text('若数据明显异常 (如电压/串数不对), 可手动指定变体:',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black54)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _variantChip(context, c, null, '自动探测'),
                    for (final v in JkVariant.values)
                      _variantChip(context, c, v, v.label),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '数据与连接',
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('断线自动重连',
                          style: TextStyle(fontSize: 13.5)),
                    ),
                    Switch(
                      value: c.autoReconnect,
                      onChanged: c.setAutoReconnect,
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download_rounded,
                      color: AppColors.primary),
                  title: const Text('导出历史数据 (CSV)',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: Text('${c.history.samples.length} 条采样记录',
                      style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final path = await c.exportCsv();
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已导出: $path')));
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_off_rounded,
                      color: AppColors.red),
                  title: const Text('断开连接',
                      style: TextStyle(fontSize: 13.5, color: AppColors.red)),
                  onTap: () => c.disconnect(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'JK BMS Monitor · 协议参考 syssi/esphome-jk-bms · 仅供个人学习使用',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantChip(
      BuildContext context, AppController c, JkVariant? v, String label) {
    final selected = c.variantOverride == v;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => c.setVariantOverride(v),
    );
  }
}
