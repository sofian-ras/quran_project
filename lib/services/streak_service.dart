import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const _kLastOpenDate  = 'streak_last_open_date';
const _kStreakCount   = 'streak_count';
const _kStreakChecked = 'streak_checked_today';

/// Tracks the user's daily reading streak and triggers motivational reminders.
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  int _streak = 0;
  int get streak => _streak;

  /// Call once at app start (after prefs init).
  Future<void> onAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastOpen = prefs.getString(_kLastOpenDate);

    if (lastOpen == today) {
      // Same day — just load streak, mark no longer at risk
      _streak = prefs.getInt(_kStreakCount) ?? 0;
      await NotificationService.instance.cancelStreakReminder();
      return;
    }

    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    if (lastOpen == yesterday) {
      // Consecutive day — increment streak
      _streak = (prefs.getInt(_kStreakCount) ?? 0) + 1;
    } else if (lastOpen == null) {
      // First ever open
      _streak = 1;
    } else {
      // Streak broken (missed at least one day)
      _streak = 1;
    }

    await prefs.setString(_kLastOpenDate, today);
    await prefs.setInt(_kStreakCount, _streak);
    await prefs.remove(_kStreakChecked);

    // Cancel any pending streak reminder since user opened the app
    await NotificationService.instance.cancelStreakReminder();
  }

  /// Called from WorkManager (background). Schedules a reminder if user
  /// hasn't opened the app today and it's past 18:00.
  static Future<void> checkAndNotify() async {
    final prefs = await SharedPreferences.getInstance();

    // Only send one streak notification per day
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_kStreakChecked) == today) return;

    final lastOpen = prefs.getString(_kLastOpenDate);
    if (lastOpen == today) return; // Already opened today

    // Only remind after 18:00 to avoid disturbing during the day
    if (DateTime.now().hour < 18) return;

    final streak = prefs.getInt(_kStreakCount) ?? 0;
    final notifEnabled = prefs.getBool('notif_streak_enabled') ?? true;
    if (!notifEnabled) return;

    await prefs.setString(_kStreakChecked, today);
    await NotificationService.instance.scheduleStreakReminder(streak);
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
