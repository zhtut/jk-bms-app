import 'package:flutter/material.dart';

/// 极空 App 风格配色
class AppColors {
  AppColors._();
  static const primary = Color(0xFF1E88E5); // 极空蓝
  static const primaryDark = Color(0xFF1565C0);
  static const bgLight = Color(0xFFF2F4F8);
  static const cardLight = Colors.white;
  static const bgDark = Color(0xFF12161C);
  static const cardDark = Color(0xFF1C232B);
  static const green = Color(0xFF43A047); // 充电/正常
  static const orange = Color(0xFFFB8C00); // 放电
  static const red = Color(0xFFE53935); // 告警/最高电芯
  static const blue = Color(0xFF1E88E5); // 最低电芯
  static const gray = Color(0xFF9AA4B2);
}

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
  );
  return _decorate(base, AppColors.cardLight, Colors.black87, Colors.black54);
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
  );
  return _decorate(base, AppColors.cardDark, Colors.white, Colors.white60);
}

ThemeData _decorate(
    ThemeData base, Color card, Color textPrimary, Color textSecondary) {
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
    dividerTheme: DividerThemeData(color: textSecondary.withValues(alpha: 0.15)),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
    ),
  );
}

/// 数值格式化辅助
String fmtNum(double? v, [int digits = 2]) =>
    v == null ? '--' : v.toStringAsFixed(digits);

String fmtInt(int? v) => v == null ? '--' : '$v';

/// 秒 → "12天 3小时 45分"
String fmtDuration(int? seconds) {
  if (seconds == null) return '--';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '$d天 $h小时 $m分';
  if (h > 0) return '$h小时 $m分';
  return '$m分钟';
}
