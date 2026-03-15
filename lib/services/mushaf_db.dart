// lib/services/mushaf_db.dart
//
// Accès unique à mushaf.db — base SQLite contenant :
//   surahs      : métadonnées des 114 sourates
//   pages       : première sourate/verset de chaque page (1-604)
//   page_lines  : texte QCF par page/ligne  → rendu
//   ayah_rects  : boîtes de tap par page    → détection du verset
//   verses      : texte hafs/warsh par verset
//   verses_fts  : index FTS5 pour la recherche arabe
//
// Usage :
//   await MushafDb.instance.init();   // une fois au démarrage
//   final lines = await MushafDb.instance.getPageLines(1);
//   final hit   = await MushafDb.instance.getAyahAt(page: 1, x: 500, y: 400);
//   final res   = await MushafDb.instance.search('الله');

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ── Modèles légers ────────────────────────────────────────────────────────────

class SurahInfo {
  final int    id;
  final String nameAr;
  final String nameFr;
  final int    pageStart;
  final int    ayahCount;
  final bool   isMadani;

  const SurahInfo({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.pageStart,
    required this.ayahCount,
    required this.isMadani,
  });

  factory SurahInfo.fromRow(Map<String, Object?> r) => SurahInfo(
    id:        r['id']         as int,
    nameAr:    r['name_ar']    as String,
    nameFr:    r['name_fr']    as String,
    pageStart: r['page_start'] as int,
    ayahCount: r['ayah_count'] as int,
    isMadani:  (r['is_madani'] as int) == 1,
  );
}

class PageInfo {
  final int page;
  final int surahStart;
  final int ayahStart;

  const PageInfo({
    required this.page,
    required this.surahStart,
    required this.ayahStart,
  });

  factory PageInfo.fromRow(Map<String, Object?> r) => PageInfo(
    page:       r['page']        as int,
    surahStart: r['surah_start'] as int,
    ayahStart:  r['ayah_start']  as int,
  );
}

class AyahRect {
  final int    page;
  final int    surah;
  final int    ayah;
  final int    line;
  final Rect   rect;

  const AyahRect({
    required this.page,
    required this.surah,
    required this.ayah,
    required this.line,
    required this.rect,
  });

  factory AyahRect.fromRow(Map<String, Object?> r) => AyahRect(
    page:  r['page']  as int,
    surah: r['surah'] as int,
    ayah:  r['ayah']  as int,
    line:  r['line']  as int,
    rect:  Rect.fromLTRB(
      (r['x0'] as int).toDouble(),
      (r['y0'] as int).toDouble(),
      (r['x1'] as int).toDouble(),
      (r['y1'] as int).toDouble(),
    ),
  );
}

class SearchResult {
  final int    surah;
  final int    ayah;
  final String textPlain;

  const SearchResult({
    required this.surah,
    required this.ayah,
    required this.textPlain,
  });
}

// ── Service principal ─────────────────────────────────────────────────────────

class MushafDb {
  static final MushafDb instance = MushafDb._();
  MushafDb._();

  static const _assetPath = 'assets/data/Mushaf/mushaf.db';
  static const _dbName    = 'mushaf.db';

  Database? _db;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// À appeler une fois au démarrage (idempotent).
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = join(await getDatabasesPath(), _dbName);
    final file   = File(dbPath);

    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final bytes = await rootBundle.load(_assetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    _db = await openDatabase(dbPath, readOnly: true);
  }

  Database get _d {
    assert(_db != null, 'MushafDb.init() non appelé');
    return _db!;
  }

  // ── Sourates ────────────────────────────────────────────────────────────────

  /// Toutes les sourates (114).
  Future<List<SurahInfo>> getAllSurahs() async {
    final rows = await _d.query('surahs', orderBy: 'id');
    return rows.map(SurahInfo.fromRow).toList();
  }

