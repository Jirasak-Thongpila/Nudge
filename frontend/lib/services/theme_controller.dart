import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight singleton controller managing theme state (Dark / Light / System)
/// with persistence via SharedPreferences.
class ThemeController extends ValueNotifier<ThemeMode> {
  static final ThemeController instance = ThemeController._();

  static const String _prefKey = 'nudge_theme_mode';

  ThemeController._() : super(ThemeMode.dark);

  /// Check if the current mode is dark
  bool get isDarkMode => value == ThemeMode.dark;

  /// Initialize theme mode from local storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_prefKey);
      if (modeString == 'light') {
        value = ThemeMode.light;
      } else if (modeString == 'dark') {
        value = ThemeMode.dark;
      } else if (modeString == 'system') {
        value = ThemeMode.system;
      }
    } catch (_) {
      // In test environments or when SharedPreferences is unavailable,
      // fallback smoothly to default dark mode.
    }
  }

  /// Toggle between Dark Mode and Light Mode
  Future<void> toggleTheme() async {
    final nextMode = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  /// Set explicit ThemeMode and persist to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await prefs.setString(_prefKey, modeString);
    } catch (_) {
      // Ignore persistence failures gracefully
    }
  }
}
