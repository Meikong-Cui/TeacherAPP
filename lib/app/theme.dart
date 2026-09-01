import 'package:flutter/material.dart';
import 'package:teacher_app/app/design_tokens.dart';

/// 统一设计系统：Teal 主题色，契合康复、成长、信任氛围。
/// 支持亮色 / 深色 / 跟随系统（由 ThemeModeNotifier 控制）。
///
/// 颜色 / 字号 / 圆角 / 阴影 / 间距等可视化常量统一从 design_tokens.dart 读取。
class AppTheme {
  static const Color teal = AppPalette.brand;
  static const Color tealDark = AppPalette.brandDark;
  static const Color tealSoft = AppPalette.brandSoft;

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: teal,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD6FBF4),
    onPrimaryContainer: Color(0xFF003B36),
    secondary: AppPalette.success,
    onSecondary: Colors.white,
    surface: Color(0xFFFFFFFF),
    onSurface: AppPalette.ink,
    surfaceContainerHighest: Color(0xFFEFF5F4),
    onSurfaceVariant: AppPalette.inkMute,
    error: AppPalette.danger,
    onError: Colors.white,
    outline: AppPalette.line,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: tealSoft,
    onPrimary: Color(0xFF003B36),
    primaryContainer: Color(0xFF0C3F3A),
    onPrimaryContainer: Color(0xFF9FF3E6),
    secondary: AppPalette.brand,
    onSecondary: Color(0xFF003B36),
    surface: Color(0xFF121C1A),
    onSurface: Color(0xFFE6EFEE),
    surfaceContainerHighest: Color(0xFF1F2A28),
    onSurfaceVariant: Color(0xFFA6BDB9),
    error: AppPalette.danger,
    onError: Color(0xFF3B0A0A),
    outline: Color(0xFF334A47),
  );

  static ThemeData _build(ColorScheme scheme) {
    final bool isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? scheme.surface : const Color(0xFFF4F8F8),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: AppFontSize.subtitle,
          fontWeight: AppFontWeight.extrabold,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          // 暗色模式下 surface 与背景同色，加描边以区分卡片边界
          side: isDark
              ? BorderSide(color: scheme.outline, width: 1)
              : BorderSide.none,
        ),
        color: scheme.surface,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: AppFontWeight.semibold,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: AppFontWeight.semibold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: AppFontWeight.semibold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : const Color(0xFFF0F6F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSize.body),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontSize: AppFontSize.small,
            fontWeight: AppFontWeight.medium,
            color: scheme.onSurface,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontSize: AppFontSize.small,
          fontWeight: AppFontWeight.semibold,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 0.6,
        space: 1,
      ),
    );
  }

  static final ThemeData light = _build(_lightScheme);
  static final ThemeData dark = _build(_darkScheme);
}
