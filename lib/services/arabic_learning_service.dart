import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/arabic_models.dart';
import '../data/arabic_curriculum.dart';

class ArabicLearningService {
  ArabicLearningService._();
  static final ArabicLearningService instance = ArabicLearningService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'arabic_learning.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE arabic_progress (
            lesson_id     TEXT PRIMARY KEY,
            completed     INTEGER NOT NULL DEFAULT 0,
            best_score    INTEGER NOT NULL DEFAULT 0,
            completed_at  TEXT,
            attempts      INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE arabic_stats (
            id                INTEGER PRIMARY KEY CHECK (id = 1),
            total_xp          INTEGER NOT NULL DEFAULT 0,
            current_streak    INTEGER NOT NULL DEFAULT 0,
            longest_streak    INTEGER NOT NULL DEFAULT 0,
            last_practice     TEXT,
            hearts            INTEGER NOT NULL DEFAULT 5,
            last_heart_refill TEXT,
            perfect_count     INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE arabic_badges (
            badge_id     TEXT PRIMARY KEY,
            unlocked_at  TEXT NOT NULL
          )
        ''');
        // Seed default stats row
        await db.insert('arabic_stats', {
          'id': 1,
          'total_xp': 0,
          'current_streak': 0,
          'longest_streak': 0,
          'hearts': 5,
          'perfect_count': 0,
        });
      },
    );
  }

  // ─── Stats ──────────────────────────────────────────────────────────────

  Future<ArabicStats> getStats() async {
    final d = await db;

    // Auto-refill hearts based on time
    await _autoRefillHearts(d);

    final statsRows = await d.query('arabic_stats', where: 'id = 1');
    final row = statsRows.isEmpty ? <String, dynamic>{} : statsRows.first;

    final progressRows = await d.query('arabic_progress');
    final badgeRows = await d.query('arabic_badges');

    final completedLessons = <String>{};
    final lessonScores = <String, int>{};
    for (final p in progressRows) {
      final id = p['lesson_id'] as String;
      if ((p['completed'] as int) == 1) completedLessons.add(id);
      lessonScores[id] = p['best_score'] as int;
    }

    final badgeIds = badgeRows.map((b) => b['badge_id'] as String).toSet();

    DateTime? lastPractice;
    final lp = row['last_practice'];
    if (lp != null) lastPractice = DateTime.tryParse(lp as String);

    DateTime? lastHeartRefill;
    final lhr = row['last_heart_refill'];
    if (lhr != null) lastHeartRefill = DateTime.tryParse(lhr as String);

    return ArabicStats(
      totalXp: (row['total_xp'] as int?) ?? 0,
      currentStreak: (row['current_streak'] as int?) ?? 0,
      longestStreak: (row['longest_streak'] as int?) ?? 0,
      hearts: (row['hearts'] as int?) ?? 5,
      lastHeartRefill: lastHeartRefill,
      lastPractice: lastPractice,
      completedLessons: completedLessons,
      lessonBestScores: lessonScores,
      unlockedBadgeIds: badgeIds,
    );
  }

  // ─── Heart refill ────────────────────────────────────────────────────────

  Future<void> _autoRefillHearts(Database d) async {
    final rows = await d.query('arabic_stats', where: 'id = 1');
    if (rows.isEmpty) return;
    final row = rows.first;
    int hearts = (row['hearts'] as int?) ?? 5;
    if (hearts >= 5) return;

    final lhr = row['last_heart_refill'];
    if (lhr == null) return;

    final lastRefill = DateTime.tryParse(lhr as String);
    if (lastRefill == null) return;

    final now = DateTime.now();
    final minutesPassed = now.difference(lastRefill).inMinutes;
    final heartsToAdd = (minutesPassed ~/ 30).clamp(0, 5 - hearts);
    if (heartsToAdd <= 0) return;

    hearts = (hearts + heartsToAdd).clamp(0, 5);
    final newLastRefill = hearts >= 5
        ? null
        : lastRefill.add(Duration(minutes: heartsToAdd * 30)).toIso8601String();

    await d.update(
      'arabic_stats',
      {'hearts': hearts, 'last_heart_refill': newLastRefill},
      where: 'id = 1',
    );
  }

  Future<void> loseHeart() async {
    final d = await db;
    final rows = await d.query('arabic_stats', where: 'id = 1');
    if (rows.isEmpty) return;
    final row = rows.first;
    final hearts = ((row['hearts'] as int?) ?? 5) - 1;
    final newHearts = hearts.clamp(0, 5);

    final updates = <String, dynamic>{'hearts': newHearts};
    if (newHearts < 5 && row['last_heart_refill'] == null) {
      updates['last_heart_refill'] = DateTime.now().toIso8601String();
    }

    await d.update('arabic_stats', updates, where: 'id = 1');
  }

  Future<void> refillAllHearts() async {
    final d = await db;
    await d.update('arabic_stats', {'hearts': 5, 'last_heart_refill': null}, where: 'id = 1');
  }

  // ─── Streak ──────────────────────────────────────────────────────────────

  Future<void> _updateStreak(Database d) async {
    final rows = await d.query('arabic_stats', where: 'id = 1');
    if (rows.isEmpty) return;
    final row = rows.first;

    final today = _dateKey(DateTime.now());
    final lp = row['last_practice'];
    final lastPractice = lp != null ? (lp as String) : null;

    if (lastPractice == today) return; // already updated today

    int streak = (row['current_streak'] as int?) ?? 0;
    int longest = (row['longest_streak'] as int?) ?? 0;

    if (lastPractice == null) {
      streak = 1;
    } else {
      final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      streak = (lastPractice == yesterday) ? streak + 1 : 1;
    }

    if (streak > longest) longest = streak;

    await d.update('arabic_stats', {
      'current_streak': streak,
      'longest_streak': longest,
      'last_practice': today,
    }, where: 'id = 1');
  }

  // ─── Complete lesson ──────────────────────────────────────────────────────

  Future<void> completeLesson({
    required String lessonId,
    required int score, // 0-100
    required int xpEarned,
    required bool perfect,
  }) async {
    final d = await db;

    // Update progress
    final existing = await d.query(
      'arabic_progress',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );

    if (existing.isEmpty) {
      await d.insert('arabic_progress', {
        'lesson_id': lessonId,
        'completed': 1,
        'best_score': score,
        'completed_at': DateTime.now().toIso8601String(),
        'attempts': 1,
      });
    } else {
      final prevBest = (existing.first['best_score'] as int?) ?? 0;
      await d.update(
        'arabic_progress',
        {
          'completed': 1,
          'best_score': score > prevBest ? score : prevBest,
          'completed_at': DateTime.now().toIso8601String(),
          'attempts': ((existing.first['attempts'] as int?) ?? 0) + 1,
        },
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
    }

    // Update XP, streak, perfect count
    final rows = await d.query('arabic_stats', where: 'id = 1');
    if (rows.isNotEmpty) {
      final row = rows.first;
      final currentXp = (row['total_xp'] as int?) ?? 0;
      final perfectCount = (row['perfect_count'] as int?) ?? 0;
      await d.update('arabic_stats', {
        'total_xp': currentXp + xpEarned,
        'perfect_count': perfect ? perfectCount + 1 : perfectCount,
      }, where: 'id = 1');
    }

    await _updateStreak(d);
    await checkAndUnlockBadges();
  }

  // ─── Lesson unlock logic ──────────────────────────────────────────────────

  Future<bool> isLessonUnlocked(String lessonId) async {
    final stats = await getStats();
    final completed = stats.completedLessons;

    // Find lesson position in curriculum
    for (final unit in kArabicCurriculum) {
      for (int i = 0; i < unit.lessons.length; i++) {
        if (unit.lessons[i].id == lessonId) {
          if (i == 0) {
            // First lesson of unit: unlock if previous unit complete (or it's unit 1)
            final unitIndex = kArabicCurriculum.indexOf(unit);
            if (unitIndex == 0) return true;
            final prevUnit = kArabicCurriculum[unitIndex - 1];
            return prevUnit.lessons.every((l) => completed.contains(l.id));
          } else {
            // Unlock if previous lesson in same unit completed with score ≥ 60
            final prevLessonId = unit.lessons[i - 1].id;
            final prevScore = stats.lessonBestScores[prevLessonId] ?? 0;
            return completed.contains(prevLessonId) && prevScore >= 60;
          }
        }
      }
    }
    return false;
  }

  LessonNodeState lessonNodeState(String lessonId, ArabicStats stats) {
    if (stats.completedLessons.contains(lessonId)) return LessonNodeState.completed;
    // Synchronous unlock check (simplified — checks completed set)
    for (final unit in kArabicCurriculum) {
      for (int i = 0; i < unit.lessons.length; i++) {
        if (unit.lessons[i].id != lessonId) continue;
        if (i == 0) {
          final unitIndex = kArabicCurriculum.indexOf(unit);
          if (unitIndex == 0) return LessonNodeState.current;
          final prevUnit = kArabicCurriculum[unitIndex - 1];
          final prevDone = prevUnit.lessons.every((l) => stats.completedLessons.contains(l.id));
          return prevDone ? LessonNodeState.current : LessonNodeState.locked;
        } else {
          final prevDone = stats.completedLessons.contains(unit.lessons[i - 1].id);
          return prevDone ? LessonNodeState.current : LessonNodeState.locked;
        }
      }
    }
    return LessonNodeState.locked;
  }

  // ─── Badges ───────────────────────────────────────────────────────────────

  Future<void> checkAndUnlockBadges() async {
    final stats = await getStats();
    final d = await db;
    final completed = stats.completedLessons;

    final toUnlock = <String>[];

    // first_lesson
    if (!stats.unlockedBadgeIds.contains('first_lesson') &&
        completed.isNotEmpty) {
      toUnlock.add('first_lesson');
    }

    // alphabet_complete — all unit 1 lessons
    final u1Ids = kArabicCurriculum[0].lessons.map((l) => l.id).toSet();
    if (!stats.unlockedBadgeIds.contains('alphabet_complete') &&
        u1Ids.every(completed.contains)) {
      toUnlock.add('alphabet_complete');
    }

    // vowels_complete — all unit 2 lessons
    final u2Ids = kArabicCurriculum[1].lessons.map((l) => l.id).toSet();
    if (!stats.unlockedBadgeIds.contains('vowels_complete') &&
        u2Ids.every(completed.contains)) {
      toUnlock.add('vowels_complete');
    }

    // quran_reader — all unit 4 lessons
    final u4Ids = kArabicCurriculum[3].lessons.map((l) => l.id).toSet();
    if (!stats.unlockedBadgeIds.contains('quran_reader') &&
        u4Ids.every(completed.contains)) {
      toUnlock.add('quran_reader');
    }

    // streak_7
    if (!stats.unlockedBadgeIds.contains('streak_7') &&
        stats.currentStreak >= 7) {
      toUnlock.add('streak_7');
    }

    // streak_30
    if (!stats.unlockedBadgeIds.contains('streak_30') &&
        stats.currentStreak >= 30) {
      toUnlock.add('streak_30');
    }

    // xp_1000
    if (!stats.unlockedBadgeIds.contains('xp_1000') &&
        stats.totalXp >= 1000) {
      toUnlock.add('xp_1000');
    }

    // perfect_5 — need to re-read perfect_count from db
    final rows = await d.query('arabic_stats', where: 'id = 1');
    if (rows.isNotEmpty) {
      final perfectCount = (rows.first['perfect_count'] as int?) ?? 0;
      if (!stats.unlockedBadgeIds.contains('perfect_5') && perfectCount >= 5) {
        toUnlock.add('perfect_5');
      }
    }

    for (final id in toUnlock) {
      await d.insert('arabic_badges', {
        'badge_id': id,
        'unlocked_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<ArabicBadge>> getUnlockedBadges() async {
    final d = await db;
    final rows = await d.query('arabic_badges');
    final ids = rows.map((r) => r['badge_id'] as String).toSet();
    return kArabicBadges.where((b) => ids.contains(b.id)).toList();
  }

  Future<List<String>> getNewlyUnlockedBadges(Set<String> previousIds) async {
    final d = await db;
    final rows = await d.query('arabic_badges');
    final currentIds = rows.map((r) => r['badge_id'] as String).toSet();
    return currentIds.difference(previousIds).toList();
  }

  // ─── XP calculation ───────────────────────────────────────────────────────

  int calculateXp({
    required int correctCount,
    required int totalCount,
    required int baseXp,
    required int streakDays,
  }) {
    final score = totalCount > 0 ? correctCount / totalCount : 0.0;
    int xp = baseXp;
    if (score == 1.0) xp += 25; // perfect bonus
    xp += (10 * streakDays.clamp(0, 7)).toInt(); // streak bonus
    return xp;
  }

  int calculateScore(int correct, int total) {
    if (total == 0) return 0;
    return ((correct / total) * 100).round();
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ignore: unused_element
  String _encode(Map<String, dynamic> map) => jsonEncode(map);
}

// ─── ValueNotifier for reactive UI ───────────────────────────────────────────

final arabicStatsNotifier = ValueNotifier<ArabicStats>(const ArabicStats());
