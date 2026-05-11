import 'dart:convert';

class RevisionEntry {
  final int surahId;
  final String surahName;
  final String surahNameAr;
  final int ayahCount;
  final DateTime addedAt;
  final DateTime? lastReviewed;
  final DateTime? nextReview;
  final int intervalDays;
  final int reviewCount;
  // 'new' | 'learning' | 'review' | 'lapsed'
  final String status;

  const RevisionEntry({
    required this.surahId,
    required this.surahName,
    required this.surahNameAr,
    required this.ayahCount,
    required this.addedAt,
    this.lastReviewed,
    this.nextReview,
    this.intervalDays = 1,
    this.reviewCount = 0,
    this.status = 'new',
  });

  bool get isDueToday {
    if (nextReview == null) return true;
    final now = DateTime.now();
    return nextReview!.isBefore(now) || _isSameDay(nextReview!, now);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  RevisionEntry copyWith({
    DateTime? lastReviewed,
    DateTime? nextReview,
    int? intervalDays,
    int? reviewCount,
    String? status,
  }) {
    return RevisionEntry(
      surahId: surahId,
      surahName: surahName,
      surahNameAr: surahNameAr,
      ayahCount: ayahCount,
      addedAt: addedAt,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      nextReview: nextReview ?? this.nextReview,
      intervalDays: intervalDays ?? this.intervalDays,
      reviewCount: reviewCount ?? this.reviewCount,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'surahId': surahId,
        'surahName': surahName,
        'surahNameAr': surahNameAr,
        'ayahCount': ayahCount,
        'addedAt': addedAt.toIso8601String(),
        'lastReviewed': lastReviewed?.toIso8601String(),
        'nextReview': nextReview?.toIso8601String(),
        'intervalDays': intervalDays,
        'reviewCount': reviewCount,
        'status': status,
      };

  factory RevisionEntry.fromJson(Map<String, dynamic> json) => RevisionEntry(
        surahId: json['surahId'] as int,
        surahName: json['surahName'] as String,
        surahNameAr: (json['surahNameAr'] as String?) ?? '',
        ayahCount: (json['ayahCount'] as int?) ?? 0,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastReviewed: json['lastReviewed'] != null
            ? DateTime.parse(json['lastReviewed'] as String)
            : null,
        nextReview: json['nextReview'] != null
            ? DateTime.parse(json['nextReview'] as String)
            : null,
        intervalDays: (json['intervalDays'] as int?) ?? 1,
        reviewCount: (json['reviewCount'] as int?) ?? 0,
        status: (json['status'] as String?) ?? 'new',
      );

  static List<RevisionEntry> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RevisionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<RevisionEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());
}
