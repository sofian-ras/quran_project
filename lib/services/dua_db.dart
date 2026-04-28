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
      version: 4,
      onCreate: (d, v) async {
        await _createTables(d);
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 4) {
          await d.execute('DROP TABLE IF EXISTS duas');
          await d.execute('DROP TABLE IF EXISTS categories');
          await _createTables(d);
        }
      },
    );

    return _db!;
  }

  Future<void> _createTables(Database d) async {
    await d.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        title_fr TEXT NOT NULL,
        title_en TEXT NOT NULL,
        title_ar TEXT NOT NULL DEFAULT '',
        order_index INTEGER NOT NULL,
        dua_count INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await d.execute('''
      CREATE TABLE duas (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title_fr TEXT NOT NULL DEFAULT '',
        ar TEXT NOT NULL DEFAULT '',
        fr TEXT NOT NULL DEFAULT '',
        en TEXT NOT NULL DEFAULT '',
        phonetic TEXT NOT NULL DEFAULT '',
        explanation TEXT NOT NULL DEFAULT '',
        repeat_count INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT '',
        audio_url TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
  }

  Future<void> importFromAssetsIfEmpty() async {
    final d = await db;

    final count = Sqflite.firstIntValue(
          await d.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;

    if (count > 0) return;

    final raw0 = await rootBundle.loadString('assets/data/hisn_almuslim.json');
    final raw = raw0.startsWith('﻿') ? raw0.substring(1) : raw0;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = (map['chapters'] as List).cast<Map<String, dynamic>>();

    await d.transaction((txn) async {
      for (final chapter in chapters) {
        final chapterId = chapter['id'] as int;
        final catId = 'c$chapterId';
        final titleFr = (chapter['title_fr'] as String?) ?? '';
        final titleEn = (chapter['title_en'] as String?) ?? '';
        final duas = (chapter['duas'] as List).cast<Map<String, dynamic>>();

        await txn.insert('categories', {
          'id': catId,
          'title_fr': titleFr,
          'title_en': titleEn,
          'title_ar': '',
          'order_index': chapterId,
          'dua_count': duas.length,
        });

        for (final dua in duas) {
          final duaId = dua['id'] as int;
          final audioObj = dua['audio'] as Map<String, dynamic>?;
          final audioUrl = (audioObj?['arabic_recitation'] as String?) ?? '';

          await txn.insert('duas', {
            'id': 'c${chapterId}_d$duaId',
            'category_id': catId,
            'title_fr': (dua['title_fr'] as String?) ?? '',
            'ar': (dua['arabic'] as String?) ?? '',
            'fr': (dua['french'] as String?) ?? '',
            'en': (dua['english'] as String?) ?? '',
            'phonetic': (dua['phonetic'] as String?) ?? '',
            'explanation': (dua['explanation'] as String?) ?? '',
            'repeat_count': (dua['repeat'] as int?) ?? 1,
            'source': (dua['source'] as String?) ?? '',
            'audio_url': audioUrl,
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
      return d.query('duas', where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'id ASC');
    }

    final q = '%${query.trim()}%';
    return d.query(
      'duas',
      where: '''
        category_id = ?
        AND (ar LIKE ? OR fr LIKE ? OR en LIKE ? OR phonetic LIKE ? OR title_fr LIKE ?)
      ''',
      whereArgs: [categoryId, q, q, q, q, q],
    );
  }

  Future<List<Map<String, Object?>>> searchDuas(String query) async {
    if (query.trim().isEmpty) return [];
    final d = await db;
    final q = '%${query.trim()}%';
    return d.rawQuery('''
      SELECT d.*, c.title_fr as cat_title_fr, c.id as cat_id
      FROM duas d
      JOIN categories c ON c.id = d.category_id
      WHERE d.ar LIKE ? OR d.fr LIKE ? OR d.phonetic LIKE ? OR d.title_fr LIKE ?
      LIMIT 100
    ''', [q, q, q, q]);
  }

  Future<List<Map<String, Object?>>> getCategoriesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final d = await db;
    final placeholders = ids.map((_) => '?').join(',');
    return d.rawQuery(
      'SELECT * FROM categories WHERE id IN ($placeholders) ORDER BY order_index ASC',
      ids,
    );
  }

  Future<void> reset() async {
    final path = join(await getDatabasesPath(), 'dua.db');
    await deleteDatabase(path);
    _db = null;
  }
}