  /// Une sourate par id.
  Future<SurahInfo?> getSurah(int id) async {
    final rows = await _d.query('surahs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SurahInfo.fromRow(rows.first);
  }

  // ── Pages ───────────────────────────────────────────────────────────────────

  /// Infos de début de page (surah_start, ayah_start).
  Future<PageInfo?> getPageInfo(int page) async {
    final rows = await _d.query('pages', where: 'page = ?', whereArgs: [page]);
    return rows.isEmpty ? null : PageInfo.fromRow(rows.first);
  }

  /// Page où commence un verset donné.
  Future<int?> getPageForAyah(int surah, int ayah) async {
    final rows = await _d.rawQuery(
      'SELECT page FROM verses WHERE surah = ? AND ayah = ? LIMIT 1',
      [surah, ayah],
    );
    return rows.isEmpty ? null : rows.first['page'] as int;
  }

  // ── Rendu QCF ───────────────────────────────────────────────────────────────

  /// Lignes de texte QCF pour une page (dans l'ordre des lignes).
  Future<List<String>> getPageLines(int page) async {
    final rows = await _d.query(
      'page_lines',
      where:   'page = ?',
      whereArgs: [page],
      orderBy: 'line_number',
    );
    return rows.map((r) => r['text_qcf'] as String).toList();
  }

  // ── Tap detection ───────────────────────────────────────────────────────────

  /// Verset le plus proche du point (x, y) sur une page (distance Manhattan).
  /// Retourne {surah, ayah} ou null si trop loin (> 20 px).
  Future<Map<String, int>?> getAyahAt({
    required int    page,
    required double x,
    required double y,
  }) async {
    final rows = await _d.rawQuery('''
      SELECT surah, ayah,
             (MAX(x0 - ?, 0) + MAX(? - x1, 0)) +
             (MAX(y0 - ?, 0) + MAX(? - y1, 0)) AS dist
      FROM ayah_rects
      WHERE page = ?
      ORDER BY dist ASC
      LIMIT 1
    ''', [x, x, y, y, page]);

    if (rows.isEmpty) return null;
    if ((rows.first['dist'] as num).toDouble() > 20.0) return null;
    return {
      'surah': rows.first['surah'] as int,
      'ayah':  rows.first['ayah']  as int,
    };
  }

  /// Tous les rectangles d'un verset sur une page.
  Future<List<Rect>> getAyahRects({
    required int page,
    required int surah,
    required int ayah,
  }) async {
    final rows = await _d.query(
      'ayah_rects',
      where:     'page = ? AND surah = ? AND ayah = ?',
      whereArgs: [page, surah, ayah],
      orderBy:   'y0, x0',
    );
    return rows.map((r) => AyahRect.fromRow(r).rect).toList();
  }

  // ── Texte des versets ───────────────────────────────────────────────────────

  /// Texte hafs d'un verset.
  Future<String?> getHafs(int surah, int ayah) async {
    final rows = await _d.query(
      'verses',
      columns:   ['hafs'],
      where:     'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
    );
    return rows.isEmpty ? null : rows.first['hafs'] as String?;
  }

  /// Texte warsh d'un verset.
  Future<String?> getWarsh(int surah, int ayah) async {
    final rows = await _d.query(
      'verses',
      columns:   ['warsh'],
      where:     'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
    );
    return rows.isEmpty ? null : rows.first['warsh'] as String?;
  }

  // ── Recherche FTS5 ──────────────────────────────────────────────────────────

  /// Recherche dans le Coran (texte sans diacritiques).
  /// Retourne jusqu'à [limit] résultats.
  Future<List<SearchResult>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];

    // FTS5 : on échappe les guillemets doubles pour éviter les erreurs de syntaxe
    final q = query.trim().replaceAll('"', '""');

    final rows = await _d.rawQuery(
      'SELECT surah, ayah, text_plain FROM verses_fts WHERE text_plain MATCH ? LIMIT ?',
      ['"$q"', limit],
    );

    return rows.map((r) => SearchResult(
      surah:     r['surah']      as int,
      ayah:      r['ayah']       as int,
      textPlain: r['text_plain'] as String,
    )).toList();
  }
}
