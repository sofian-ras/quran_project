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
  final String nameFr; // translitération / titre français
  final String authorAr;
  final String descFr;
  final List<Color> gradient;

  const TafsirBook({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameFr,
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
      id: 14,
      slug: 'ibn_kathir',
      nameAr: 'تفسير ابن كثير',
      nameFr: 'Tafsir Ibn Kathir',
      authorAr: 'ابن كثير الدمشقي',
      descFr: 'Le plus célèbre des tafsirs, commentaire exhaustif du Coran',
      gradient: [Color(0xFF0D3B2E), Color(0xFF1A5C42)],
    ),
    TafsirBook(
      id: 16,
      slug: 'muyassar',
      nameAr: 'التفسير الميسر',
      nameFr: 'At-Tafsir Al-Muyassar',
      authorAr: 'مجمع الملك فهد',
      descFr: 'Tafsir simplifié du complexe du Roi Fahd',
      gradient: [Color(0xFF4A2800), Color(0xFF7A4800)],
    ),
    TafsirBook(
      id: 91,
      slug: 'saadi',
      nameAr: 'تفسير السعدي',
      nameFr: "Tafsir As-Sa'di",
      authorAr: 'عبد الرحمن السعدي',
      descFr: "Tafsir clair et bénéfique du Sheikh Al-Sa'di",
      gradient: [Color(0xFF0A1A30), Color(0xFF1A3A60)],
    ),
    TafsirBook(
      id: 15,
      slug: 'tabari',
      nameAr: 'تفسير الطبري',
      nameFr: 'Tafsir At-Tabari',
      authorAr: 'ابن جرير الطبري',
      descFr: "Fondement de l'exégèse coranique, source des sources",
      gradient: [Color(0xFF3B0A18), Color(0xFF6B1A32)],
    ),
    TafsirBook(
      id: 90,
      slug: 'qurtubi',
      nameAr: 'تفسير القرطبي',
      nameFr: 'Tafsir Al-Qurtubi',
      authorAr: 'محمد القرطبي',
      descFr: "Tafsir encyclopédique de l'imam Al-Qurtubi",
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
        final resp = await dio.get(
          url,
          queryParameters: {'per_page': 300},
          cancelToken: cancelToken,
        );

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
                // Ré-applique le nettoyage pour corriger les données stockées
                // avant le fix deux-passes (entités HTML encodées).
                text: _stripHtml(r['text'] as String),
              ))
          .toList();
    } finally {
      await db.close();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Nettoie le HTML en deux passes :
  ///   Passe 1 : supprime les balises HTML réelles (<rulee class="...">…</rulee>)
  ///   Décodage : transforme les entités (&lt; → <, &amp; → & …)
  ///   Passe 2 : supprime les balises qui étaient HTML-encodées (&lt;rulee…&gt;)
  /// Cela garantit que les classes CSS comme "madda_normal" n'apparaissent pas
  /// dans le texte final, qu'elles soient encodées ou non par l'API.
  static String _stripHtml(String html) {
    // Passe 1 : balises réelles
    var text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // Décodage des entités HTML
    text = text
        .replaceAll('&nbsp;', '\u00A0')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'&#(\d+);'), '');
    // Passe 2 : balises issues du décodage (ex-encodées)
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return text
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── Verse counts ─────────────────────────────────────────────────────────────

  /// Nombre de versets par sourate (index 0 = sourate 1).
  static const List<int> surahAyahCounts = [
    7,   286, 200, 176, 120, 165, 206, 75,  129, 109,
    123, 111, 43,  52,  99,  128, 111, 110, 98,  135,
    112, 78,  118, 64,  77,  227, 93,  88,  69,  60,
    34,  30,  73,  54,  45,  83,  182, 88,  75,  85,
    54,  53,  89,  59,  37,  35,  38,  29,  18,  45,
    60,  49,  62,  55,  78,  96,  29,  22,  24,  13,
    14,  11,  11,  18,  12,  12,  30,  52,  52,  44,
    28,  28,  20,  56,  40,  31,  50,  40,  46,  42,
    29,  19,  36,  25,  22,  17,  19,  26,  30,  20,
    15,  21,  11,  8,   8,   19,  5,   8,   8,   11,
    11,  8,   3,   9,   5,   4,   7,   3,   6,   3,
    5,   4,   5,   6,
  ];

  // ── Surah names (Arabic) ──────────────────────────────────────────────────────

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
