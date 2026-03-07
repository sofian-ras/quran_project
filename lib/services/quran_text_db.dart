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

  // Cache léger : numéro de sourate → versets déjà chargés depuis SQLite.
  // Invalidé par close(). Évite de relire la DB à chaque rebuild de l'écran.
  final Map<int, List<QVerse>> _surahCache = {};

  Future<String> _baseQulDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'qul');
  }

  Future<String> _arPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'quran_text_ar.sqlite');
  }

  Future<String> _frPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'translation_fr.sqlite');
  }

  Future<String> _legacyPath() async {
    final base = await _baseQulDir();
    return p.join(base, 'quran_text_fr.sqlite');
  }

  Future<bool> isReady() async {
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

  // ── Lecture d'un verset unique (inchangé) ────────────────────────────────

  Future<QVerse?> getVerseByKey(String verseKey) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]) ?? 0;
    final ayah  = int.tryParse(parts[1]) ?? 0;

    final arPath = await _arPath();
    final frPath = await _frPath();

    if (await File(arPath).exists() && await File(frPath).exists()) {
      final dbAr = await _openAr();
      final dbFr = await _openFr();

      final ar = await _getTextByVerseKey(dbAr, _shapeAr!, verseKey) ?? '';
      final fr = await _getTextByVerseKey(dbFr, _shapeFr!, verseKey) ?? '';

      return QVerse(
        verseKey: verseKey,
        surah:    surah,
        ayah:     ayah,
        ar:       ar,
        fr:       fr,
        tafsir:   null,
      );
    }

    final legacy = await _legacyPath();
    if (await File(legacy).exists()) {
      final db  = await _openLegacy();
      final sh  = _shapeLegacy!;
      final row = await _getRowByVerseKey(db, sh, verseKey);
      if (row == null) return null;

      return QVerse(
        verseKey: verseKey,
        surah:    (row['surah'] as num?)?.toInt()  ?? surah,
        ayah:     (row['ayah']  as num?)?.toInt()  ?? ayah,
        ar:       (row['ar'] ?? row[sh.textCol])?.toString() ?? '',
        fr:       row['fr']?.toString() ?? '',
        tafsir:   row['tafsir']?.toString(),
      );
    }

    return null;
  }

  // ── Lecture groupée d'une sourate entière ─────────────────────────────────
  //
  // Avant : boucle de 286 appels getVerseByKey() = 286 requêtes SQL.
  // Après : 1 requête SQL pour AR + 1 pour FR (mode split) ou 1 seule (legacy).

  Future<List<QVerse>> getSurah(int surah) async {
    // Retourne le résultat mis en cache si la sourate a déjà été lue.
    final cached = _surahCache[surah];
    if (cached != null) return cached;

    final arPath = await _arPath();
    final frPath = await _frPath();
    final List<QVerse> result;

    if (await File(arPath).exists() && await File(frPath).exists()) {
      // ── Mode split AR + FR ──
      final dbAr = await _openAr();
      final dbFr = await _openFr();

      final arRows = await _fetchAllSurahRows(dbAr, _shapeAr!, surah);
      final frRows = await _fetchAllSurahRows(dbFr, _shapeFr!, surah);

      // Indexer le texte FR par verse_key pour fusion O(1).
      final frByKey = <String, String>{};
      for (final row in frRows) {
        final key = _rowVerseKey(row, _shapeFr!, surah);
        if (key.isNotEmpty) frByKey[key] = row[_shapeFr!.textCol]?.toString() ?? '';
      }

      result = [];
      for (final row in arRows) {
        final key   = _rowVerseKey(row, _shapeAr!, surah);
        final parts = key.split(':');
        if (parts.length != 2) continue;
        final s = int.tryParse(parts[0]) ?? surah;
        final a = int.tryParse(parts[1]) ?? 0;
        if (a == 0) continue;

        result.add(QVerse(
          verseKey: key,
          surah:    s,
          ayah:     a,
          ar:       row[_shapeAr!.textCol]?.toString() ?? '',
          fr:       frByKey[key] ?? '',
          tafsir:   null,
        ));
      }
    } else {
      // ── Mode legacy (DB combinée) ──
      final legacy = await _legacyPath();
      if (!await File(legacy).exists()) return [];

      final db   = await _openLegacy();
      final sh   = _shapeLegacy!;
      final rows = await _fetchAllSurahRows(db, sh, surah);

      result = [];
      for (final row in rows) {
        final key   = _rowVerseKey(row, sh, surah);
        final parts = key.split(':');
        if (parts.length != 2) continue;
        final s = (row['surah'] as num?)?.toInt() ?? int.tryParse(parts[0]) ?? surah;
        final a = (row['ayah']  as num?)?.toInt() ?? int.tryParse(parts[1]) ?? 0;
        if (a == 0) continue;

        result.add(QVerse(
          verseKey: key,
          surah:    s,
          ayah:     a,
          ar:       (row['ar'] ?? row[sh.textCol])?.toString() ?? '',
          fr:       row['fr']?.toString() ?? '',
          tafsir:   row['tafsir']?.toString(),
        ));
      }
    }

    // Garantir l'ordre croissant des versets.
    result.sort((a, b) => a.ayah.compareTo(b.ayah));
    _surahCache[surah] = result;
    return result;
  }

  // ── Lecture groupée par clés arbitraires ─────────────────────────────────
  //
  // Avant : N appels getVerseByKey() = N requêtes SQL.
  // Après : WHERE verse_key IN (...) ou WHERE surah=? AND ayah IN (...).

  Future<Map<String, QVerse>> getVersesByKeys(List<String> keys) async {
    if (keys.isEmpty) return {};

    final arPath = await _arPath();
    final frPath = await _frPath();
    final result = <String, QVerse>{};

    if (await File(arPath).exists() && await File(frPath).exists()) {
      // ── Mode split AR + FR ──
      final dbAr = await _openAr();
      final dbFr = await _openFr();

      final arMap = await _fetchRowsByKeys(dbAr, _shapeAr!, keys);
      final frMap = await _fetchRowsByKeys(dbFr, _shapeFr!, keys);

      for (final key in keys) {
        final arRow = arMap[key];
        if (arRow == null) continue;
        final parts = key.split(':');
        if (parts.length != 2) continue;
        final s = int.tryParse(parts[0]) ?? 0;
        final a = int.tryParse(parts[1]) ?? 0;

        result[key] = QVerse(
          verseKey: key,
          surah:    s,
          ayah:     a,
          ar:       arRow[_shapeAr!.textCol]?.toString() ?? '',
          fr:       frMap[key]?[_shapeFr!.textCol]?.toString() ?? '',
          tafsir:   null,
        );
      }
    } else {
      // ── Mode legacy ──
      final legacy = await _legacyPath();
      if (!await File(legacy).exists()) return {};

      final db     = await _openLegacy();
      final sh     = _shapeLegacy!;
      final rowMap = await _fetchRowsByKeys(db, sh, keys);

      for (final key in keys) {
        final row = rowMap[key];
        if (row == null) continue;
        final parts = key.split(':');
        if (parts.length != 2) continue;
        final s = (row['surah'] as num?)?.toInt() ?? int.tryParse(parts[0]) ?? 0;
        final a = (row['ayah']  as num?)?.toInt() ?? int.tryParse(parts[1]) ?? 0;

        result[key] = QVerse(
          verseKey: key,
          surah:    s,
          ayah:     a,
          ar:       (row['ar'] ?? row[sh.textCol])?.toString() ?? '',
          fr:       row['fr']?.toString() ?? '',
          tafsir:   row['tafsir']?.toString(),
        );
      }
    }

    return result;
  }

  Future<List<QVerse>> getRange(int surah, int fromAyah, int toAyah) async {
    final out = <QVerse>[];
    for (int ayah = fromAyah; ayah <= toAyah; ayah++) {
      final v = await getVerseByKey('$surah:$ayah');
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<void> close() async {
    _surahCache.clear();
    await _dbAr?.close();
    await _dbFr?.close();
    await _dbLegacy?.close();
    _dbAr      = null;
    _dbFr      = null;
    _dbLegacy  = null;
    _shapeAr   = null;
    _shapeFr   = null;
    _shapeLegacy = null;
  }

  // ── Helpers de lecture groupée ────────────────────────────────────────────

  /// Récupère toutes les lignes d'une sourate en **une seule requête SQL**,
  /// triées par numéro de verset croissant.
  Future<List<Map<String, Object?>>> _fetchAllSurahRows(
      Database db, _DbShape sh, int surah) async {
    if (sh.verseKeyCol != null) {
      // DB avec colonne verse_key : filtre sur le préfixe 'S:'.
      final rows = await db.rawQuery(
        'SELECT * FROM "${sh.table}" WHERE "${sh.verseKeyCol}" LIKE ?',
        ['$surah:%'],
      );
      // SQLite compare les verse_keys en ordre lexicographique ('2:9' > '2:10'),
      // donc on trie en Dart sur la valeur numérique de l'ayah.
      final sorted = List<Map<String, Object?>>.from(rows);
      sorted.sort((a, b) => _ayahFromKey(a[sh.verseKeyCol] as String? ?? '')
          .compareTo(_ayahFromKey(b[sh.verseKeyCol] as String? ?? '')));
      return sorted;
    } else {
      // DB avec colonnes surah + ayah : tri natif par la DB.
      return db.query(sh.table,
          where: 'surah = ?', whereArgs: [surah], orderBy: 'ayah ASC');
    }
  }

  /// Récupère les lignes pour une liste arbitraire de verse_keys en un minimum
  /// de requêtes SQL. Retourne une Map verse_key → row.
  Future<Map<String, Map<String, Object?>>> _fetchRowsByKeys(
      Database db, _DbShape sh, List<String> keys) async {
    final result = <String, Map<String, Object?>>{};

    if (sh.verseKeyCol != null) {
      // WHERE verse_key IN (?, ?, ...) — une seule requête pour toutes les clés.
      final placeholders = List.filled(keys.length, '?').join(', ');
      final rows = await db.rawQuery(
        'SELECT * FROM "${sh.table}" WHERE "${sh.verseKeyCol}" IN ($placeholders)',
        [...keys],
      );
      for (final row in rows) {
        final k = row[sh.verseKeyCol!]?.toString() ?? '';
        if (k.isNotEmpty) result[k] = row;
      }
    } else {
      // Pas de verse_key : grouper par sourate → WHERE surah=? AND ayah IN (...).
      final bySurah = <int, List<int>>{};
      for (final k in keys) {
        final parts = k.split(':');
        if (parts.length != 2) continue;
        final s = int.tryParse(parts[0]);
        final a = int.tryParse(parts[1]);
        if (s == null || a == null) continue;
        bySurah.putIfAbsent(s, () => []).add(a);
      }

      for (final entry in bySurah.entries) {
        final s     = entry.key;
        final ayahs = entry.value;
        final ph    = List.filled(ayahs.length, '?').join(', ');
        final rows  = await db.rawQuery(
          'SELECT * FROM "${sh.table}" WHERE surah = ? AND ayah IN ($ph)',
          [s, ...ayahs],
        );
        for (final row in rows) {
          final a = (row['ayah'] as num?)?.toInt() ?? 0;
          if (a > 0) result['$s:$a'] = row;
        }
      }
    }

    return result;
  }

  /// Extrait le numéro d'ayah depuis une verse_key "S:A".
  int _ayahFromKey(String key) {
    final idx = key.indexOf(':');
    if (idx < 0 || idx == key.length - 1) return 0;
    return int.tryParse(key.substring(idx + 1)) ?? 0;
  }

  /// Reconstruit la verse_key d'une row quelle que soit la structure du schéma.
  String _rowVerseKey(Map<String, Object?> row, _DbShape sh, int fallbackSurah) {
    if (sh.verseKeyCol != null) {
      return row[sh.verseKeyCol!]?.toString() ?? '';
    }
    final s = (row['surah'] as num?)?.toInt() ?? fallbackSurah;
    final a = (row['ayah']  as num?)?.toInt() ?? 0;
    return '$s:$a';
  }

  // ── Helpers de schéma (inchangés) ────────────────────────────────────────

  Future<_DbShape> _inspect(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );

    for (final t in tables) {
      final name     = t['name'] as String;
      final cols     = await db.rawQuery("PRAGMA table_info('$name')");
      final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();

      if (colNames.contains('verse_key')) {
        final textCol = _pickTextCol(colNames);
        if (textCol != null) {
          return _DbShape(table: name, verseKeyCol: 'verse_key', textCol: textCol);
        }
      }
    }

    for (final t in tables) {
      final name     = t['name'] as String;
      final cols     = await db.rawQuery("PRAGMA table_info('$name')");
      final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();

      if (colNames.contains('surah') && colNames.contains('ayah')) {
        final textCol = _pickTextCol(colNames);
        if (textCol != null) {
          return _DbShape(table: name, verseKeyCol: null, textCol: textCol);
        }
      }
    }

    final fallback = tables.isNotEmpty ? (tables.first['name'] as String) : 'verses';
    final cols     = await db.rawQuery("PRAGMA table_info('$fallback')");
    final colNames = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();
    return _DbShape(
      table:        fallback,
      verseKeyCol:  colNames.contains('verse_key') ? 'verse_key' : null,
      textCol:      _pickTextCol(colNames) ?? 'text',
    );
  }

  String? _pickTextCol(Set<String> cols) {
    const candidates = [
      'text', 'value', 'content', 'arabic_text', 'translation',
      'text_uthmani', 'text_uthmani_simple',
    ];
    for (final c in candidates) {
      if (cols.contains(c)) return c;
    }
    return null;
  }

  Future<String?> _getTextByVerseKey(
      Database db, _DbShape sh, String verseKey) async {
    final row = await _getRowByVerseKey(db, sh, verseKey);
    if (row == null) return null;
    final v = row[sh.textCol];
    return v is String ? v : v?.toString();
  }

  Future<Map<String, Object?>?> _getRowByVerseKey(
      Database db, _DbShape sh, String verseKey) async {
    if (sh.verseKeyCol != null) {
      final rows = await db.query(sh.table,
          where: '${sh.verseKeyCol} = ?', whereArgs: [verseKey], limit: 1);
      return rows.isEmpty ? null : rows.first;
    }

    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1]);
    if (s == null || a == null) return null;

    final rows = await db.query(sh.table,
        where: 'surah = ? AND ayah = ?', whereArgs: [s, a], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}

// ── Schéma DB ─────────────────────────────────────────────────────────────────

class _DbShape {
  final String  table;
  final String? verseKeyCol;
  final String  textCol;

  _DbShape({
    required this.table,
    required this.verseKeyCol,
    required this.textCol,
  });
}

// ── Modèle verset ─────────────────────────────────────────────────────────────

class QVerse {
  final String  verseKey;
  final int     surah;
  final int     ayah;
  final String  ar;
  final String  fr;
  final String? tafsir;

  QVerse({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.ar,
    required this.fr,
    required this.tafsir,
  });

  /// Construit un QVerse depuis une Map SQLite de manière null-safe.
  factory QVerse.fromMap(Map<String, Object?> m) {
    return QVerse(
      verseKey: m['verse_key']?.toString()         ?? '',
      surah:    (m['surah']    as num?)?.toInt()   ?? 0,
      ayah:     (m['ayah']     as num?)?.toInt()   ?? 0,
      ar:       m['ar']?.toString()                ?? '',
      fr:       m['fr']?.toString()                ?? '',
      tafsir:   m['tafsir']?.toString(),
    );
  }
}
