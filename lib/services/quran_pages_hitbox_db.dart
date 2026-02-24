// lib/services/quran_pages_hitbox_db.dart
//
// Service de hitbox des versets — lecture SQLite (quranpages1024.sqlite).
//
// Schéma attendu :
//   TABLE ayarects (page INT, soraid INT, ayaid INT,
//                   minx REAL, miny REAL, maxx REAL, maxy REAL)
//
// API publique :
//   ensureFromAsset(assetPath)          — copie le SQLite asset → disque (idempotent)
//   getAyahAt(page, x, y)              → {surah, ayah} ou null
//   getAyahRect(page, surah, ayah)     → Rect ou null

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class QuranPagesHitboxDb {
  static final QuranPagesHitboxDb instance = QuranPagesHitboxDb._();
  QuranPagesHitboxDb._();

  Database? _db;

  Future<void> ensureFromAsset({required String assetPath}) async {
    final dbPath = await _resolveDbPath();
    final file = File(dbPath);

    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final bytes = await rootBundle.load(assetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    await _open();
  }

  Future<String> _resolveDbPath() async {
    final dir = await getDatabasesPath();
    return join(dir, 'quranpages1024.sqlite');
  }

  Future<void> _open() async {
    if (_db != null) return;
    final path = await _resolveDbPath();
    _db = await openDatabase(path, readOnly: true);
  }

  Future<Map<String, int>?> getAyahAt({
    required int page,
    required double x,
    required double y,
  }) async {
    await _open();
    final rows = await _db!.rawQuery(
      '''
      SELECT soraid, ayaid
      FROM ayarects
      WHERE page = ?
        AND ? >= minx AND ? <= maxx
        AND ? >= miny AND ? <= maxy
      LIMIT 1
      ''',
      [page, x, x, y, y],
    );

    if (rows.isEmpty) return null;
    return {
      'surah': rows.first['soraid'] as int,
      'ayah': rows.first['ayaid'] as int,
    };
  }

  /// Retourne tous les rectangles individuels (mots) d'un verset, triés par miny.
  Future<List<Rect>> getAyahRects({
    required int page,
    required int surah,
    required int ayah,
  }) async {
    await _open();
    final rows = await _db!.rawQuery(
      '''
      SELECT minx, miny, maxx, maxy
      FROM ayarects
      WHERE page = ? AND soraid = ? AND ayaid = ?
      ORDER BY miny, minx
      ''',
      [page, surah, ayah],
    );

    return rows.map((r) => Rect.fromLTRB(
      (r['minx'] as num).toDouble(),
      (r['miny'] as num).toDouble(),
      (r['maxx'] as num).toDouble(),
      (r['maxy'] as num).toDouble(),
    )).toList();
  }
}
