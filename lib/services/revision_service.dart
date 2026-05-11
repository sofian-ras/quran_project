import 'package:shared_preferences/shared_preferences.dart';
import '../models/revision_entry.dart';

class RevisionService {
  static final RevisionService instance = RevisionService._();
  RevisionService._();

  static const String _key = 'revision_entries';

  List<RevisionEntry>? _cache;

  Future<List<RevisionEntry>> getAll() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      _cache = RevisionEntry.listFromJson(raw);
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  Future<List<RevisionEntry>> getDueToday() async {
    final all = await getAll();
    return all.where((e) => e.isDueToday).toList();
  }

  Future<bool> isTracked(int surahId) async {
    final all = await getAll();
    return all.any((e) => e.surahId == surahId);
  }

  Future<void> addSurah({
    required int surahId,
    required String surahName,
    required String surahNameAr,
    required int ayahCount,
  }) async {
    final all = await getAll();
    if (all.any((e) => e.surahId == surahId)) return;
    final now = DateTime.now();
    all.add(RevisionEntry(
      surahId: surahId,
      surahName: surahName,
      surahNameAr: surahNameAr,
      ayahCount: ayahCount,
      addedAt: now,
      nextReview: now,
      intervalDays: 1,
      status: 'new',
    ));
    all.sort((a, b) => a.surahId.compareTo(b.surahId));
    await _save(all);
  }

  Future<void> removeSurah(int surahId) async {
    final all = await getAll();
    all.removeWhere((e) => e.surahId == surahId);
    await _save(all);
  }

  /// [correctCount] / [totalCount] → met à jour l'intervalle SRS.
  Future<void> recordSessionResult(
    int surahId, {
    required int correctCount,
    required int totalCount,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((e) => e.surahId == surahId);
    if (idx == -1) return;

    final entry = all[idx];
    final score = totalCount > 0 ? correctCount / totalCount : 0.0;
    final now = DateTime.now();

    int newInterval;
    String newStatus;

    if (score >= 0.8) {
      newInterval = (entry.intervalDays * 2).clamp(1, 90);
      newStatus = 'review';
    } else if (score >= 0.5) {
      newInterval = entry.intervalDays;
      newStatus = 'learning';
    } else {
      newInterval = 1;
      newStatus = 'lapsed';
    }

    all[idx] = entry.copyWith(
      lastReviewed: now,
      nextReview: now.add(Duration(days: newInterval)),
      intervalDays: newInterval,
      reviewCount: entry.reviewCount + 1,
      status: newStatus,
    );
    await _save(all);
  }

  Future<void> _save(List<RevisionEntry> entries) async {
    _cache = entries;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, RevisionEntry.listToJson(entries));
  }
}
