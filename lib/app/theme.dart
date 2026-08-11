import 'package:flutter/material.dart';

/// 统一设计系统：Teal 主题色，契合康复、成长、信任氛围。
/// 支持亮色 / 深色 / 跟随系统（由 ThemeModeNotifier 控制）。
class AppTheme {
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealDark = Color(0xFF0D9488);
  static const Color tealSoft = Color(0xFF5EEAD4);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: teal,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD6FBF4),
    onPrimaryContainer: Color(0xFF003B36),
    secondary: Color(0xFF0EA5A4),
    onSecondary: Colors.white,
    surface: Color(0xFFF7FAFA),
    onSurface: Color(0xFF102A27),
    surfaceContainerHighest: Color(0xFFE6EFEE),
    onSurfaceVariant: Color(0xFF5B6F6C),
    error: Color(0xFFD14343),
    onError: Colors.white,
    outline: Color(0xFFCFE0DD),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: tealSoft,
    onPrimary: Color(0xFF003B36),
    primaryContainer: Color(0xFF0C3F3A),
    onPrimaryContainer: Color(0xFF9FF3E6),
    secondary: Color(0xFF2DD4BF),
    onSecondary: Color(0xFF003B36),
    surface: Color(0xFF0E1716),
    onSurface: Color(0xFFE6EFEE),
    surfaceContainerHighest: Color(0xFF1B2725),
    onSurfaceVariant: Color(0xFFA6BDB9),
    error: Color(0xFFFF8A8A),
    onError: Color(0xFF3B0A0A),
    outline: Color(0xFF334A47),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: _lightScheme.surface,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF102A27),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F6F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: _darkScheme,
    scaffoldBackgroundColor: _darkScheme.surface,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFE6EFEE),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFF16211F),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1B2725),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
