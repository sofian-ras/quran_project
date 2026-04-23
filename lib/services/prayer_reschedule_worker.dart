import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'streak_service.dart';

// ── Identifiants WorkManager ──────────────────────────────────────────────────
const kRescheduleTaskUnique = 'prayer_reschedule_daily';
const kRescheduleTaskName   = 'prayer_reschedule';

// ── Point d'entrée isolate WorkManager ───────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == kRescheduleTaskName ||
          task == Workmanager.iOSBackgroundTask) {
        await _reschedulePrayers();
        await _refreshDhikrNotifications();
        await StreakService.checkAndNotify();
      }
      return true;
    } catch (e, st) {
      debugPrint('[WorkManager] erreur tâche de fond : $e\n$st');
      return false;
    }
  });
}

// ── Re-planification prières ──────────────────────────────────────────────────
Future<void> _reschedulePrayers() async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  final prayersEnabled = prefs.getBool('notif_prayers_enabled') ?? false;
  if (!prayersEnabled) return;

  Map<String, String>? freshTimes;
  try {
    freshTimes = await _fetchTodayPrayerTimes(prefs);
  } catch (_) {
    // Pas de réseau — fallback cache.
  }

  if (freshTimes != null && freshTimes.isNotEmpty) {
    await NotificationService.instance.savePrayerTimesCache(freshTimes);
    await NotificationService.instance.scheduleFromStringTimes(freshTimes);
  } else {
    await NotificationService.instance.scheduleFromCache();
  }
}

// ── Re-planification dhikrs (contenu aléatoire renouvelé chaque jour) ─────────
Future<void> _refreshDhikrNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  final dhikrEnabled = prefs.getBool('notif_dhikr_enabled') ?? false;
  if (!dhikrEnabled) return;

  final morningHour   = prefs.getInt('notif_dhikr_morning_hour')   ?? 7;
  final morningMinute = prefs.getInt('notif_dhikr_morning_minute') ?? 30;
  final eveningHour   = prefs.getInt('notif_dhikr_evening_hour')   ?? 21;
  final eveningMinute = prefs.getInt('notif_dhikr_evening_minute') ?? 0;

  await NotificationService.instance.scheduleDhikrNotifications(
    morning: TimeOfDay(hour: morningHour, minute: morningMinute),
    evening: TimeOfDay(hour: eveningHour, minute: eveningMinute),
  );
}

// ── AlAdhan API ───────────────────────────────────────────────────────────────
Future<Map<String, String>> _fetchTodayPrayerTimes(
    SharedPreferences prefs) async {
  const defMethod  = '12';
  const defCity    = 'Paris';
  const defCountry = 'France';

  final method   = (prefs.getString('prayer_method')  ?? defMethod).trim();
  final isManual =  prefs.getBool('prayer_manual')    ?? false;
  final lat      =  prefs.getDouble('prayer_lat')     ?? 0.0;
  final lng      =  prefs.getDouble('prayer_lng')     ?? 0.0;

  final Uri uri;
  if (!isManual && lat != 0 && lng != 0) {
    uri = Uri.https('api.aladhan.com', '/v1/timings', {
      'latitude':  lat.toString(),
      'longitude': lng.toString(),
      'method':    method,
    });
  } else {
    final city    = (prefs.getString('prayer_city')    ?? defCity).trim();
    final country = (prefs.getString('prayer_country') ?? defCountry).trim();
    uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': city, 'country': country, 'method': method,
    });
  }

  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

  final root    = json.decode(res.body) as Map<String, dynamic>;
  final timings = (root['data'] as Map)['timings'] as Map<String, dynamic>;

  return {
    'Fajr':    timings['Fajr']?.toString()    ?? '',
    'Dhuhr':   timings['Dhuhr']?.toString()   ?? '',
    'Asr':     timings['Asr']?.toString()     ?? '',
    'Maghrib': timings['Maghrib']?.toString() ?? '',
    'Isha':    timings['Isha']?.toString()    ?? '',
  };
}
