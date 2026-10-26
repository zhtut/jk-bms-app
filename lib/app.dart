import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_controller.dart';
import 'theme.dart';
import 'ui/home_shell.dart';

class JkBmsApp extends StatelessWidget {
  const JkBmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(),
      child: MaterialApp(
        title: 'JK BMS Monitor',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
