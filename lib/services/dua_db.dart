import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DuaDb {
  static final DuaDb instance = DuaDb._();
  DuaDb._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final path = join(await getDatabasesPath(), 'dua.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            title_ar TEXT NOT NULL,
            title_fr TEXT NOT NULL,
            title_en TEXT NOT NULL,
            order_index INTEGER NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE duas (
            id TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            title_ar TEXT NOT NULL,
            title_fr TEXT NOT NULL,
            title_en TEXT NOT NULL,
            ar TEXT NOT NULL,
            fr TEXT NOT NULL,
            en TEXT NOT NULL,
            repeat_count INTEGER NOT NULL,
            source TEXT NOT NULL,
            FOREIGN KEY(category_id) REFERENCES categories(id)
          );
        ''');
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          // Ajout colonnes EN (fallback), sans casser ton modèle actuel
          await d.execute("ALTER TABLE categories ADD COLUMN title_en TEXT NOT NULL DEFAULT '';");
          await d.execute("ALTER TABLE duas ADD COLUMN title_en TEXT NOT NULL DEFAULT '';");
          await d.execute("ALTER TABLE duas ADD COLUMN en TEXT NOT NULL DEFAULT '';");
        }
      },
    );

    return _db!;
  }

  Future<void> importFromAssetsIfEmpty() async {
    final d = await db;

    final count = Sqflite.firstIntValue(
          await d.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;

    if (count > 0) return;

    // IMPORTANT: fichier Hisn Al-Muslim (ar + en)
    final raw0 = await rootBundle.loadString('assets/data/husn_en.json');

    // Au cas où BOM (UTF-8) au début du fichier
    final raw = raw0.startsWith('\uFEFF') ? raw0.substring(1) : raw0;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final doors = (map['English'] as List).cast<Map<String, dynamic>>();

    await d.transaction((txn) async {
      for (final door in doors) {
        final catId = (door['ID']).toString();
        final titleEn = (door['TITLE'] ?? '').toString();
        final orderIndex = (door['ID'] is int) ? (door['ID'] as int) : 9999;

        // Category
        await txn.insert('categories', {
          'id': catId,
          'title_ar': '',
          'title_fr': '',
          'title_en': titleEn,
          'order_index': orderIndex,
        });

        // Items
        final textList = (door['TEXT'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        for (final it in textList) {
          final duaId = (it['ID']).toString();

          final ar = (it['ARABIC_TEXT'] ?? '').toString();
          final en = (it['TRANSLATED_TEXT'] ?? '').toString();
          final repeat = (it['REPEAT'] is int) ? (it['REPEAT'] as int) : 1;

          // Audio (si tu veux le garder quelque part)
          final audio = (it['AUDIO'] ?? '').toString();

          await txn.insert('duas', {
            'id': duaId,
            'category_id': catId,

            // Pas de titre par dua dans ce dataset -> on laisse vide
            'title_ar': '',
            'title_fr': '',
            'title_en': '',

            'ar': ar,
            'fr': '',      // futur: ta traduction FR
            'en': en,      // fallback pour l’UI

            'repeat_count': repeat,
            'source': audio,
          });
        }
      }
    });
  }

  Future<List<Map<String, Object?>>> getCategories() async {
    final d = await db;
    return d.query('categories', orderBy: 'order_index ASC');
  }

  Future<List<Map<String, Object?>>> getDuasByCategory(
    String categoryId, {
    String query = '',
  }) async {
    final d = await db;

    if (query.trim().isEmpty) {
      return d.query('duas', where: 'category_id = ?', whereArgs: [categoryId]);
    }

    final q = '%${query.trim()}%';
    return d.query(
      'duas',
      where: '''
        category_id = ?
        AND (
          ar LIKE ? OR fr LIKE ? OR en LIKE ?
          OR title_ar LIKE ? OR title_fr LIKE ? OR title_en LIKE ?
        )
      ''',
      whereArgs: [categoryId, q, q, q, q, q, q],
    );
  }

  Future<void> reset() async {
    final path = join(await getDatabasesPath(), 'dua.db');
    await deleteDatabase(path);
    _db = null;
  }
}