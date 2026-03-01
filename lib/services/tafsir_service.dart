import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class TafsirBook {
  final int id;        // quran.com tafsir resource ID
  final String slug;   // used for file naming
  final String nameAr;
  final String authorAr;
  final String descFr;
  final List<Color> gradient;

  const TafsirBook({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.authorAr,
    required this.descFr,
    required this.gradient,
  });

  String get dbFileName => 'tafsir_$slug.sqlite';
}

class TafsirVerse {
  final String verseKey;
  final int surah;
  final int ayah;
  final String text;
  const TafsirVerse({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.text,
  });
}

// ── Catalog ───────────────────────────────────────────────────────────────────

class TafsirService {
  static const String _base = 'https://api.quran.com/api/v4';

  static const List<TafsirBook> catalog = [
    TafsirBook(
      id: 169,
      slug: 'ibn_kathir',
      nameAr: 'تفسير ابن كثير',
      authorAr: 'ابن كثير الدمشقي',
      descFr: 'Le plus célèbre des tafsirs, commentaire exhaustif du Coran',
      gradient: [Color(0xFF0D3B2E), Color(0xFF1A5C42)],
    ),
    TafsirBook(
      id: 16,
      slug: 'muyassar',
      nameAr: 'التفسير الميسر',
      authorAr: 'مجمع الملك فهد',
      descFr: 'Tafsir simplifié du complexe du Roi Fahd',
      gradient: [Color(0xFF4A2800), Color(0xFF7A4800)],
    ),
    TafsirBook(
      id: 93,
      slug: 'saadi',
      nameAr: 'تفسير السعدي',
      authorAr: 'عبد الرحمن السعدي',
      descFr: 'Tafsir clair et bénéfique du Sheikh Al-Sa\'di',
      gradient: [Color(0xFF0A1A30), Color(0xFF1A3A60)],
    ),
    TafsirBook(
      id: 74,
      slug: 'jalalayn',
      nameAr: 'تفسير الجلالين',
      authorAr: 'السيوطي والمحلي',
      descFr: 'Commentaire concis des deux Jalal',
      gradient: [Color(0xFF3B0A18), Color(0xFF6B1A32)],
    ),
    TafsirBook(
      id: 90,
      slug: 'qurtubi',
      nameAr: 'تفسير القرطبي',
      authorAr: 'محمد القرطبي',
      descFr: 'Tafsir encyclopédique de l\'imam Al-Qurtubi',
      gradient: [Color(0xFF1A1A00), Color(0xFF3A3A00)],
    ),
  ];

  // ── Storage ─────────────────────────────────────────────────────────────────

  static Future<String> _dbPath(TafsirBook book) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = p.join(docs.path, 'qul', 'tafsir');
    await Directory(dir).create(recursive: true);
    return p.join(dir, book.dbFileName);
  }

  static Future<bool> isDownloaded(TafsirBook book) async {
    final path = await _dbPath(book);
    return File(path).exists();
  }

  static Future<void> deleteBook(TafsirBook book) async {
    final path = await _dbPath(book);
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  // ── Download ─────────────────────────────────────────────────────────────────

  static Future<void> download(
    TafsirBook book, {
    required void Function(double progress, int surah) onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await _dbPath(book);
    final tmpPath = '$path.part';

    // Remove stale temp file if exists
    final tmp = File(tmpPath);
    if (await tmp.exists()) await tmp.delete();

    final db = await openDatabase(
      tmpPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE verses (
            verse_key TEXT PRIMARY KEY,
            surah     INTEGER NOT NULL,
            ayah      INTEGER NOT NULL,
            text      TEXT    NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_surah ON verses(surah, ayah)');
      },
    );

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    try {
      for (int surah = 1; surah <= 114; surah++) {
        if (cancelToken?.isCancelled ?? false) {
          throw DioException.requestCancelled(
              requestOptions: RequestOptions(), reason: 'cancelled');
        }

        final url = '$_base/tafsirs/${book.id}/by_chapter/$surah';
        final resp = await dio.get(url, cancelToken: cancelToken);

        final data = resp.data as Map<String, dynamic>;
        final list = (data['tafsirs'] as List?) ?? [];

        final batch = db.batch();
        for (final t in list) {
          final vk = (t['verse_key'] as String?) ?? '';
          final parts = vk.split(':');
          final s = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? surah;
          final a = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
          final raw = (t['text'] as String?) ?? '';
          batch.insert(
            'verses',
            {
              'verse_key': vk,
              'surah': s,
              'ayah': a,
              'text': _stripHtml(raw),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        onProgress(surah / 114, surah);

        // Polite delay to respect rate limits
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      await db.close();
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }

    await db.close();

    // Atomic rename
    final out = File(path);
    if (await out.exists()) await out.delete();
    await File(tmpPath).rename(path);
  }

  // ── Reading ──────────────────────────────────────────────────────────────────

  static Future<List<TafsirVerse>> getSurah(TafsirBook book, int surah) async {
    final path = await _dbPath(book);
    final db = await openDatabase(path, readOnly: true);
    try {
      final rows = await db.query(
        'verses',
        where: 'surah = ?',
        whereArgs: [surah],
        orderBy: 'ayah ASC',
      );
      return rows
          .map((r) => TafsirVerse(
                verseKey: r['verse_key'] as String,
                surah: r['surah'] as int,
                ayah: r['ayah'] as int,
                text: r['text'] as String,
              ))
          .toList();
    } finally {
      await db.close();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', '\u00A0')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── Surah names ──────────────────────────────────────────────────────────────

  static const List<String> surahNames = [
    'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
    'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
    'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
    'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
    'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
    'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
    'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
    'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
    'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
    'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
    'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
    'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
    'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
    'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
    'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
    'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
    'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
    'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
    'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
    'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
    'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
    'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];
}
