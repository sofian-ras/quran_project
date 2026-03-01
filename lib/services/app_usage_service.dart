import 'package:shared_preferences/shared_preferences.dart';

/// Tracks cumulative time the user spends in the app.
/// Call [init] once at startup, [onResume] / [onPause] from AppLifecycleState.
class AppUsageService {
  static const _kTotalSeconds = 'app_total_seconds';

  static int _baseSeconds  = 0;
  static int _sessionStart = 0; // ms since epoch, 0 = not running

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseSeconds  = prefs.getInt(_kTotalSeconds) ?? 0;
    _sessionStart = DateTime.now().millisecondsSinceEpoch;
  }

  static void onResume() {
    _sessionStart = DateTime.now().millisecondsSinceEpoch;
  }

  static Future<void> onPause() async {
    if (_sessionStart == 0) return;
    final elapsed = (DateTime.now().millisecondsSinceEpoch - _sessionStart) ~/ 1000;
    _baseSeconds += elapsed;
    _sessionStart = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTotalSeconds, _baseSeconds);
  }

  /// Current total including the live session.
  static int get totalSeconds {
    if (_sessionStart == 0) return _baseSeconds;
    return _baseSeconds +
        (DateTime.now().millisecondsSinceEpoch - _sessionStart) ~/ 1000;
  }

  static String formatDuration(int s) {
    if (s < 60) return '$s s';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h == 0) return '${m} min';
    return '${h}h ${m}min';
  }
}
