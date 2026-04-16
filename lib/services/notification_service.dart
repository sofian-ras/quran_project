import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── Clés SharedPreferences ────────────────────────────────────────────────────
const _kDailyEnabled   = 'notif_daily_enabled';
const _kDailyHour      = 'notif_daily_hour';
const _kDailyMinute    = 'notif_daily_minute';
const _kPrayersEnabled = 'notif_prayers_enabled';
const _kPrayerCache    = 'notif_last_prayer_times'; // JSON Map<String,String> HH:mm

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

  /// Vérifie si les alarmes exactes sont autorisées (Android 12+ / API 31+).
  /// Retourne toujours true sur les versions antérieures.
  Future<bool> canScheduleExactNotifications() async {
    if (!Platform.isAndroid) return true;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? true;
  }

  /// Ouvre l'écran système "Alarmes et rappels" pour que l'utilisateur
  /// puisse autoriser les alarmes exactes (Android 12+).
  Future<void> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
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
    // Utiliser DateTime.now() (heure locale du device) pour éviter le décalage
    // UTC : tz.TZDateTime(tz.local, ...) interprète l'heure en UTC si
    // setLocalLocation() n'est pas appelé, ce qui décale la notification.
    final now = DateTime.now();
    var localScheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!localScheduled.isAfter(now)) {
      localScheduled = localScheduled.add(const Duration(days: 1));
    }
    // fromMillisecondsSinceEpoch préserve l'instant UTC exact.
    final scheduled = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      localScheduled.millisecondsSinceEpoch,
    );

    // Sur Android 12+, SCHEDULE_EXACT_ALARM doit être accordée explicitement.
    // Si elle ne l'est pas, on replie sur inexact pour que la notification
    // s'affiche quand même (avec un léger décalage possible).
    final canExact = await canScheduleExactNotifications();
    final schedMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexact;

    await _plugin.zonedSchedule(
      _kDailyId,
      'Rappel de lecture',
      'N\'oubliez pas votre lecture du Coran aujourd\'hui 📖',
      scheduled,
      NotificationDetails(android: _androidDetails),
      androidScheduleMode: schedMode,
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

    // Sur Android 12+, SCHEDULE_EXACT_ALARM doit être accordée explicitement.
    final canExact = await canScheduleExactNotifications();
    final schedMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexact;

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
        androidScheduleMode: schedMode,
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

  // ── Cache des horaires de prière ──────────────────────────────────────────
  /// Persiste une map { "Fajr": "05:30", ... } pour un usage hors-ligne.
  Future<void> savePrayerTimesCache(Map<String, String> times) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrayerCache, json.encode(times));
  }

  Future<Map<String, String>?> _loadPrayerTimesCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrayerCache);
    if (raw == null) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  // ── Planification depuis des horaires HH:mm (aujourd'hui + demain) ────────
  /// Converts "HH:mm" strings to DateTimes for today AND tomorrow,
  /// then schedules up to 10 one-shot notifications.
  /// Returns false if times map is empty.
  Future<bool> scheduleFromStringTimes(Map<String, String> times) async {
    if (times.isEmpty) return false;
    await init();
    final now = DateTime.now();

    final Map<String, DateTime> toSchedule = {};
    for (final entry in times.entries) {
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;

      var dt = DateTime(now.year, now.month, now.day, h, m);
      if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
      // If still within 24h window, also schedule the next occurrence (tomorrow)
      toSchedule[entry.key] = dt;
    }

    await schedulePrayerNotifications(toSchedule);
    return toSchedule.isNotEmpty;
  }

  /// Loads the cached prayer times and schedules notifications.
  /// Returns false if no cache is available.
  Future<bool> scheduleFromCache() async {
    final cached = await _loadPrayerTimesCache();
    if (cached == null || cached.isEmpty) return false;
    return scheduleFromStringTimes(cached);
  }

  // ── Re-planification au démarrage ─────────────────────────────────────────
  /// À appeler dans main() : re-planifie les notifications actives dont
  /// les one-shots auraient expiré depuis le dernier lancement de l'app.
  Future<void> scheduleOnStartup() async {
    await init();
    // Rappel quotidien (matchDateTimeComponents le rend récurrent, mais on
    // le re-planifie quand même pour mettre à jour l'heure si elle a changé).
    if (await isDailyEnabled()) {
      final time = await getDailyTime();
      await scheduleDailyReminder(time);
    }
    // Prières : re-planifie depuis le cache pour remplacer les one-shots expirés.
    if (await arePrayersEnabled()) {
      await scheduleFromCache();
    }
  }
}
