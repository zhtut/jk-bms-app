import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../protocol/errors.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/cell_bars.dart';
import '../widgets/common.dart';
import '../widgets/trend_chart.dart';

/// 主监控页 (仿极空 App 电池数据页, 紧凑布局)
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final s = c.snapshot;
    const padding = EdgeInsets.fromLTRB(14, 10, 14, 20);

    if (s == null) {
      return _WaitingView(statusText: c.statusText);
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AlarmBanner(snapshot: s),
          const SizedBox(height: 10),
          _TopCard(s: s),
          const SizedBox(height: 10),
          _StatusOverview(s: s, settingsNominalAh: c.settings?.nominalCapacityAh),
          const SizedBox(height: 10),
          SectionCard(
            title: '电芯电压',
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            trailing: _DeltaChip(s: s),
            child: Column(
              children: [
                CellBarsChart(voltages: s.cellVoltages, height: 170),
                const SizedBox(height: 6),
                _CellSummaryRow(s: s),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: '历史趋势',
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            trailing: TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('清空', style: TextStyle(fontSize: 12)),
              onPressed: c.clearHistory,
            ),
            child: TrendChart(samples: List.of(c.history.samples)),
          ),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.statusText});
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 44, height: 44, child: CircularProgressIndicator()),
          const SizedBox(height: 18),
          Text(
            statusText.isEmpty ? '等待 BMS 数据...' : statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.gray),
          ),
          const SizedBox(height: 6),
          const Text('保护板约每 0.5~2 秒推送一帧数据 (界面 5 秒刷新一次)',
              style: TextStyle(fontSize: 12, color: AppColors.gray)),
        ],
      ),
    );
  }
}

class _AlarmBanner extends StatelessWidget {
  const _AlarmBanner({required this.snapshot});
  final JkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bits = JkErrorBits.activeBits(snapshot.errorsBitmask);
    if (bits.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 17, color: AppColors.green),
            SizedBox(width: 8),
            Text('系统正常',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, size: 17, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              children: bits
                  .map((b) => Text(JkErrorBits.labelZh(b),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部紧凑卡: 电池仪表 + 6 个核心指标 (小块徽章式, 与状态总览同密度)
class _TopCard extends StatelessWidget {
  const _TopCard({required this.s});
  final JkSnapshot s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    final chips = Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _stat(context, '电池电压', fmtNum(s.totalVoltage, 2), 'V'),
        _stat(
          context,
          '电池电流',
          fmtNum(s.current, 2),
          'A',
          color: s.isCharging
              ? AppColors.green
              : s.isDischarging
                  ? AppColors.orange
                  : null,
        ),
        _stat(context, '电池功率', fmtNum(s.power, 1), 'W'),
        _stat(context, '剩余容量', fmtNum(s.remainingCapacityAh, 1), 'Ah'),
        _stat(context, '循环次数', fmtInt(s.cycleCount), '次'),
        _stat(
            context,
            '均衡电流',
            s.balanceCurrent == null
                ? '--'
                : (s.balanceCurrent! * 1000).round().toString(),
            'mA'),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: LayoutBuilder(builder: (context, cons) {
          if (cons.maxWidth > 700) {
            return Row(
              children: [
                SizedBox(
                  width: 230,
                  child: BatteryGauge(
                    soc: s.soc,
                    charging: s.isCharging,
                    discharging: s.isDischarging,
                    powerW: s.power,
                    current: s.current,
                  ),
                ),
                Container(width: 1, height: 74, color: dividerColor),
                const SizedBox(width: 14),
                Expanded(child: chips),
              ],
            );
          }
          return Column(
            children: [
              BatteryGauge(
                soc: s.soc,
                charging: s.isCharging,
                discharging: s.isDischarging,
                powerW: s.power,
                current: s.current,
              ),
              const SizedBox(height: 10),
              chips,
            ],
          );
        }),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, String unit,
      {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: color ??
                      (isDark ? Colors.white : const Color(0xFF212B36)))),
          const SizedBox(width: 3),
          Text(unit,
              style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : Colors.black45)),
        ],
      ),
    );
  }
}

/// 紧凑状态总览: 温度 / 开关状态 / 电池信息 三区合一
class _StatusOverview extends StatelessWidget {
  const _StatusOverview({required this.s, required this.settingsNominalAh});
  final JkSnapshot s;
  final double? settingsNominalAh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    final temps = <Widget>[
      _kv('传感器1', _temp(s.temp1), _tempColor(s.temp1)),
      _kv('传感器2', _temp(s.temp2), _tempColor(s.temp2)),
      if (s.temp3 != null) _kv('传感器3', _temp(s.temp3), _tempColor(s.temp3)),
      if (s.temp4 != null) _kv('传感器4', _temp(s.temp4), _tempColor(s.temp4)),
      if (s.temp5 != null) _kv('传感器5', _temp(s.temp5), _tempColor(s.temp5)),
      _kv('MOS', _temp(s.mosTemp), _tempColor(s.mosTemp)),
      if (s.heatingCurrent != null && s.heatingCurrent!.abs() > 0.001)
        _kv('加热电流', '${(s.heatingCurrent! * 1000).round()} mA', AppColors.orange),
    ];

