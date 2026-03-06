import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Accès à la base de données bundlée quran-metadata-ayah.sqlite.
/// Contient le texte arabe de tous les 6236 versets (surah_number, ayah_number,
/// verse_key au format "S:A", text).
/// La DB est copiée une seule fois depuis assets vers le répertoire documents
/// pour que sqflite puisse l'ouvrir comme un fichier normal.
class QuranAyahMetadataDb {
  static final QuranAyahMetadataDb instance = QuranAyahMetadataDb._();
  QuranAyahMetadataDb._();

  Database? _db;

  static const String _assetPath = 'assets/data/quran-metadata-ayah.sqlite';
  static const String _fileName  = 'quran_metadata_ayah.sqlite';

  Future<String> _dbPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'qul', _fileName);
  }

  Future<Database> _open() async {
    if (_db != null) return _db!;

    final dbPath = await _dbPath();

    if (!await File(dbPath).exists()) {
      final dir = Directory(p.dirname(dbPath));
      if (!await dir.exists()) await dir.create(recursive: true);
      final bytes = await rootBundle.load(_assetPath);
      await File(dbPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  /// Retourne le texte arabe d'un seul verset, ou null s'il n'existe pas.
  Future<String?> getVerseText(int surah, int ayah) async {
    final db = await _open();
    final rows = await db.query(
      'verses',
      columns: ['text'],
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final text = rows.first['text'] as String?;
    return (text != null && text.isNotEmpty) ? text : null;
  }

  /// Retourne une map verse_key → texte arabe pour toute une sourate.
  Future<Map<String, String>> getSurahTexts(int surah) async {
    final db = await _open();
    final rows = await db.query(
      'verses',
      columns: ['verse_key', 'text'],
      where: 'surah_number = ?',
      whereArgs: [surah],
      orderBy: 'ayah_number ASC',
    );
    final result = <String, String>{};
    for (final r in rows) {
      final key  = r['verse_key'] as String?;
      final text = r['text'] as String?;
      if (key != null && text != null && text.isNotEmpty) {
        result[key] = text;
      }
    }
    return result;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
