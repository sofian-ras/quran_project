import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static const _androidPackage = 'com.sofian.quran';
  static const _kHijri = 'notif_last_hijri';

  static const _prayerKeys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  /// À appeler au démarrage de l'app pour initialiser le package.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await HomeWidget.setAppGroupId(_androidPackage);
  }

  /// Met à jour les widgets depuis le cache disponible.
  /// Appeler au démarrage et après chaque fetch des horaires.
  static Future<void> updateAll() async {
    if (!Platform.isAndroid) return;
    await _updatePrayerWidget();
  }

  /// Sauvegarde la date hijri pour le widget (appelé depuis PrayersScreen).
  static Future<void> saveHijri(String hijriLine) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHijri, hijriLine);
  }

  // ── Widget Prière ─────────────────────────────────────────────────────────
  static Future<void> _updatePrayerWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('notif_last_prayer_times');
    final hijri = prefs.getString(_kHijri) ?? '';

    final Map<String, String> times;
    if (raw == null) {
      times = {};
    } else {
      times = (json.decode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    }

    final now    = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    String activeName = '';
    int?   activeTotalMin;

    // La première prière (≠ Sunrise) dont l'heure > maintenant → active
    for (final name in _prayerKeys) {
      if (name == 'Sunrise') continue;
      final t = _parseMinutes(times[name] ?? '');
      if (t == null) continue;
      // minutes normalisées pour "demain" si < now
      final adjusted = t < nowMin ? t + 1440 : t;
      if (activeTotalMin == null || adjusted < activeTotalMin) {
        activeTotalMin = adjusted;
        activeName = name;
      }
    }

    final futures = <Future>[];
    for (final name in _prayerKeys) {
      final key     = 'pw_${name.toLowerCase()}';
      final timeStr = _cleanTime(times[name] ?? '');
      futures.add(HomeWidget.saveWidgetData<String>(key, timeStr));
    }
    futures.add(HomeWidget.saveWidgetData<String>('pw_active', activeName));
    futures.add(HomeWidget.saveWidgetData<String>('pw_hijri',  hijri));
    await Future.wait(futures);
    await HomeWidget.updateWidget(androidName: 'PrayerWidget');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parse "HH:MM" or "HH:MM (TZ)" → minutes depuis minuit, null si invalide.
  static int? _parseMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim().split(' ')[0]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Retourne "HH:MM" depuis "HH:MM (TZ)" ou "—" si invalide.
  static String _cleanTime(String raw) {
    final min = _parseMinutes(raw);
    if (min == null) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
