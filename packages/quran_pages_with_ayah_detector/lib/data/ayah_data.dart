/// Ayah bounding box data — loaded at runtime from a JSON asset.
/// Replaces the former 882 k-line Dart const list to dramatically
/// reduce compile time.
library;

import 'dart:convert';
import 'package:flutter/services.dart';

// ── Internal cache ────────────────────────────────────────────────────────────

/// Page-keyed cache: page → list of rows, each row = [ln, sn, an, x0, y0, x1, y1]
Map<int, List<List<int>>>? _cache;

Future<Map<int, List<List<int>>>> _ensureLoaded() async {
  if (_cache != null) return _cache!;
  final s = await rootBundle.loadString(
    'packages/quran_pages_with_ayah_detector/lib/data/ayah_data.json',
  );
  final raw = jsonDecode(s) as Map<String, dynamic>;
  _cache = raw.map(
    (k, v) => MapEntry(
      int.parse(k),
      List<List<int>>.from(
        (v as List).map((e) => List<int>.from(e as List)),
      ),
    ),
  );
  return _cache!;
}

Map<String, Object?> _rowToMap(int page, List<int> r) => {
      'page_number': page,
      'line_number': r[0],
      'sura_number': r[1],
      'ayah_number': r[2],
      'min_x': r[3],
      'min_y': r[4],
      'max_x': r[5],
      'max_y': r[6],
    };

// ── Public API ────────────────────────────────────────────────────────────────

/// All rows as Maps — equivalent to the former [ayahRows] const list.
/// Prefer [ayahRowsForPage] for page-specific lookups (O(1) vs O(n)).
Future<List<Map<String, Object?>>> get ayahRows async {
  final data = await _ensureLoaded();
  return [
    for (final e in data.entries)
      for (final r in e.value) _rowToMap(e.key, r),
  ];
}

/// Rows for a specific page — O(1) lookup into the cached map.
Future<List<Map<String, Object?>>> ayahRowsForPage(int page) async {
  final data = await _ensureLoaded();
  return (data[page] ?? []).map((r) => _rowToMap(page, r)).toList();
}

/// Builds the page→ayah-list map directly from cache — skips the O(n) loop.
Future<Map<int, List<Map<String, int>>>> buildPageAyahMap() async {
  final data = await _ensureLoaded();
  final result = <int, List<Map<String, int>>>{};
  for (final e in data.entries) {
    final seen = <String>{};
    final ayahs = <Map<String, int>>[];
    for (final r in e.value) {
      final key = '${r[1]}:${r[2]}';
      if (seen.add(key)) ayahs.add({'surah': r[1], 'ayah': r[2]});
    }
    ayahs.sort((a, b) => a['surah'] != b['surah']
        ? a['surah']!.compareTo(b['surah']!)
        : a['ayah']!.compareTo(b['ayah']!));
    result[e.key] = ayahs;
  }
  return result;
}
