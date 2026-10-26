import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../protocol/errors.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// 参数页: 只读展示保护参数 (不提供写入)
class ParamsPage extends StatelessWidget {
  const ParamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final st = c.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_rounded, size: 17, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '监控模式：本程序仅提供参数查看，不向保护板写入任何设置，避免误操作损坏电池组。',
                    style: TextStyle(fontSize: 12.5, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (st == null)
            SectionCard(
              title: '保护参数',
              trailing: TextButton.icon(
                onPressed: c.refreshSettings,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('重新请求', style: TextStyle(fontSize: 12)),
              ),
              child: const Text(
                  '等待参数帧 (0x01)... 连接后会自动查询; 也可点击"重新请求"。若始终无数据, 请到"设备"页切换协议变体',
                  style: TextStyle(fontSize: 13, color: AppColors.gray)),
            )
          else ...[
            SectionCard(
              title: '电芯电压保护',
              trailing: TextButton.icon(
                onPressed: c.refreshSettings,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
              child: Column(
                children: [
                  InfoRow(label: '单体过压保护 (OVP)', value: _v(st.cellOvp)),
                  InfoRow(label: '单体过压恢复', value: _v(st.cellOvpRecovery)),
                  InfoRow(label: '单体欠压保护 (UVP)', value: _v(st.cellUvp)),
                  InfoRow(label: '单体欠压恢复', value: _v(st.cellUvpRecovery)),
                  InfoRow(label: 'SOC 100% 电压', value: _v(st.soc100Voltage)),
                  InfoRow(label: 'SOC 0% 电压', value: _v(st.soc0Voltage)),
                  InfoRow(label: '关机电压', value: _v(st.powerOffVoltage)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '电流保护',
              child: Column(
                children: [
                  InfoRow(label: '最大充电电流', value: _a(st.maxChargeCurrent)),
                  InfoRow(
                      label: '充电过流延时',
                      value: _s(st.chargeOcpDelaySeconds)),
                  InfoRow(
                      label: '充电过流恢复时间',
                      value: _s(st.chargeOcpRecoverySeconds)),
                  InfoRow(label: '最大放电电流', value: _a(st.maxDischargeCurrent)),
                  InfoRow(
                      label: '放电过流延时',
                      value: _s(st.dischargeOcpDelaySeconds)),
                  InfoRow(
                      label: '放电过流恢复时间',
                      value: _s(st.dischargeOcpRecoverySeconds)),
                  InfoRow(
                      label: '短路保护恢复时间',
                      value: _s(st.shortCircuitRecoverySeconds)),
                  if (st.shortCircuitDelayMicros != null)
                    InfoRow(
                        label: '短路保护延时',
                        value: '${st.shortCircuitDelayMicros} μs'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '温度保护',
              child: Column(
                children: [
                  InfoRow(label: '充电过温保护', value: _t(st.chargeOtp)),
                  InfoRow(label: '充电过温恢复', value: _t(st.chargeOtpRecovery)),
                  InfoRow(label: '充电低温保护', value: _t(st.chargeUtp)),
                  InfoRow(label: '充电低温恢复', value: _t(st.chargeUtpRecovery)),
                  InfoRow(label: '放电过温保护', value: _t(st.dischargeOtp)),
                  InfoRow(label: '放电过温恢复', value: _t(st.dischargeOtpRecovery)),
                  InfoRow(label: '放电低温保护', value: _t(st.dischargeUtp)),
                  InfoRow(label: '放电低温恢复', value: _t(st.dischargeUtpRecovery)),
                  InfoRow(label: 'MOS 过温保护', value: _t(st.mosOtp)),
                  InfoRow(label: 'MOS 过温恢复', value: _t(st.mosOtpRecovery)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '均衡',
              child: Column(
                children: [
                  InfoRow(label: '均衡开关', value: _b(st.balancerSwitch)),
                  InfoRow(label: '均衡启动电压', value: _v(st.balanceStartVoltage)),
                  InfoRow(label: '均衡触发压差', value: _v(st.balanceTriggerVoltage)),
                  InfoRow(label: '最大均衡电流', value: _a(st.maxBalanceCurrent)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '基本参数',
              child: Column(
                children: [
                  InfoRow(
                      label: '电芯串数',
                      value: st.cellCount == null ? '--' : '${st.cellCount}'),
                  InfoRow(label: '充电开关 (设置)', value: _b(st.chargeSwitch)),
                  InfoRow(label: '放电开关 (设置)', value: _b(st.dischargeSwitch)),
                  InfoRow(label: '标称容量', value: _ah(st.nominalCapacityAh)),
                  if (st.smartSleepHours != null)
                    InfoRow(label: '智能休眠', value: '${st.smartSleepHours} 小时'),
                  if (st.heatingStartTempC != null)
                    InfoRow(
                        label: '加热启动/停止温度',
                        value: '${st.heatingStartTempC} / ${st.heatingStopTempC} °C'),
                  if (st.deviceAddress != null)
                    InfoRow(label: '设备地址', value: '${st.deviceAddress}'),
                  if (st.controlsBitmask != null)
                    InfoRow(
                        label: '控制位',
                        value: JkControlsBits.active(st.controlsBitmask!)
                                    .isEmpty
                                ? '--'
                                : JkControlsBits.active(st.controlsBitmask!)
                                    .join('、')),
                  if (st.voltageCalibration != null)
                    InfoRow(
                        label: '电压校准系数',
                        value: st.voltageCalibration!.toStringAsFixed(4)),
                ],
              ),
            ),
            if (st.wireResistances != null &&
                st.wireResistances!.any((r) => r > 0)) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: '连接线电阻 (mΩ)',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < st.wireResistances!.length; i++)
                      if (st.wireResistances![i] > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${i + 1}  ${(st.wireResistances![i] * 1000).round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _v(double? x) => x == null ? '--' : '${x.toStringAsFixed(3)} V';
  static String _a(double? x) => x == null ? '--' : '${x.toStringAsFixed(2)} A';
  static String _ah(double? x) => x == null ? '--' : '${x.toStringAsFixed(1)} Ah';
  static String _t(double? x) => x == null ? '--' : '${x.toStringAsFixed(1)} °C';
  static String _s(int? x) => x == null ? '--' : '$x s';
  static String _b(bool? x) => x == null ? '--' : (x ? '开启' : '关闭');
}
