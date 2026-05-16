import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── Clés SharedPreferences ────────────────────────────────────────────────────
const _kDailyEnabled       = 'notif_daily_enabled';
const _kDailyHour          = 'notif_daily_hour';
const _kDailyMinute        = 'notif_daily_minute';
const _kPrayersEnabled     = 'notif_prayers_enabled';
const _kPrayerCache        = 'notif_last_prayer_times';
const _kVerseEnabled       = 'notif_verse_enabled';
const _kVerseHour          = 'notif_verse_hour';
const _kVerseMinute        = 'notif_verse_minute';
const _kDhikrEnabled       = 'notif_dhikr_enabled';
const _kDhikrMorningHour   = 'notif_dhikr_morning_hour';
const _kDhikrMorningMinute = 'notif_dhikr_morning_minute';
const _kDhikrEveningHour   = 'notif_dhikr_evening_hour';
const _kDhikrEveningMinute = 'notif_dhikr_evening_minute';
const _kStreakEnabled      = 'notif_streak_enabled';
const _kArabicEnabled      = 'notif_arabic_enabled';
const _kArabicHour         = 'notif_arabic_hour';
const _kArabicMinute       = 'notif_arabic_minute';

// ── IDs de notification ───────────────────────────────────────────────────────
const _kDailyId         = 1;
const _kVerseId         = 2;
const _kDhikrMorningId  = 20;
const _kDhikrEveningId  = 21;
const _kStreakId        = 30;
const _kArabicId        = 50;
const _kFajrId          = 10;
const _kDhuhrId         = 11;
const _kAsrId           = 12;
const _kMaghribId       = 13;
const _kIshaId          = 14;

// ── Canaux ────────────────────────────────────────────────────────────────────
const _kChannelId   = 'quran_reminders';
const _kChannelName = 'Rappels Quran';

// ── Actions ───────────────────────────────────────────────────────────────────
const _kActionSnooze = 'snooze_30';

const _kBatteryChannel = MethodChannel('com.sofian.quran/battery');

