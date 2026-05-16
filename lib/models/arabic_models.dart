import 'package:flutter/material.dart';

// ─── Exercise types ────────────────────────────────────────────────────────

enum ExerciseType {
  letterIntro,
  letterRecognition,
  nameToLetter,
  letterForms,
  letterWriting,
  wordAssociation,
}

// ─── Arabic letter ─────────────────────────────────────────────────────────

class ArabicLetter {
  final String char;
  final String nameFr;
  final String nameAr;
  final String phonetic;
  final String exampleFr;
  // 4 positional forms
  final String isolated;
  final String initial;
  final String medial;
  final String final_;

  const ArabicLetter({
    required this.char,
    required this.nameFr,
    required this.nameAr,
    required this.phonetic,
    required this.exampleFr,
    required this.isolated,
    required this.initial,
    required this.medial,
    required this.final_,
  });
}

// ─── Exercise ──────────────────────────────────────────────────────────────

class Exercise {
  final ExerciseType type;
  final Map<String, dynamic> data;
  final int xpReward;

  const Exercise({
    required this.type,
    required this.data,
    this.xpReward = 10,
  });
}

// ─── Lesson ────────────────────────────────────────────────────────────────

class ArabicLesson {
  final String id;
  final String titleFr;
  final List<Exercise> exercises;
  final bool isQuiz;

  const ArabicLesson({
    required this.id,
    required this.titleFr,
    required this.exercises,
    this.isQuiz = false,
  });

  int get totalXp => exercises.fold(0, (sum, e) => sum + e.xpReward) + 50;
}

// ─── Unit ──────────────────────────────────────────────────────────────────

class ArabicUnit {
  final String id;
  final String titleFr;
  final String titleAr;
  final String emoji;
  final List<ArabicLesson> lessons;
  final Color accentColor;
  final String description;

  const ArabicUnit({
    required this.id,
    required this.titleFr,
    required this.titleAr,
    required this.emoji,
    required this.lessons,
    required this.accentColor,
    required this.description,
  });
}

// ─── Badge ─────────────────────────────────────────────────────────────────

class ArabicBadge {
  final String id;
  final String titleFr;
  final String emoji;
  final String description;
  final String condition; // human-readable

  const ArabicBadge({
    required this.id,
    required this.titleFr,
    required this.emoji,
    required this.description,
    required this.condition,
  });
}

// ─── Stats model ───────────────────────────────────────────────────────────

class ArabicStats {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final int hearts;
  final DateTime? lastHeartRefill;
  final DateTime? lastPractice;
  final Set<String> completedLessons;
  final Map<String, int> lessonBestScores;
  final Set<String> unlockedBadgeIds;

  const ArabicStats({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.hearts = 5,
    this.lastHeartRefill,
    this.lastPractice,
    this.completedLessons = const {},
    this.lessonBestScores = const {},
    this.unlockedBadgeIds = const {},
  });

  int get level => (totalXp / 200).floor() + 1;
  int get xpInCurrentLevel => totalXp % 200;
  int get xpNeededForNextLevel => 200;

  int minutesUntilNextHeart() {
    if (hearts >= 5) return 0;
    if (lastHeartRefill == null) return 0;
    final nextRefill = lastHeartRefill!.add(const Duration(minutes: 30));
    final diff = nextRefill.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inMinutes + 1;
  }

  ArabicStats copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    int? hearts,
    DateTime? lastHeartRefill,
    DateTime? lastPractice,
    Set<String>? completedLessons,
    Map<String, int>? lessonBestScores,
    Set<String>? unlockedBadgeIds,
  }) {
    return ArabicStats(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      hearts: hearts ?? this.hearts,
      lastHeartRefill: lastHeartRefill ?? this.lastHeartRefill,
      lastPractice: lastPractice ?? this.lastPractice,
      completedLessons: completedLessons ?? this.completedLessons,
      lessonBestScores: lessonBestScores ?? this.lessonBestScores,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
    );
  }
}

// ─── Lesson node state ─────────────────────────────────────────────────────

enum LessonNodeState { locked, current, completed }
