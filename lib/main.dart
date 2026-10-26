import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端窗口设置 (Web/移动端跳过)
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      await windowManager.ensureInitialized();
      const options = WindowOptions(
        size: Size(1180, 820),
        minimumSize: Size(420, 640),
        center: true,
        title: 'JK BMS Monitor - 极空保护板监控',
        titleBarStyle: TitleBarStyle.normal,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setTitle(
            'JK BMS Monitor - 极空保护板监控');
        await windowManager.setMinimumSize(const Size(420, 640));
        await windowManager.center();
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // 窗口设置失败不影响应用启动
    }
  }

  runApp(const JkBmsApp());
}
