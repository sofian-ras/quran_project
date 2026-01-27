import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class QuranTextDb {
  static final QuranTextDb instance = QuranTextDb._();
  QuranTextDb._();

  Database? _db;

  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'quran_text', 'fr', 'quran_text_fr.sqlite');
  }

  Future<bool> isReady() async {
    final path = await _dbPath();
    return File(path).exists();
  }

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = await _dbPath();
    _db = await openDatabase(path, readOnly: true);
    return _db!;
  }

  Future<QVerse?> getVerseByKey(String verseKey) async {
    final db = await _open();
    final rows = await db.query(
      'verses',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return QVerse.fromMap(rows.first);
  }

  Future<List<QVerse>> getSurah(int surah) async {
    final db = await _open();
    final rows = await db.query(
      'verses',
      where: 'surah = ?',
      whereArgs: [surah],
      orderBy: 'ayah ASC',
    );
    return rows.map(QVerse.fromMap).toList();
  }

  Future<List<QVerse>> getRange(int surah, int fromAyah, int toAyah) async {
    final db = await _open();
    final rows = await db.query(
      'verses',
      where: 'surah = ? AND ayah >= ? AND ayah <= ?',
      whereArgs: [surah, fromAyah, toAyah],
      orderBy: 'ayah ASC',
    );
    return rows.map(QVerse.fromMap).toList();
  }

  Future<Map<String, QVerse>> getVersesByKeys(List<String> keys) async {
    if (keys.isEmpty) return {};
    final db = await _open();

    // IN (?, ?, ?, ...) : 30 keys max ici (Juz), OK.
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT verse_key, surah, ayah, ar, fr, tafsir FROM verses WHERE verse_key IN ($placeholders)',
      keys,
    );

    final map = <String, QVerse>{};
    for (final r in rows) {
      final v = QVerse.fromMap(r);
      map[v.verseKey] = v;
    }
    return map;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
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
