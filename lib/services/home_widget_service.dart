import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static const _androidPackage = 'com.sofian.quran';

  static final _arabicNames = {
    'Fajr':    'الفجر',
    'Dhuhr':   'الظهر',
    'Asr':     'العصر',
    'Maghrib': 'المغرب',
    'Isha':    'العشاء',
  };

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

  // ── Widget Prière ─────────────────────────────────────────────────────────
  static Future<void> _updatePrayerWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notif_last_prayer_times');
    if (raw == null) {
      await _savePrayerWidgetData(
        name: '—', time: '—', arabic: '', countdown: '',
      );
      return;
    }

    final Map<String, String> times = (json.decode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

    final now = DateTime.now();
    String? nextName;
    DateTime? nextDt;

    for (final entry in times.entries) {
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      var dt = DateTime(now.year, now.month, now.day, h, m);
      if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
      if (nextDt == null || dt.isBefore(nextDt)) {
        nextDt = dt;
        nextName = entry.key;
      }
    }

    if (nextName == null || nextDt == null) {
      await _savePrayerWidgetData(name: '—', time: '—', arabic: '', countdown: '');
      return;
    }

    final diff = nextDt.difference(now);
    final countdown = _formatCountdown(diff);
    final timeStr =
        '${nextDt.hour.toString().padLeft(2, '0')}:${nextDt.minute.toString().padLeft(2, '0')}';

    await _savePrayerWidgetData(
      name:      nextName,
      time:      timeStr,
      arabic:    _arabicNames[nextName] ?? '',
      countdown: countdown,
    );
  }

  static Future<void> _savePrayerWidgetData({
    required String name,
    required String time,
    required String arabic,
    required String countdown,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>('next_prayer_name',     name),
      HomeWidget.saveWidgetData<String>('next_prayer_time',     time),
      HomeWidget.saveWidgetData<String>('next_prayer_arabic',   arabic),
      HomeWidget.saveWidgetData<String>('next_prayer_countdown', countdown),
    ]);
    await HomeWidget.updateWidget(androidName: 'PrayerWidget');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _formatCountdown(Duration d) {
    if (d.isNegative) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return 'dans ${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return 'dans ${m}min';
    return 'maintenant';
  }
}
