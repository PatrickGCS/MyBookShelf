import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'settings_service.dart';

/// Lembrete diário de leitura via notificação local agendada.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _notificationId = 1001;
  static const _channelId = 'daily_reading_reminder';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Mantém UTC se o fuso do aparelho não puder ser obtido
    }
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  /// Próxima ocorrência de [time] (hoje, ou amanhã se já passou).
  @visibleForTesting
  static tz.TZDateTime nextInstance(TimeOfDay time, tz.TZDateTime now) {
    var d = tz.TZDateTime(now.location, now.year, now.month, now.day, time.hour, time.minute);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }

  /// Pede permissão (Android 13+) e agenda o lembrete diário. Retorna false se negado.
  Future<bool> enable(TimeOfDay time) async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted == false) return false;
    await _schedule(time);
    await SettingsService.saveReminder(enabled: true, time: time);
    return true;
  }

  Future<void> disable() async {
    await init();
    await _plugin.cancel(_notificationId);
    final time = await SettingsService.loadReminderTime();
    await SettingsService.saveReminder(enabled: false, time: time);
  }

  /// Reagenda ao abrir o app, se o lembrete estiver ligado.
  Future<void> rescheduleIfEnabled() async {
    if (!await SettingsService.loadReminderEnabled()) return;
    await init();
    await _schedule(await SettingsService.loadReminderTime());
  }

  Future<void> _schedule(TimeOfDay time) async {
    await _plugin.cancel(_notificationId);
    await _plugin.zonedSchedule(
      _notificationId,
      '📚 Hora de ler!',
      'Leia algumas páginas hoje para manter sua sequência.',
      nextInstance(time, tz.TZDateTime.now(tz.local)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Lembrete de leitura',
          channelDescription: 'Lembrete diário para ler e manter a sequência',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Inexato: não exige a permissão de alarmes exatos
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repete todos os dias
    );
  }
}
