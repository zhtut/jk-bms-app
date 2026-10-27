import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../protocol/errors.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'pages/alarms_page.dart';
import 'pages/connect_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/debug_page.dart';
import 'pages/device_page.dart';
import 'pages/params_page.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _navItems = [
  _NavItem('监控', Icons.dashboard_outlined, Icons.dashboard),
  _NavItem('告警', Icons.warning_amber_rounded, Icons.warning_rounded),
  _NavItem('参数', Icons.tune_rounded, Icons.tune_rounded),
  _NavItem('设备', Icons.memory_rounded, Icons.memory_rounded),
  _NavItem('调试', Icons.bug_report_outlined, Icons.bug_report),
];

/// 主框架: 未连接时显示连接页; 已连接时按宽度显示侧边导航或底部导航
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    if (!c.isConnected) {
      return const ConnectPage();
    }

    final pages = [
      const DashboardPage(),
      const AlarmsPage(),
      const ParamsPage(),
      const DevicePage(),
      const DebugPage(),
    ];

    final alarmCount =
        JkErrorBits.activeBits(c.snapshot?.errorsBitmask ?? 0).length;
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(state: c.state),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              c.deviceInfo?.name.isNotEmpty == true
                  ? c.deviceInfo!.name
                  : (c.targetName ?? 'JK BMS'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (c.variant != null)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(c.variant!.label,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        if (c.rssi != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(_rssiIcon(c.rssi!),
                    size: 16, color: Colors.white70),
                const SizedBox(width: 3),
                Text('${c.rssi}',
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.white70)),
              ],
            ),
          ),
        if (c.statusText.isNotEmpty)
          IconButton(
            tooltip: c.statusText,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('状态'),
                  content: Text(c.statusText),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭')),
                  ],
                ),
              );
            },
          ),
        IconButton(
          tooltip: '断开连接',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.link_off_rounded),
          onPressed: () => c.disconnect(),
        ),
        const SizedBox(width: 8),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
              destinations: [
                for (int i = 0; i < _navItems.length; i++)
                  NavigationRailDestination(
                    icon: i == 1 && alarmCount > 0
                        ? Badge(
                            label: Text('$alarmCount'),
                            backgroundColor: AppColors.red,
                            child: Icon(_navItems[i].icon),
                          )
                        : Icon(_navItems[i].icon),
                    selectedIcon: Icon(_navItems[i].selectedIcon),
                    label: Text(_navItems[i].label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (int i = 0; i < _navItems.length; i++)
            NavigationDestination(
              icon: i == 1 && alarmCount > 0
                  ? Badge(
                      label: Text('$alarmCount'),
                      backgroundColor: AppColors.red,
                      child: Icon(_navItems[i].icon),
                    )
                  : Icon(_navItems[i].icon),
              selectedIcon: Icon(_navItems[i].selectedIcon),
              label: _navItems[i].label,
            ),
        ],
      ),
    );
  }

  IconData _rssiIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt_rounded;
    if (rssi >= -75) return Icons.signal_cellular_alt_2_bar_rounded;
    return Icons.signal_cellular_alt_1_bar_rounded;
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state});
  final ConnState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ConnState.running => AppColors.green,
      ConnState.waitingData => AppColors.orange,
      ConnState.connecting => AppColors.orange,
      ConnState.error => AppColors.red,
      _ => AppColors.gray,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
    );
  }
}
