import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AppLang { fr, en }

class QuranTranslationPackService {
  // URLs (GitHub Releases)
  static const String frDbUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/v1.0/quran_text_fr.sqlite';
  static const String enDbUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/v1.0/quran_text_en.sqlite';

  static const String _frDbName = 'quran_text_fr.sqlite';
  static const String _enDbName = 'quran_text_en.sqlite';

  static final Dio _dio = Dio();
  static bool _busy = false;

  static Future<String> _packDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'quran_translation');
  }

  static Future<String> getDbPath(AppLang lang) async {
    final base = await _packDir();
    final name = (lang == AppLang.fr) ? _frDbName : _enDbName;
    return p.join(base, name);
  }

  static Future<bool> isPackReady(AppLang lang) async {
    final path = await getDbPath(lang);
    return File(path).exists();
  }

  static Future<void> downloadPack(
    AppLang lang, {
    void Function(double progress01)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_busy) return;
    _busy = true;

    try {
      final base = await _packDir();
      await Directory(base).create(recursive: true);

      final dbPath = await getDbPath(lang);
      final tmpPath = '$dbPath.tmp';

      final url = (lang == AppLang.fr) ? frDbUrl : enDbUrl;

      await _dio.download(
        url,
        tmpPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          onProgress?.call((received / total).clamp(0.0, 1.0));
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      final tmp = File(tmpPath);
      final dest = File(dbPath);

      if (await dest.exists()) {
        await dest.delete();
      }
      await tmp.rename(dbPath);

      onProgress?.call(1.0);
    } finally {
      _busy = false;
    }
  }

  // --- Compat : pour ne pas casser ton code actuel ---
  static Future<bool> isFrenchPackReady() => isPackReady(AppLang.fr);
  static Future<void> downloadFrenchPack({void Function(double)? onProgress}) =>
      downloadPack(AppLang.fr, onProgress: onProgress);

  static Future<bool> isEnglishPackReady() => isPackReady(AppLang.en);
  static Future<void> downloadEnglishPack({void Function(double)? onProgress}) =>
      downloadPack(AppLang.en, onProgress: onProgress);
}
