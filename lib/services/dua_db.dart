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
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            title_ar TEXT NOT NULL,
            title_fr TEXT NOT NULL,
            order_index INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE duas (
            id TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            title_ar TEXT NOT NULL,
            title_fr TEXT NOT NULL,
            ar TEXT NOT NULL,
            fr TEXT NOT NULL,
            repeat_count INTEGER NOT NULL,
            source TEXT NOT NULL,
            FOREIGN KEY(category_id) REFERENCES categories(id)
          );
        ''');
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

    final raw = await rootBundle.loadString('assets/data/dua_pack_v1.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final cats = (map['categories'] as List).cast<Map<String, dynamic>>();
    final items = (map['items'] as List).cast<Map<String, dynamic>>();

    await d.transaction((txn) async {
      // Categories
      for (final c in cats) {
        final title = (c['title'] as Map?)?.cast<String, dynamic>() ?? {};
        await txn.insert('categories', {
          'id': c['id'] as String,
          'title_ar': (title['ar'] ?? '') as String,
          'title_fr': (title['fr'] ?? '') as String,
          'order_index': (c['order'] ?? 9999) as int,
        });
      }

      // Duas
      for (final it in items) {
        final t = (it['title'] as Map?)?.cast<String, dynamic>() ?? {};
        final text = (it['text'] as Map?)?.cast<String, dynamic>() ?? {};
        final repeat = (it['repeat'] as Map?)?.cast<String, dynamic>() ?? {};
        final source = (it['source'] as Map?)?.cast<String, dynamic>() ?? {};

        await txn.insert('duas', {
          'id': it['id'] as String,
          'category_id': it['categoryId'] as String,
          'title_ar': (t['ar'] ?? '') as String,
          'title_fr': (t['fr'] ?? '') as String,
          'ar': (text['ar'] ?? '') as String,
          'fr': (text['fr'] ?? '') as String,
          'repeat_count': (repeat['count'] ?? 1) as int,
          'source': (source['ref'] ?? '') as String,
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> getCategories() async {
    final d = await db;
    return d.query('categories', orderBy: 'order_index ASC');
  }

  Future<List<Map<String, Object?>>> getDuasByCategory(String categoryId, {String query = ''}) async {
    final d = await db;
    if (query.trim().isEmpty) {
      return d.query('duas', where: 'category_id = ?', whereArgs: [categoryId]);
    }
    final q = '%${query.trim()}%';
    return d.query(
      'duas',
      where: 'category_id = ? AND (ar LIKE ? OR fr LIKE ? OR title_ar LIKE ? OR title_fr LIKE ?)',
      whereArgs: [categoryId, q, q, q, q],
    );
  }
    Future<void> reset() async {
      final path = join(await getDatabasesPath(), 'dua.db');
      await deleteDatabase(path);
      _db = null;
    }
}