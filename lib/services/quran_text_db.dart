import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'quran_translation_pack_service.dart';

class QuranTextDb {
  static final QuranTextDb instance = QuranTextDb._();
  QuranTextDb._();

  Database? _dbAr;
  Database? _dbFr;
  Database? _dbLegacy;

  _DbShape? _shapeAr;
  _DbShape? _shapeFr;
  _DbShape? _shapeLegacy;

  Future<String> _baseQulDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'qul');
  }

  // Noms de fichiers "unifiés" (QUL-like)
  Future<String> _arPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'quran_text_ar.sqlite');
  }

  Future<String> _frPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'translation_fr.sqlite');
  }

  // Fallback temporaire (si tu n’as pas encore splitté en AR/FR)
  Future<String> _legacyPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'quran_text_fr.sqlite');
  }

  Future<bool> isReady() async {
    // Migration one-shot : copie quran_translation/ → qul/ si besoin
    await QuranTranslationPackService.migrateLegacyToQulIfNeeded();

    final ar = await _arPath();
    final fr = await _frPath();
    if (await File(ar).exists() && await File(fr).exists()) return true;

    final legacy = await _legacyPath();
    return File(legacy).exists();
  }

  Future<Database> _openAr() async {
    if (_dbAr != null) return _dbAr!;
    final path = await _arPath();
    _dbAr = await openDatabase(path, readOnly: true);
    _shapeAr = await _inspect(_dbAr!);
    return _dbAr!;
  }

  Future<Database> _openFr() async {
    if (_dbFr != null) return _dbFr!;
    final path = await _frPath();
    _dbFr = await openDatabase(path, readOnly: true);
    _shapeFr = await _inspect(_dbFr!);
    return _dbFr!;
  }

  Future<Database> _openLegacy() async {
    if (_dbLegacy != null) return _dbLegacy!;
    final path = await _legacyPath();
    _dbLegacy = await openDatabase(path, readOnly: true);
    _shapeLegacy = await _inspect(_dbLegacy!);
    return _dbLegacy!;
  }

  Future<QVerse?> getVerseByKey(String verseKey) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]) ?? 0;
    final ayah = int.tryParse(parts[1]) ?? 0;

    final arPath = await _arPath();
    final frPath = await _frPath();

    // Mode QUL split: AR + FR séparés
    if (await File(arPath).exists() && await File(frPath).exists()) {
      final dbAr = await _openAr();
      final dbFr = await _openFr();

      final ar = await _getTextByVerseKey(dbAr, _shapeAr!, verseKey) ?? '';
      final fr = await _getTextByVerseKey(dbFr, _shapeFr!, verseKey) ?? '';

      // tafsir = null (Étape 3)
      return QVerse(
        verseKey: verseKey,
        surah: surah,
        ayah: ayah,
        ar: ar,
        fr: fr,
        tafsir: null,
      );
    }

    // Fallback: DB combinée (ancienne)
    final legacy = await _legacyPath();
    if (await File(legacy).exists()) {
      final db = await _openLegacy();
      final sh = _shapeLegacy!;
      final row = await _getRowByVerseKey(db, sh, verseKey);
      if (row == null) return null;

      // On essaye d’être compatible avec ton ancien schéma (ar/fr/tafsir)
      final ar = (row['ar'] ?? row[sh.textCol] ?? '') as String;
      final fr = (row['fr'] ?? '') as String;
      final tafsir = row['tafsir'] as String?;
      final s = (row['surah'] as num?)?.toInt() ?? surah;
      final a = (row['ayah'] as num?)?.toInt() ?? ayah;

      return QVerse(
        verseKey: verseKey,
        surah: s,
        ayah: a,
        ar: ar,
        fr: fr,
        tafsir: tafsir,
      );
    }

    return null;
  }

  Future<List<QVerse>> getSurah(int surah) async {
    // Minimal & sûr : génère les keys et utilise getVerseByKey
    // (286 max -> ok; optimisations plus tard si besoin)
    final out = <QVerse>[];
    for (int ayah = 1; ayah <= 286; ayah++) {
      final v = await getVerseByKey('$surah:$ayah');
      if (v == null) break;
      out.add(v);
    }
    return out;
  }

  Future<List<QVerse>> getRange(int surah, int fromAyah, int toAyah) async {
    final out = <QVerse>[];
    for (int ayah = fromAyah; ayah <= toAyah; ayah++) {
      final v = await getVerseByKey('$surah:$ayah');
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<Map<String, QVerse>> getVersesByKeys(List<String> keys) async {
    final map = <String, QVerse>{};
    for (final k in keys) {
      final v = await getVerseByKey(k);
      if (v != null) map[k] = v;
    }
    return map;
  }

  Future<void> close() async {
    await _dbAr?.close();
    await _dbFr?.close();
    await _dbLegacy?.close();
    _dbAr = null;
    _dbFr = null;
    _dbLegacy = null;
    _shapeAr = null;
    _shapeFr = null;
    _shapeLegacy = null;
  }

  // --------- Helpers (schema flexible) ---------

  Future<_DbShape> _inspect(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );

    // 1) préfère une table qui a verse_key
    for (final t in tables) {
      final name = t['name'] as String;
      final cols = await db.rawQuery("PRAGMA table_info('$name')");
      final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();

      if (colNames.contains('verse_key')) {
        final textCol = _pickTextCol(colNames);
        if (textCol != null) {
          return _DbShape(table: name, verseKeyCol: 'verse_key', textCol: textCol);
        }
      }
    }

    // 2) sinon table avec (surah + ayah) et un champ texte
    for (final t in tables) {
      final name = t['name'] as String;
      final cols = await db.rawQuery("PRAGMA table_info('$name')");
      final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();

      if (colNames.contains('surah') && colNames.contains('ayah')) {
        final textCol = _pickTextCol(colNames);
        if (textCol != null) {
          return _DbShape(
            table: name,
            verseKeyCol: null,
            textCol: textCol,
          );
        }
      }
    }

    // 3) fallback brut : table "verses" si existe, sinon 1ère table
    final fallback = tables.isNotEmpty ? (tables.first['name'] as String) : 'verses';
    final cols = await db.rawQuery("PRAGMA table_info('$fallback')");
    final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();
    return _DbShape(
      table: fallback,
      verseKeyCol: colNames.contains('verse_key') ? 'verse_key' : null,
      textCol: _pickTextCol(colNames) ?? 'text',
    );
  }

  String? _pickTextCol(Set<String> cols) {
    const candidates = [
      'text',
      'value',
      'content',
      'arabic_text',
      'translation',
      'text_uthmani',
      'text_uthmani_simple',
    ];
    for (final c in candidates) {
      if (cols.contains(c)) return c;
    }
    return null;
  }

  Future<String?> _getTextByVerseKey(Database db, _DbShape sh, String verseKey) async {
    final row = await _getRowByVerseKey(db, sh, verseKey);
    if (row == null) return null;
    final v = row[sh.textCol];
    return v is String ? v : (v?.toString());
  }

  Future<Map<String, Object?>?> _getRowByVerseKey(Database db, _DbShape sh, String verseKey) async {
    if (sh.verseKeyCol != null) {
      final rows = await db.query(
        sh.table,
        where: '${sh.verseKeyCol} = ?',
        whereArgs: [verseKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    }

    // Si pas de verse_key, on parse "S:A" et on query sur surah/ayah
    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1]);
    if (s == null || a == null) return null;

    final rows = await db.query(
      sh.table,
      where: 'surah = ? AND ayah = ?',
      whereArgs: [s, a],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}

class _DbShape {
  final String table;
  final String? verseKeyCol;
  final String textCol;

  _DbShape({
    required this.table,
    required this.verseKeyCol,
    required this.textCol,
  });
}

class QVerse {
  final String verseKey;
  final int surah;
  final int ayah;
  final String ar;
  final String fr;
  final String? tafsir;

  QVerse({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.ar,
    required this.fr,
    required this.tafsir,
  });

  factory QVerse.fromMap(Map<String, Object?> m) {
    return QVerse(
      verseKey: (m['verse_key'] as String),
      surah: (m['surah'] as num).toInt(),
      ayah: (m['ayah'] as num).toInt(),
      ar: (m['ar'] as String),
      fr: (m['fr'] as String),
      tafsir: m['tafsir'] as String?,
    );
  }
}