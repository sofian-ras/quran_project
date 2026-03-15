// lib/services/quran_db.dart
//
// Accès unifié à assets/data/quran.db — base générée depuis les fichiers
// Dart du package quran_pages_with_ayah_detector.
//
// Tables :
//   ayah_bbox        — bounding boxes des versets (88 246 lignes)
//                      columns: page, line, sura, ayah, min_x, max_x, min_y, max_y
//   quran_text_qcf   — glyphes QCF par page/ligne (6 236 lignes)
//                      columns: page, line, qcf_text
//   quran_plain      — texte arabe plain sans tashkeel (6 236 lignes)
//                      columns: sura, ayah, content
//   quran_tashkeel   — texte arabe vocalisé (6 236 lignes)
//                      columns: sura, ayah, content
//   quran_plain_fts  — index FTS5 sur quran_plain pour la recherche
//
// API publique :
//   QuranDb.instance.ensureReady()
//   QuranDb.instance.getBboxForPage(page)           → List<AyahBbox>
//   QuranDb.instance.getAyahAt(page, x, y)          → AyahBbox? (tap detection)
//   QuranDb.instance.getQcfLines(page)              → List<String>
//   QuranDb.instance.getPlainText(sura, ayah)       → String?
//   QuranDb.instance.getTashkeelText(sura, ayah)    → String?
//   QuranDb.instance.searchPlain(query, {limit})    → List<SearchResult>

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ── Data classes ─────────────────────────────────────────────────────────────

class AyahBbox {
  final int page;
  final int line;
  final int sura;
  final int ayah;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const AyahBbox({
    required this.page,
    required this.line,
    required this.sura,
    required this.ayah,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory AyahBbox.fromRow(Map<String, Object?> r) => AyahBbox(
        page: r['page'] as int,
        line: r['line'] as int,
        sura: r['sura'] as int,
        ayah: r['ayah'] as int,
        minX: (r['min_x'] as num).toDouble(),
        maxX: (r['max_x'] as num).toDouble(),
        minY: (r['min_y'] as num).toDouble(),
        maxY: (r['max_y'] as num).toDouble(),
      );
}

class SearchResult {
  final int sura;
  final int ayah;
  final String content;

  const SearchResult({
    required this.sura,
    required this.ayah,
    required this.content,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class QuranDb {
  static final QuranDb instance = QuranDb._();
  QuranDb._();

  Database? _db;

  static const String _assetPath = 'assets/data/quran.db';
  static const String _fileName = 'quran.db';

  // Cache en mémoire par page pour les bounding boxes (utilisées très souvent).
  final Map<int, List<AyahBbox>> _bboxCache = {};

  Future<String> _dbPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'qul', _fileName);
  }

  /// Copie la DB depuis les assets si nécessaire, puis l'ouvre.
  /// À appeler une fois au démarrage (ex: dans main() ou un splash screen).
  Future<void> ensureReady() async {
    if (_db != null) return;

    final dbPath = await _dbPath();

    if (!await File(dbPath).exists()) {
      final dir = Directory(p.dirname(dbPath));
      if (!await dir.exists()) await dir.create(recursive: true);
      final bytes = await rootBundle.load(_assetPath);
      await File(dbPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    _db = await openDatabase(dbPath, readOnly: true);
  }

  Future<Database> _open() async {
    if (_db == null) await ensureReady();
    return _db!;
  }

  // ── Bounding boxes ────────────────────────────────────────────────────────

  /// Retourne toutes les bounding boxes d'une page (avec cache mémoire).
  Future<List<AyahBbox>> getBboxForPage(int page) async {
    if (_bboxCache.containsKey(page)) return _bboxCache[page]!;

    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT page, line, sura, ayah, min_x, max_x, min_y, max_y '
      'FROM ayah_bbox WHERE page = ? ORDER BY line, min_x DESC',
      [page],
    );
    final result = rows.map(AyahBbox.fromRow).toList();
    _bboxCache[page] = result;
    return result;
  }

  /// Détecte quel ayah a été touché à la position (x, y) sur une page.
  /// Les coordonnées doivent être dans le repère de l'image originale (1920px).
  /// Retourne null si aucun ayah n'est assez proche (tolérance: 20px).
  Future<AyahBbox?> getAyahAt({
    required int page,
    required double x,
    required double y,
    double tolerance = 20.0,
  }) async {
    final db = await _open();
    final rows = await db.rawQuery(
      '''
      SELECT page, line, sura, ayah, min_x, max_x, min_y, max_y,
             (MAX(min_x - ?, 0.0) + MAX(? - max_x, 0.0)) +
             (MAX(min_y - ?, 0.0) + MAX(? - max_y, 0.0)) AS dist
      FROM ayah_bbox
      WHERE page = ?
      ORDER BY dist ASC
      LIMIT 1
      ''',
      [x, x, y, y, page],
    );

    if (rows.isEmpty) return null;
    final dist = (rows.first['dist'] as num).toDouble();
    if (dist > tolerance) return null;
    return AyahBbox.fromRow(rows.first);
  }

  // ── Texte QCF ─────────────────────────────────────────────────────────────

  /// Retourne les lignes QCF d'une page dans l'ordre.
  Future<List<String>> getQcfLines(int page) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT qcf_text FROM quran_text_qcf WHERE page = ? ORDER BY line',
      [page],
    );
    return rows.map((r) => r['qcf_text'] as String).toList();
  }

  // ── Texte arabe ───────────────────────────────────────────────────────────

  /// Texte arabe plain (sans tashkeel) d'un verset. Utile pour la recherche.
  Future<String?> getPlainText(int sura, int ayah) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT content FROM quran_plain WHERE sura = ? AND ayah = ? LIMIT 1',
      [sura, ayah],
    );
    if (rows.isEmpty) return null;
    return rows.first['content'] as String?;
  }

