import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências simples do usuário (tema, lembrete diário...).
class SettingsService {
  static const _themeKey = 'theme_mode';
  static const _reminderOnKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';

  static Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_themeKey)) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
      }
    } catch (_) {}
    return ThemeMode.system;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {}
  }

  // --- Lembrete diário ---
  static Future<bool> loadReminderEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_reminderOnKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Horário do lembrete (padrão 20:00).
  static Future<TimeOfDay> loadReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return TimeOfDay(hour: prefs.getInt(_reminderHourKey) ?? 20, minute: prefs.getInt(_reminderMinuteKey) ?? 0);
    } catch (_) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
  }

  static Future<void> saveReminder({required bool enabled, required TimeOfDay time}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderOnKey, enabled);
      await prefs.setInt(_reminderHourKey, time.hour);
      await prefs.setInt(_reminderMinuteKey, time.minute);
    } catch (_) {}
  }
}
