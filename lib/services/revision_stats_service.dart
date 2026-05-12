import 'package:shared_preferences/shared_preferences.dart';
import '../models/revision_entry.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class RevisionStats {
  final int dailyGoal;
  final int todayAyahs;
  final int streak;
  final int allTimeSessions;
  final int allTimeAyahs;
  final int totalTracked;
  final int masteredCount;  // status == 'review'
  final int learningCount;  // status == 'learning'
  final int lapsedCount;    // status == 'lapsed'

  const RevisionStats({
    required this.dailyGoal,
    required this.todayAyahs,
    required this.streak,
    required this.allTimeSessions,
    required this.allTimeAyahs,
    required this.totalTracked,
    required this.masteredCount,
    required this.learningCount,
    required this.lapsedCount,
  });

  double get masteryPercent =>
      totalTracked == 0 ? 0 : masteredCount / totalTracked;

  double get goalProgress =>
      dailyGoal == 0 ? 1.0 : (todayAyahs / dailyGoal).clamp(0.0, 1.0);

  bool get goalMet => todayAyahs >= dailyGoal;
}

// ── Service ───────────────────────────────────────────────────────────────────

class RevisionStatsService {
  RevisionStatsService._();
  static final instance = RevisionStatsService._();

  static const _kGoal         = 'revision_daily_goal';
  static const _kStreak       = 'revision_streak';
  static const _kLastActive   = 'revision_last_active';
  static const _kTodayAyahs   = 'revision_today_ayahs';
  static const _kTodayDate    = 'revision_today_date';
  static const _kAllSessions  = 'revision_all_time_sessions';
  static const _kAllAyahs     = 'revision_all_time_ayahs';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _resetTodayIfNeeded(SharedPreferences p) async {
    final stored = p.getString(_kTodayDate);
    final today  = _dateStr(DateTime.now());
    if (stored != today) {
      await p.setInt(_kTodayAyahs, 0);
      await p.setString(_kTodayDate, today);
    }
  }

  Future<RevisionStats> getStats({required List<RevisionEntry> allEntries}) async {
    final p = await SharedPreferences.getInstance();
    await _resetTodayIfNeeded(p);

    final mastered = allEntries.where((e) => e.status == 'review').length;
    final learning = allEntries.where((e) => e.status == 'learning').length;
    final lapsed   = allEntries.where((e) => e.status == 'lapsed').length;

    return RevisionStats(
      dailyGoal:        p.getInt(_kGoal) ?? 10,
      todayAyahs:       p.getInt(_kTodayAyahs) ?? 0,
      streak:           p.getInt(_kStreak) ?? 0,
      allTimeSessions:  p.getInt(_kAllSessions) ?? 0,
      allTimeAyahs:     p.getInt(_kAllAyahs) ?? 0,
      totalTracked:     allEntries.length,
      masteredCount:    mastered,
      learningCount:    learning,
      lapsedCount:      lapsed,
    );
  }

  Future<void> recordSession(int ayahsReviewed) async {
    final p     = await SharedPreferences.getInstance();
    final today = _dateStr(DateTime.now());

    await _resetTodayIfNeeded(p);

    // Streak
    final lastActive = p.getString(_kLastActive);
    if (lastActive == null) {
      await p.setInt(_kStreak, 1);
    } else {
      final last = DateTime.parse(lastActive);
      final now  = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (diff == 1) {
        await p.setInt(_kStreak, (p.getInt(_kStreak) ?? 0) + 1);
      } else if (diff > 1) {
        await p.setInt(_kStreak, 1);
      }
      // diff == 0 : same day, streak unchanged
    }
    await p.setString(_kLastActive, today);

    // Today's ayahs
    await p.setInt(_kTodayAyahs, (p.getInt(_kTodayAyahs) ?? 0) + ayahsReviewed);

    // All-time
    await p.setInt(_kAllSessions, (p.getInt(_kAllSessions) ?? 0) + 1);
    await p.setInt(_kAllAyahs,    (p.getInt(_kAllAyahs) ?? 0) + ayahsReviewed);
  }

  Future<void> setDailyGoal(int goal) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kGoal, goal.clamp(5, 300));
  }
}
