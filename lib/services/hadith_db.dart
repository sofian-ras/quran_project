import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/hadith.dart';

class HadithDb {
  static final HadithDb instance = HadithDb._();
  HadithDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'hadiths.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE hadiths (
            id           INTEGER PRIMARY KEY,
            arabic       TEXT NOT NULL,
            category_id  TEXT NOT NULL DEFAULT '',
            category_name TEXT NOT NULL DEFAULT ''
          );
        ''');
        await d.execute('''
          CREATE TABLE hadith_translations (
            hadith_id   INTEGER NOT NULL,
            lang        TEXT NOT NULL,
            title       TEXT,
            translation TEXT NOT NULL,
            explanation TEXT,
            PRIMARY KEY (hadith_id, lang),
            FOREIGN KEY (hadith_id) REFERENCES hadiths(id)
          );
        ''');
        await d.execute('CREATE INDEX idx_ht_lang ON hadith_translations(lang);');
        await d.execute('CREATE INDEX idx_ht_search ON hadith_translations(translation);');
        await d.execute('CREATE INDEX idx_h_cat ON hadiths(category_id);');
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Clear and recreate so importFromAssetsIfNeeded repopulates with category data
          await d.execute('DROP TABLE IF EXISTS hadith_translations');
          await d.execute('DROP TABLE IF EXISTS hadiths');
          await d.execute('''
            CREATE TABLE hadiths (
              id           INTEGER PRIMARY KEY,
              arabic       TEXT NOT NULL,
              category_id  TEXT NOT NULL DEFAULT '',
              category_name TEXT NOT NULL DEFAULT ''
            );
          ''');
          await d.execute('''
            CREATE TABLE hadith_translations (
              hadith_id   INTEGER NOT NULL,
              lang        TEXT NOT NULL,
              title       TEXT,
              translation TEXT NOT NULL,
              explanation TEXT,
              PRIMARY KEY (hadith_id, lang),
              FOREIGN KEY (hadith_id) REFERENCES hadiths(id)
            );
          ''');
          await d.execute('CREATE INDEX idx_ht_lang ON hadith_translations(lang);');
          await d.execute('CREATE INDEX idx_ht_search ON hadith_translations(translation);');
          await d.execute('CREATE INDEX idx_h_cat ON hadiths(category_id);');
        }
      },
    );
    return _db!;
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  Future<void> importFromAssetsIfNeeded({String lang = 'fr'}) async {
    final d = await db;

    final count = Sqflite.firstIntValue(
          await d.rawQuery(
            'SELECT COUNT(*) FROM hadith_translations WHERE lang = ?',
            [lang],
          ),
        ) ??
        0;

    if (count > 0) return;

    final assetPath = 'assets/data/hadiths_$lang.json';
    final raw0 = await rootBundle.loadString(assetPath);
    final raw = raw0.startsWith('\uFEFF') ? raw0.substring(1) : raw0;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    await d.transaction((txn) async {
      for (final item in list) {
        final id = (item['id'] as num).toInt();
        final arabic = (item['arabic'] as String?) ?? '';
        final translation = (item[lang] as String?) ?? (item['french'] as String?) ?? '';
        final title = (item['title'] as String?) ?? '';
        final explanation = (item['explanation'] as String?) ?? '';
        final categoryId = (item['category_id'] as String?) ?? '';
        final categoryName = (item['category_name'] as String?) ?? '';

        await txn.insert(
          'hadiths',
          {
            'id': id,
            'arabic': arabic,
            'category_id': categoryId,
            'category_name': categoryName,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.insert(
          'hadith_translations',
          {
            'hadith_id': id,
            'lang': lang,
            'title': title,
            'translation': translation,
            'explanation': explanation,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  Future<int> getTotalCount({String lang = 'fr'}) async {
    final d = await db;
    return Sqflite.firstIntValue(
          await d.rawQuery(
            'SELECT COUNT(*) FROM hadith_translations WHERE lang = ?',
            [lang],
          ),
        ) ??
        0;
  }

  /// Returns distinct categories as list of {category_id, category_name, count}
  Future<List<Map<String, dynamic>>> getCategories({String lang = 'fr'}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.category_id, h.category_name, COUNT(*) as count
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      WHERE h.category_id != ''
      GROUP BY h.category_id
      ORDER BY count DESC
    ''', [lang]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Hadith?> getHadithOfDay({String lang = 'fr'}) async {
    final total = await getTotalCount(lang: lang);
    if (total == 0) return null;

    final epochDays = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final offset = epochDays % total;

    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      LIMIT 1 OFFSET ?
    ''', [lang, offset]);

    if (rows.isEmpty) return null;
    return Hadith.fromMap(rows.first);
  }

  Future<Hadith?> getRandomHadith({String lang = 'fr'}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      ORDER BY RANDOM()
      LIMIT 1
    ''', [lang]);

    if (rows.isEmpty) return null;
    return Hadith.fromMap(rows.first);
  }

  Future<Hadith?> getHadithById(int id, {String lang = 'fr'}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      WHERE h.id = ?
      LIMIT 1
    ''', [lang, id]);

    if (rows.isEmpty) return null;
    return Hadith.fromMap(rows.first);
  }

  Future<List<Hadith>> getPage(int page, {int pageSize = 30, String lang = 'fr'}) async {
    final d = await db;
    final offset = page * pageSize;
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      ORDER BY h.id ASC
      LIMIT ? OFFSET ?
    ''', [lang, pageSize, offset]);

    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  Future<List<Hadith>> getByCategory(
    String categoryId, {
    int page = 0,
    int pageSize = 30,
    String lang = 'fr',
  }) async {
    final d = await db;
    final offset = page * pageSize;
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      WHERE h.category_id = ?
      ORDER BY h.id ASC
      LIMIT ? OFFSET ?
    ''', [lang, categoryId, pageSize, offset]);

    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  Future<List<Hadith>> search(String query, {String lang = 'fr', int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    final d = await db;
    final q = '%${query.trim()}%';
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      WHERE t.translation LIKE ? OR t.title LIKE ?
      ORDER BY h.id ASC
      LIMIT ?
    ''', [lang, q, q, limit]);

    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  Future<List<Hadith>> getFavoriteHadiths(List<int> ids, {String lang = 'fr'}) async {
    if (ids.isEmpty) return [];
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await d.rawQuery('''
      SELECT h.id, h.arabic, h.category_id, h.category_name,
             t.title, t.translation, t.explanation
      FROM hadiths h
      JOIN hadith_translations t ON t.hadith_id = h.id AND t.lang = ?
      WHERE h.id IN ($placeholders)
      ORDER BY h.id ASC
    ''', [lang, ...ids]);

    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  Future<void> reset() async {
    final path = join(await getDatabasesPath(), 'hadiths.db');
    await deleteDatabase(path);
    _db = null;
  }
}
