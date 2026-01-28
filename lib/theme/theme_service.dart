import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _key = 'theme_mode';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);

    if (v == 'light') {
      themeMode.value = ThemeMode.light;
    } else if (v == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.system;
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;

    final prefs = await SharedPreferences.getInstance();
    final v = (mode == ThemeMode.light)
        ? 'light'
        : (mode == ThemeMode.dark)
            ? 'dark'
            : 'system';

    await prefs.setString(_key, v);
  }
}