  /// Texte arabe vocalisé (avec tashkeel) d'un verset.
  Future<String?> getTashkeelText(int sura, int ayah) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT content FROM quran_tashkeel WHERE sura = ? AND ayah = ? LIMIT 1',
      [sura, ayah],
    );
    if (rows.isEmpty) return null;
    return rows.first['content'] as String?;
  }

  /// Tous les versets d'une sourate (plain text), triés par numéro d'ayah.
  Future<Map<int, String>> getSurahPlainTexts(int sura) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT ayah, content FROM quran_plain WHERE sura = ? ORDER BY ayah',
      [sura],
    );
    return {for (final r in rows) r['ayah'] as int: r['content'] as String};
  }

  /// Tous les versets d'une sourate (avec tashkeel), triés par numéro d'ayah.
  Future<Map<int, String>> getSurahTashkeelTexts(int sura) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT ayah, content FROM quran_tashkeel WHERE sura = ? ORDER BY ayah',
      [sura],
    );
    return {for (final r in rows) r['ayah'] as int: r['content'] as String};
  }

  // ── Recherche FTS ─────────────────────────────────────────────────────────

  /// Recherche plein texte dans le Coran (arabe sans tashkeel).
  /// Retourne jusqu'à [limit] résultats.
  Future<List<SearchResult>> searchPlain(String query,
      {int limit = 50}) async {
    final db = await _open();
    // Joindre FTS avec la table principale pour récupérer sura/ayah.
    final rows = await db.rawQuery(
      '''
      SELECT p.sura, p.ayah, p.content
      FROM quran_plain p
      JOIN quran_plain_fts fts ON fts.rowid = p.rowid
      WHERE quran_plain_fts MATCH ?
      LIMIT ?
      ''',
      [query, limit],
    );
    return rows
        .map((r) => SearchResult(
              sura: r['sura'] as int,
              ayah: r['ayah'] as int,
              content: r['content'] as String,
            ))
        .toList();
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  void clearBboxCache() => _bboxCache.clear();

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _bboxCache.clear();
  }
}