// ── Liste de dhikrs / duas ────────────────────────────────────────────────────
const _dhikrs = [
  ('سُبْحَانَ اللَّهِ', 'Gloire à Allah — Subhan Allah'),
  ('الْحَمْدُ لِلَّهِ', 'Louange à Allah — Alhamdulillah'),
  ('اللَّهُ أَكْبَرُ', 'Allah est le Plus Grand — Allahu Akbar'),
  ('لَا إِلَٰهَ إِلَّا اللَّهُ', 'Nul dieu n\'est digne d\'adoration sinon Allah'),
  ('أَسْتَغْفِرُ اللَّهَ', 'Je demande le pardon d\'Allah — Astaghfirullah'),
  ('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 'Nulle force ni puissance si ce n\'est par Allah'),
  ('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 'Au nom d\'Allah, le Tout Miséricordieux, le Très Miséricordieux'),
  ('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'Allah nous suffit, quel excellent garant Il est !'),
  ('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'Ô Allah, accorde Tes grâces sur Muhammad ﷺ'),
  ('رَبَّنَا تَقَبَّلْ مِنَّا', 'Seigneur, accepte de nous (cette dévotion)'),
  ('اللَّهُمَّ اغْفِرْ لِي', 'Ô Allah, pardonne-moi'),
  ('رَبِّ اشْرَحْ لِي صَدْرِي', 'Seigneur, ouvre ma poitrine (à Ta guidance)'),
  ('اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ', 'Ô Allah, je Te demande la clémence et le bien-être'),
  ('يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ', 'Ô Vivant, ô Subsistant, c\'est par Ta miséricorde que j\'implore'),
  ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً', 'Seigneur, accorde-nous le bien ici-bas et dans l\'au-delà'),
  ('إِنَّا لِلَّٰهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ', 'Nous sommes à Allah et c\'est vers Lui que nous retournerons'),
  ('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'Gloire à Allah et à Sa louange — 100×, les péchés effacés'),
  ('اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ', 'Ô Allah, aide-moi à T\'invoquer, à T\'être reconnaissant et à bien T\'adorer'),
  ('رَبِّ زِدْنِي عِلْمًا', 'Seigneur, accroît mes connaissances'),
  ('اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ', 'Ô Allah, je cherche refuge en Toi contre l\'anxiété et la tristesse'),
];

// ── Handler background (actions depuis notification, app en arrière-plan) ─────
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  if (response.actionId == _kActionSnooze) {
    tz.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    final snoozeAt = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch,
    );
    await plugin.zonedSchedule(
      _kDailyId,
      'Rappel de lecture ⏰',
      'Prêt à lire le Coran maintenant ? 📖',
      snoozeAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Callback déclenché quand l'utilisateur tape sur une notification.
  /// Défini dans main.dart pour naviguer vers le bon écran.
  static void Function(String payload)? onNotificationTap;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );

    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (impl != null) {
        await impl.deleteNotificationChannel(_kChannelId);
        await impl.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: 'Rappels de lecture, dhikrs et alertes de prière',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ));
      }
    }

    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    if (response.actionId == _kActionSnooze) {
      _snoozeDaily30min();
      return;
    }
    final payload = response.payload;
    if (payload != null && onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }

  Future<void> _snoozeDaily30min() async {
    await init();
    final canExact = await canScheduleExactNotifications();
    final snoozeAt = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch,
    );
    await _plugin.zonedSchedule(
      _kDailyId,
      'Rappel de lecture ⏰',
      'Prêt à lire le Coran maintenant ? 📖',
      snoozeAt,
      NotificationDetails(android: _androidDetails()),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reader',
    );
  }

  // ── Batterie ──────────────────────────────────────────────────────────────
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _kBatteryChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestBatteryOptimizationExclusion() async {
    if (!Platform.isAndroid) return;
    try {
      await _kBatteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {
      await Geolocator.openAppSettings();
    }
  }

  // ── Notification de test ──────────────────────────────────────────────────
  Future<void> showTestNotification() async {
    await init();
    final in5s = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      DateTime.now().add(const Duration(seconds: 5)).millisecondsSinceEpoch,
    );
    final canExact = await canScheduleExactNotifications();
    await _plugin.zonedSchedule(
      99,
      'Test ✓',
      'Les notifications fonctionnent !',
      in5s,
      NotificationDetails(android: _androidDetails()),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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

  Future<bool> canScheduleExactNotifications() async {
    if (!Platform.isAndroid) return true;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  // ── Canal Android ─────────────────────────────────────────────────────────
  AndroidNotificationDetails _androidDetails({
    bool withSnooze = false,
    BigTextStyleInformation? style,
  }) {
    return AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: 'Rappels de lecture, dhikrs et alertes de prière',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: style,
      actions: withSnooze
          ? const [
              AndroidNotificationAction(
                _kActionSnooze,
                'Rappeler dans 30 min',
                showsUserInterface: false,
              ),
            ]
          : null,
    );
  }

  // ── Rappel quotidien ──────────────────────────────────────────────────────
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    final now = DateTime.now();
    var localScheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!localScheduled.isAfter(now)) {
      localScheduled = localScheduled.add(const Duration(days: 1));
    }
    final scheduled = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      localScheduled.millisecondsSinceEpoch,
    );

    final canExact = await canScheduleExactNotifications();
    await _plugin.zonedSchedule(
      _kDailyId,
      'Rappel de lecture 📖',
      'N\'oubliez pas votre lecture du Coran aujourd\'hui',
      scheduled,
      NotificationDetails(android: _androidDetails(withSnooze: true)),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reader',
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

  // ── Verset du jour ────────────────────────────────────────────────────────
  Future<void> scheduleVerseNotification(TimeOfDay time) async {
    await init();
    final now = DateTime.now();
    var localScheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!localScheduled.isAfter(now)) {
      localScheduled = localScheduled.add(const Duration(days: 1));
    }
    final scheduled = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      localScheduled.millisecondsSinceEpoch,
    );

    final canExact = await canScheduleExactNotifications();
    await _plugin.zonedSchedule(
      _kVerseId,
      'Verset du jour ✨',
      'Découvrez votre verset inspirant du jour',
      scheduled,
      NotificationDetails(
        android: _androidDetails(
          style: const BigTextStyleInformation(
            'Découvrez votre verset inspirant du jour — touchez pour lire',
            summaryText: 'Coran • Verset du jour',
          ),
        ),
      ),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'verse',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVerseEnabled, true);
    await prefs.setInt(_kVerseHour, time.hour);
    await prefs.setInt(_kVerseMinute, time.minute);
  }

  Future<void> cancelVerseNotification() async {
    await _plugin.cancel(_kVerseId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVerseEnabled, false);
  }

  Future<bool> isVerseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kVerseEnabled) ?? false;
  }

  Future<TimeOfDay> getVerseTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour:   prefs.getInt(_kVerseHour)   ?? 7,
      minute: prefs.getInt(_kVerseMinute) ?? 0,
    );
  }

  // ── Dhikr & Dua ──────────────────────────────────────────────────────────
  Future<void> scheduleDhikrNotifications({
    TimeOfDay morning = const TimeOfDay(hour: 7, minute: 30),
    TimeOfDay evening = const TimeOfDay(hour: 21, minute: 0),
  }) async {
    await init();
    final canExact = await canScheduleExactNotifications();
    final schedMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexact;

    final now = DateTime.now();
    final rng = math.Random();

    // Matin
    final morningDhikr = _dhikrs[rng.nextInt(_dhikrs.length)];
    var morningDt = DateTime(now.year, now.month, now.day, morning.hour, morning.minute);
    if (!morningDt.isAfter(now)) morningDt = morningDt.add(const Duration(days: 1));
    final morningTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local, morningDt.millisecondsSinceEpoch);

    await _plugin.zonedSchedule(
      _kDhikrMorningId,
      'Dhikr du matin 🌅',
      morningDhikr.$1,
      morningTz,
      NotificationDetails(
        android: _androidDetails(
          style: BigTextStyleInformation(
            morningDhikr.$2,
            summaryText: 'Rappel spirituel du matin',
          ),
        ),
      ),
      androidScheduleMode: schedMode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'dhikr',
    );

    // Soir
    final eveningDhikr = _dhikrs[rng.nextInt(_dhikrs.length)];
    var eveningDt = DateTime(now.year, now.month, now.day, evening.hour, evening.minute);
    if (!eveningDt.isAfter(now)) eveningDt = eveningDt.add(const Duration(days: 1));
    final eveningTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local, eveningDt.millisecondsSinceEpoch);

    await _plugin.zonedSchedule(
      _kDhikrEveningId,
      'Dhikr du soir 🌙',
      eveningDhikr.$1,
      eveningTz,
      NotificationDetails(
        android: _androidDetails(
          style: BigTextStyleInformation(
            eveningDhikr.$2,
            summaryText: 'Rappel spirituel du soir',
          ),
        ),
      ),
      androidScheduleMode: schedMode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'dhikr',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDhikrEnabled, true);
    await prefs.setInt(_kDhikrMorningHour, morning.hour);
    await prefs.setInt(_kDhikrMorningMinute, morning.minute);
    await prefs.setInt(_kDhikrEveningHour, evening.hour);
    await prefs.setInt(_kDhikrEveningMinute, evening.minute);
  }

  Future<void> cancelDhikrNotifications() async {
    await _plugin.cancel(_kDhikrMorningId);
    await _plugin.cancel(_kDhikrEveningId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDhikrEnabled, false);
  }

  Future<bool> isDhikrEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDhikrEnabled) ?? false;
  }

  Future<TimeOfDay> getDhikrMorningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour:   prefs.getInt(_kDhikrMorningHour)   ?? 7,
      minute: prefs.getInt(_kDhikrMorningMinute) ?? 30,
    );
  }

  Future<TimeOfDay> getDhikrEveningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour:   prefs.getInt(_kDhikrEveningHour)   ?? 21,
      minute: prefs.getInt(_kDhikrEveningMinute) ?? 0,
    );
  }

  // ── Streak de lecture ─────────────────────────────────────────────────────
  Future<void> scheduleStreakReminder(int streakDays) async {
    await init();
    final canExact = await canScheduleExactNotifications();
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kStreakEnabled) ?? true)) return;

    // Notification dans ~2h pour que l'utilisateur la voie dans la soirée
    final when = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    );

    final body = streakDays > 0
        ? 'Tu lis le Coran depuis $streakDays jour${streakDays > 1 ? "s" : ""} consécutif${streakDays > 1 ? "s" : ""} 🔥 Ne brise pas ta série !'
        : 'Tu n\'as pas lu le Coran aujourd\'hui. Quelques minutes suffisent 📖';

    await _plugin.zonedSchedule(
      _kStreakId,
      streakDays > 0 ? 'Série en danger ! 🔥' : 'Rappel de lecture 📖',
      body,
      when,
      NotificationDetails(
        android: _androidDetails(
          withSnooze: true,
          style: BigTextStyleInformation(
            body,
            summaryText: 'Quran App • Rappel quotidien',
          ),
        ),
      ),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reader',
    );
  }

  Future<void> cancelStreakReminder() async {
    await _plugin.cancel(_kStreakId);
  }

  Future<bool> isStreakNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kStreakEnabled) ?? true;
  }

  Future<void> setStreakNotifEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakEnabled, value);
    if (!value) await cancelStreakReminder();
  }

  // ── Rappel apprentissage arabe ────────────────────────────────────────────
  Future<void> scheduleArabicReminder(TimeOfDay time) async {
    await init();
    final canExact = await canScheduleExactNotifications();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kArabicEnabled, true);
    await prefs.setInt(_kArabicHour, time.hour);
    await prefs.setInt(_kArabicMinute, time.minute);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _kArabicId,
      'تعلم العربية • Leçon du jour 📖',
      'C\'est l\'heure de ta leçon d\'arabe ! Continue ton streak !',
      scheduled,
      NotificationDetails(
        android: _androidDetails(
          withSnooze: false,
          style: const BigTextStyleInformation(
            'C\'est l\'heure de ta leçon d\'arabe ! Continue ton streak !',
            summaryText: 'Quran App • Apprentissage arabe',
          ),
        ),
      ),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'arabic',
    );
  }

  Future<void> cancelArabicReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kArabicEnabled, false);
    await _plugin.cancel(_kArabicId);
  }

  Future<bool> isArabicReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kArabicEnabled) ?? false;
  }

  Future<TimeOfDay> getArabicReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getInt(_kArabicHour) ?? 9;
    final m = prefs.getInt(_kArabicMinute) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  // ── Notifications de prières ──────────────────────────────────────────────
  Future<void> schedulePrayerNotifications(
      Map<String, DateTime> prayerTimes) async {
    await init();
    final ids = {
      'Fajr':    _kFajrId,
      'Dhuhr':   _kDhuhrId,
      'Asr':     _kAsrId,
      'Maghrib': _kMaghribId,
      'Isha':    _kIshaId,
    };
    final arabicNames = {
      'Fajr':    'الفجر',
      'Dhuhr':   'الظهر',
      'Asr':     'العصر',
      'Maghrib': 'المغرب',
      'Isha':    'العشاء',
    };

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
        NotificationDetails(android: _androidDetails()),
        androidScheduleMode: schedMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'prayers',
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

  // ── Planification depuis des horaires HH:mm ───────────────────────────────
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
      toSchedule[entry.key] = dt;
    }

    await schedulePrayerNotifications(toSchedule);
    return toSchedule.isNotEmpty;
  }

  Future<bool> scheduleFromCache() async {
    final cached = await _loadPrayerTimesCache();
    if (cached == null || cached.isEmpty) return false;
    return scheduleFromStringTimes(cached);
  }

  Future<int> getEnabledCount() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    if (prefs.getBool(_kDailyEnabled) == true) count++;
    if (prefs.getBool(_kVerseEnabled) == true) count++;
    if (prefs.getBool(_kPrayersEnabled) == true) count++;
    if (prefs.getBool(_kDhikrEnabled) == true) count++;
    if (prefs.getBool(_kStreakEnabled) == true) count++;
    return count;
  }

  // ── Re-planification au démarrage ─────────────────────────────────────────
  Future<void> scheduleOnStartup() async {
    await init();
    if (await isDailyEnabled()) {
      final time = await getDailyTime();
      await scheduleDailyReminder(time);
    }
    if (await arePrayersEnabled()) {
      await scheduleFromCache();
    }
    if (await isVerseEnabled()) {
      final time = await getVerseTime();
      await scheduleVerseNotification(time);
    }
    if (await isDhikrEnabled()) {
      final morning = await getDhikrMorningTime();
      final evening = await getDhikrEveningTime();
      await scheduleDhikrNotifications(morning: morning, evening: evening);
    }
  }
}
