import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式：亮色 / 深色 / 跟随系统。持久化到 SharedPreferences。
final StateNotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _init();
  }

  static const String _key = 'teacher_app_theme_mode';

  Future<void> _init() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? v = prefs.getString(_key);
      if (v != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.name == v,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {
      // 忽略持久化读取失败，使用默认 system
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // 忽略
    }
  }

  void cycle() {
    final int idx = ThemeMode.values.indexOf(state);
    set(ThemeMode.values[(idx + 1) % ThemeMode.values.length]);
  }
}
