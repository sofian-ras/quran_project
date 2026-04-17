import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

// ── Identifiants WorkManager ──────────────────────────────────────────────────
/// Nom unique de la tâche périodique (clé WorkManager).
const kRescheduleTaskUnique = 'prayer_reschedule_daily';

/// Nom de la tâche passé au callback.
const kRescheduleTaskName = 'prayer_reschedule';

// ── Point d'entrée isolate WorkManager ───────────────────────────────────────
/// Doit être une fonction top-level ; @pragma évite le tree-shaking en release.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == kRescheduleTaskName ||
          task == Workmanager.iOSBackgroundTask) {
        await _reschedulePrayers();
      }
      return true;
    } catch (e, st) {
      debugPrint('[WorkManager] erreur re-planification prières : $e\n$st');
      // Retourner false signale à WorkManager de re-tenter.
      return false;
    }
  });
}

// ── Logique principale ────────────────────────────────────────────────────────
Future<void> _reschedulePrayers() async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  final prayersEnabled = prefs.getBool('notif_prayers_enabled') ?? false;
  if (!prayersEnabled) return;

  // Tenter un fetch frais des horaires du jour (requiert réseau).
  Map<String, String>? freshTimes;
  try {
    freshTimes = await _fetchTodayPrayerTimes(prefs);
  } catch (_) {
    // Pas de réseau — on tombera sur le fallback cache.
  }

  if (freshTimes != null && freshTimes.isNotEmpty) {
    // Mettre à jour le cache puis re-planifier.
    await NotificationService.instance.savePrayerTimesCache(freshTimes);
    await NotificationService.instance.scheduleFromStringTimes(freshTimes);
  } else {
    // Fallback : cache du dernier fetch (peut être d'hier, décalage ~1 min max).
    await NotificationService.instance.scheduleFromCache();
  }
}

// ── AlAdhan API ───────────────────────────────────────────────────────────────
Future<Map<String, String>> _fetchTodayPrayerTimes(
    SharedPreferences prefs) async {
  const defMethod  = '12';   // UOIF – France
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
