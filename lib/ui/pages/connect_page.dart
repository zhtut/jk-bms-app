import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';

/// 连接页: 扫描设备列表 + 连接 + 排障帮助
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  @override
  void initState() {
    super.initState();
    // 首次进入自动扫描
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<AppController>();
      if (c.state == ConnState.idle) c.startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('JK BMS Monitor'),
        actions: [
          IconButton(
            tooltip: '重新扫描',
            icon: const Icon(Icons.refresh),
            onPressed: c.state == ConnState.scanning ? null : c.startScan,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _Header(state: c.state, adapterState: c.adapterState),
              const SizedBox(height: 14),
              if (c.state == ConnState.connecting)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: c.cancelConnect,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('取消连接',
                          style: TextStyle(fontSize: 15)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 13),
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: c.startScan,
                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
                  label: const Text('扫描设备', style: TextStyle(fontSize: 15)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
              const SizedBox(height: 10),
              if (c.statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(c.statusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.red)),
                ),
              Expanded(
                child: c.scanResults.isEmpty
                    ? _EmptyHint(scanning: c.state == ConnState.scanning)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: c.scanResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _DeviceTile(
                          result: c.scanResults[i],
                          busy: c.connectingId ==
                              c.scanResults[i].device.remoteId.str,
                        ),
                      ),
              ),
              if (!c.isWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Switch(
                        value: c.showAllDevices,
                        onChanged: c.setShowAllDevices,
                      ),
                      const Text('显示所有蓝牙设备', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              const _HelpSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.adapterState});

  final ConnState state;
  final BluetoothAdapterState adapterState;

  @override
  Widget build(BuildContext context) {
    final scanning = state == ConnState.scanning;
    final connecting = state == ConnState.connecting;
    String title;
    String? subtitle;
    if (connecting) {
      title = '正在连接...';
      subtitle = null;
    } else if (adapterState == BluetoothAdapterState.off) {
      title = '蓝牙未开启';
      subtitle = '请先在系统中打开蓝牙';
    } else if (adapterState == BluetoothAdapterState.unauthorized) {
      title = '无蓝牙权限';
      subtitle = '请在系统设置中授予本应用蓝牙权限';
    } else if (adapterState == BluetoothAdapterState.unavailable) {
      title = '蓝牙不可用';
      subtitle = '未检测到蓝牙适配器';
    } else {
      title = scanning ? '正在搜索附近的极空保护板...' : '选择要连接的保护板';
      subtitle = scanning ? null : '点击"刷新"开始扫描';
    }
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: scanning
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(
                  connecting
                      ? Icons.bluetooth_connected_rounded
                      : Icons.battery_charging_full_rounded,
                  size: 36,
                  color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.gray)),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_searching_rounded,
              size: 52,
              color: AppColors.gray.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            scanning ? '搜索中, 请确保保护板已上电且未被手机 App 占用...' : '未发现设备',
            style: const TextStyle(fontSize: 13.5, color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.result, required this.busy});

  final ScanResult result;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    final advName = result.advertisementData.advName;
    final name = AppController.deviceNameOf(result);
    final isJk = AppController.isLikelyJkDevice(result);
    final hasName = advName.isNotEmpty;
    return Card(
      child: ListTile(
        leading: Icon(
          isJk
              ? Icons.battery_charging_full_rounded
              : Icons.bluetooth_rounded,
          color: isJk ? AppColors.primary : AppColors.gray,
        ),
        title: Text(
          hasName ? name : '未命名设备 (疑似极空)',
          style: TextStyle(
              fontWeight: isJk ? FontWeight.w600 : FontWeight.w400),
        ),
        subtitle: Text(
          '${result.device.remoteId.str}  ·  ${result.rssi} dBm'
          '${!hasName && isJk ? '  ·  识别依据: ${AppController.jkMatchReason(result)}' : ''}',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton.tonal(
                onPressed: () => c.connectTo(result),
                child: const Text('连接'),
              ),
        onTap: busy ? null : () => c.connectTo(result),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.help_outline_rounded,
              color: AppColors.gray),
          title: const Text('连不上？常见排查', style: TextStyle(fontSize: 13.5)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _helpLine('1. 保护板蓝牙同一时间通常只允许一个连接 —— 请先断开手机 App（极空BMS）后再扫描。'),
                  _helpLine('2. 部分型号需短按保护板电源键唤醒蓝牙。'),
                  if (c.isWeb)
                    _helpLine(
                        '3. Web 版仅支持 Chrome / Edge，且需通过 https:// 或 localhost 访问；点击扫描后在浏览器弹窗中选择设备。'),
                  if (!c.isWeb)
                    _helpLine('3. 确认电脑具备 BLE 4.0+ 蓝牙；Windows 请确认系统蓝牙已开启。'),
                  _helpLine('4. 连接成功但无数据：到"设备"页手动切换协议变体（JK02-24S / JK02-32S / JK04），并到"调试"页查看原始字节。'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _helpLine(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, color: AppColors.gray, height: 1.45)),
      );
}