    final switches = <Widget>[
      _lamp('充电MOS', s.chargeMosOn),
      _lamp('放电MOS', s.dischargeMosOn),
      _lamp('均衡', s.balanceAction != 0 ? true : s.balancerWorking,
          onColor: AppColors.primary,
          sub: switch (s.balanceAction) {
            1 => '充电均衡',
            2 => '放电均衡',
            _ => null,
          }),
      _lamp('加热', s.heating, onColor: AppColors.orange),
      _lamp('预充', s.precharging),
      if (s.dryContact1 != null)
        _lamp('干接点1', s.dryContact1, onColor: AppColors.primary),
      if (s.dryContact2 != null)
        _lamp('干接点2', s.dryContact2, onColor: AppColors.primary),
    ];

    final battery = <Widget>[
      _kv('SOH', s.soh == null ? '--' : '${s.soh}%', null),
      _kv('标称容量',
          '${fmtNum(settingsNominalAh ?? s.nominalCapacityAh, 1)} Ah', null),
      _kv('循环容量', '${fmtNum(s.cycleCapacityAh, 1)} Ah', null),
      _kv('运行时间', fmtDuration(s.runtimeSeconds), null),
      if (s.batteryTypeId != null) _kv('电池类型', s.batteryTypeText, null),
      if (s.chargeStatusId != null) _kv('充电阶段', s.chargeStatusText, null),
      if (s.chargerConnected != null)
        _kv('充电器', s.chargerConnected! ? '已插入' : '未插入', null),
    ];

    Widget block(String title, List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: items),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: LayoutBuilder(builder: (context, cons) {
          if (cons.maxWidth >= 980) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: block('温度', temps)),
                _vDivider(dividerColor),
                Expanded(flex: 4, child: block('开关状态', switches)),
                _vDivider(dividerColor),
                Expanded(flex: 5, child: block('电池信息', battery)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block('温度', temps),
              const SizedBox(height: 10),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 10),
              block('开关状态', switches),
              const SizedBox(height: 10),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 10),
              block('电池信息', battery),
            ],
          );
        }),
      ),
    );
  }

  Widget _vDivider(Color color) => Container(
        width: 1,
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: color,
      );

  String _temp(double? t) => t == null ? '--' : '${t.toStringAsFixed(1)}°C';

  Color? _tempColor(double? t) {
    if (t == null) return null;
    if (t >= 55) return AppColors.red;
    if (t >= 45) return AppColors.orange;
    if (t <= 0) return AppColors.blue;
    return null;
  }

  /// 紧凑键值: "标签 值" 单行小字
  Widget _kv(String label, String value, Color? valueColor) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45)),
            const SizedBox(width: 5),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        (isDark ? Colors.white : const Color(0xFF212B36)))),
          ],
        ),
      );
    });
  }

  /// 紧凑指示灯: 圆点 + 名称 + 状态
  Widget _lamp(String label, bool? on, {Color onColor = AppColors.green, String? sub}) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final lampColor = on == null
          ? AppColors.gray
          : on
              ? onColor
              : (isDark ? Colors.white24 : const Color(0xFFD5DBE3));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: lampColor,
              shape: BoxShape.circle,
              boxShadow: on == true
                  ? [
                      BoxShadow(
                          color: onColor.withValues(alpha: 0.5), blurRadius: 5)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(width: 4),
          Text(sub ?? (on == null ? '--' : on ? '开' : '关'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: on == true ? onColor : AppColors.gray,
              )),
        ],
      );
    });
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.s});
  final JkSnapshot s;

  @override
  Widget build(BuildContext context) {
    final delta = s.deltaCellVoltage;
    final warn = delta != null && delta > 0.1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (warn ? AppColors.red : AppColors.primary)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '压差 ${delta == null ? '--' : delta.toStringAsFixed(3)} V',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: warn ? AppColors.red : AppColors.primary),
      ),
    );
  }
}

class _CellSummaryRow extends StatelessWidget {
  const _CellSummaryRow({required this.s});
  final JkSnapshot s;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, String value, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.gray)),
            const SizedBox(width: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        // 极空配色: 最高电压=蓝, 最低电压=红
        item(
            '最高',
            s.maxCellVoltage == null
                ? '--'
                : '#${s.maxCellNumber} ${s.maxCellVoltage!.toStringAsFixed(3)}V',
            AppColors.blue),
        item(
            '最低',
            s.minCellVoltage == null
                ? '--'
                : '#${s.minCellNumber} ${s.minCellVoltage!.toStringAsFixed(3)}V',
            AppColors.red),
        item(
            '平均',
            s.avgCellVoltage == null
                ? '--'
                : '${s.avgCellVoltage!.toStringAsFixed(3)}V',
            AppColors.green),
        item('启用', '${s.activeCellCount} 串', AppColors.gray),
      ],
    );
  }
}
