import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestordelivros/services/reminder_service.dart';
import 'package:gestordelivros/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tema é salvo e restaurado', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SettingsService.loadThemeMode(), ThemeMode.system);
    await SettingsService.saveThemeMode(ThemeMode.dark);
    expect(await SettingsService.loadThemeMode(), ThemeMode.dark);
  });

  test('lembrete: padrão 20:00 desligado; salva horário', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SettingsService.loadReminderEnabled(), false);
    expect(await SettingsService.loadReminderTime(), const TimeOfDay(hour: 20, minute: 0));
    await SettingsService.saveReminder(enabled: true, time: const TimeOfDay(hour: 7, minute: 30));
    expect(await SettingsService.loadReminderEnabled(), true);
    expect(await SettingsService.loadReminderTime(), const TimeOfDay(hour: 7, minute: 30));
  });

  test('próxima ocorrência do lembrete: hoje se ainda não passou, senão amanhã', () {
    tzdata.initializeTimeZones();
    final loc = tz.getLocation('America/Sao_Paulo');
    final now = tz.TZDateTime(loc, 2026, 10, 26, 15, 0);
    final later = ReminderService.nextInstance(const TimeOfDay(hour: 20, minute: 0), now);
    expect(later, tz.TZDateTime(loc, 2026, 10, 26, 20, 0));
    final passed = ReminderService.nextInstance(const TimeOfDay(hour: 8, minute: 0), now);
    expect(passed, tz.TZDateTime(loc, 2026, 10, 27, 8, 0));
  });
}
