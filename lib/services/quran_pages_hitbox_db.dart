import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AyahBox {
  final int page;
  final int surah;
  final int ayah;
  final double x;
  final double y;
  final double w;
  final double h;

  const AyahBox({
    required this.page,
    required this.surah,
    required this.ayah,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

/// Accès lecture seule à une DB SQLite de coordonnées (page -> ayah rectangles).
/// Compatible avec plusieurs schémas tant que la table contient :
/// - page
/// - sura/surah
/// - aya/ayah
/// - x, y, w/width, h/height
class QuranPagesHitboxDb {
  static final QuranPagesHitboxDb instance = QuranPagesHitboxDb._();
  QuranPagesHitboxDb._();

  Database? _db;
  String? _table;
  String? _colPage, _colSurah, _colAyah, _colX, _colY, _colW, _colH;

  /// Copie une DB depuis assets vers Documents si elle n'existe pas.
  /// Exemple: assetPath = 'assets/data/quranpages.sqlite'
  Future<void> ensureFromAsset({required String assetPath, String outName = 'quranpages.sqlite'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'quran_pages'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final outPath = p.join(outDir.path, outName);
    if (await File(outPath).exists()) return;

    final bytes = await rootBundle.load(assetPath);
    final buffer = bytes.buffer;
    await File(outPath).writeAsBytes(buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  }

  Future<Database> _open({String? overridePath}) async {
    if (_db != null) return _db!;
    final path = overridePath ?? await _defaultPath();
    _db = await openDatabase(path, readOnly: true);
    await _detectSchema(_db!);
    return _db!;
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'quran_pages', 'quranpages.sqlite');
  }

  Future<void> _detectSchema(Database db) async {
    if (_table != null) return;

    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    for (final t in tables) {
      final name = (t['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final info = await db.rawQuery("PRAGMA table_info($name)");
      final cols = info.map((e) => (e['name'] as String).toLowerCase()).toSet();

      // Must have x & y
      if (!cols.contains('x') || !cols.contains('y')) continue;

      // Page col
      final pageCol = _pick(cols, ['page', 'page_number', 'page_no']);
      if (pageCol == null) continue;

      // Surah + ayah cols
      final surahCol = _pick(cols, ['sura', 'surah', 's']);
      final ayahCol = _pick(cols, ['aya', 'ayah', 'a']);
      if (surahCol == null || ayahCol == null) continue;

      // width/height variants
      final wCol = _pick(cols, ['w', 'width']);
      final hCol = _pick(cols, ['h', 'height']);
      if (wCol == null || hCol == null) continue;

      _table = name;
      _colPage = pageCol;
      _colSurah = surahCol;
      _colAyah = ayahCol;
      _colX = 'x';
      _colY = 'y';
      _colW = wCol;
      _colH = hCol;
      return;
    }

    throw StateError("Impossible de détecter une table de coordonnées dans quranpages.sqlite");
  }

  String? _pick(Set<String> cols, List<String> candidates) {
    for (final c in candidates) {
      if (cols.contains(c)) return c;
    }
    return null;
  }

  Future<List<AyahBox>> getPageBoxes(int page, {String? dbPathOverride}) async {
    final db = await _open(overridePath: dbPathOverride);
    final table = _table!;
    final rows = await db.query(
      table,
      where: '${_colPage!} = ?',
      whereArgs: [page],
      orderBy: '${_colSurah!} ASC, ${_colAyah!} ASC',
    );

    double _d(Object? v) => (v as num).toDouble();

    return rows.map((r) {
      return AyahBox(
        page: (r[_colPage!] as num).toInt(),
        surah: (r[_colSurah!] as num).toInt(),
        ayah: (r[_colAyah!] as num).toInt(),
        x: _d(r[_colX!]),
        y: _d(r[_colY!]),
        w: _d(r[_colW!]),
        h: _d(r[_colH!]),
      );
    }).toList();
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _table = null;
    if (db != null) await db.close();
  }
}
