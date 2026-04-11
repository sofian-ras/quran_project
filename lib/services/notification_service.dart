import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── Clés SharedPreferences ────────────────────────────────────────────────────
const _kDailyEnabled  = 'notif_daily_enabled';
const _kDailyHour     = 'notif_daily_hour';
const _kDailyMinute   = 'notif_daily_minute';
const _kPrayersEnabled = 'notif_prayers_enabled';

// ── IDs de notification ───────────────────────────────────────────────────────
const _kDailyId   = 1;
const _kFajrId    = 10;
const _kDhuhrId   = 11;
const _kAsrId     = 12;
const _kMaghribId = 13;
const _kIshaId    = 14;

const _kChannelId   = 'quran_reminders';
const _kChannelName = 'Rappels Quran';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  // ── Permissions (Android 13+) ─────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  // ── Canal Android ─────────────────────────────────────────────────────────
  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: 'Rappels de lecture et alertes de prière',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

  // ── Rappel quotidien ──────────────────────────────────────────────────────
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _kDailyId,
      'Rappel de lecture',
      'N\'oubliez pas votre lecture du Coran aujourd\'hui 📖',
      scheduled,
      NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, true);
    await prefs.setInt(_kDailyHour, time.hour);
    await prefs.setInt(_kDailyMinute, time.minute);
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_kDailyId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, false);
  }

  // ── Notifications de prières ──────────────────────────────────────────────
  Future<void> schedulePrayerNotifications(
      Map<String, DateTime> prayerTimes) async {
    await init();
    final ids = {
      'Fajr': _kFajrId,
      'Dhuhr': _kDhuhrId,
      'Asr': _kAsrId,
      'Maghrib': _kMaghribId,
      'Isha': _kIshaId,
    };
    final arabicNames = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };

    for (final entry in prayerTimes.entries) {
      final id = ids[entry.key];
      if (id == null) continue;
      final prayerTime = entry.value;
      if (prayerTime.isBefore(DateTime.now())) continue;

      final tzTime = tz.TZDateTime.from(prayerTime, tz.local);
      await _plugin.zonedSchedule(
        id,
        'Heure de prière — ${arabicNames[entry.key] ?? entry.key}',
        'C\'est l\'heure de ${entry.key}',
        tzTime,
        NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrayersEnabled, true);
  }

  Future<void> cancelPrayerNotifications() async {
    for (final id in [_kFajrId, _kDhuhrId, _kAsrId, _kMaghribId, _kIshaId]) {
      await _plugin.cancel(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrayersEnabled, false);
  }

  // ── Lecture des préférences ───────────────────────────────────────────────
  Future<bool> isDailyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDailyEnabled) ?? false;
  }

  Future<TimeOfDay> getDailyTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour:   prefs.getInt(_kDailyHour)   ?? 8,
      minute: prefs.getInt(_kDailyMinute) ?? 0,
    );
  }

  Future<bool> arePrayersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrayersEnabled) ?? false;
  }
}
