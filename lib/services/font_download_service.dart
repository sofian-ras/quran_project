import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

/// Service pour le téléchargement et le chargement des polices QCF (Quranic Font Code).
class FontDownloadService {
  static const String zipUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/v1/quran_fonts.zip';
  static const String zipFileName = 'quran_fonts.zip';

  static String? _docsPath;
  static String? _fontsPath;
  static final Dio _dio = Dio();
  static bool _isDownloading = false;
  static bool _isExtracting = false;
  static double _downloadProgress = 0.0;
  static double _extractionProgress = 0.0;

  static final Set<String> _loadedFamilies = {};

  static Future<void> _ensurePaths() async {
    if (_docsPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _docsPath = dir.path;
    _fontsPath = p.join(_docsPath!, 'fonts');
  }

  static String _fontFileName(int page) =>
      'QCF_P${page.toString().padLeft(3, '0')}.TTF';

  /// Vérifie si les polices QCF sont déjà téléchargées.
  static Future<bool> areFontsDownloaded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontsPath = p.join(dir.path, 'fonts');
      final first = File(p.join(fontsPath, _fontFileName(0)));
      final last  = File(p.join(fontsPath, _fontFileName(604)));
      return await first.exists() && await last.exists();
    } catch (_) {
      return false;
    }
  }

  /// Télécharge et extrait le ZIP contenant les polices QCF.
  static Future<void> downloadAndExtractFonts({
    Function(double)? onDownloadProgress,
    Function(double)? onExtractionProgress,
  }) async {
    if (_isDownloading || _isExtracting) {
      debugPrint('Téléchargement/extraction des polices déjà en cours, attente...');
      while (_isDownloading || _isExtracting) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return;
    }

    if (await areFontsDownloaded()) {
      debugPrint('Polices déjà téléchargées');
      return;
    }

    try {
      await _ensurePaths();
      _isDownloading = true;
      final zipPath = p.join(_docsPath!, zipFileName);

      debugPrint('Début du téléchargement des polices depuis: $zipUrl');
      await _dio.download(
        zipUrl,
        zipPath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress = received / total;
            onDownloadProgress?.call(_downloadProgress);
          }
        },
      );

      _isDownloading = false;
      _isExtracting = true;
      _extractionProgress = 0.0;
      onExtractionProgress?.call(0.0);

      await _extractZipInIsolate(zipPath, _docsPath!);

      _extractionProgress = 1.0;
      onExtractionProgress?.call(1.0);
      _isExtracting = false;
      debugPrint('Extraction des polices terminée avec succès');

      final zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await zipFile.delete();
        debugPrint('ZIP polices supprimé');
      }
    } catch (e) {
      _isDownloading = false;
      _isExtracting = false;
      debugPrint('Erreur téléchargement/extraction polices: $e');
      rethrow;
    }
  }

  static Future<void> _extractZipInIsolate(
    String zipPath,
    String destinationPath,
  ) async {
    await compute(_extractZipTask, {
      'zipPath': zipPath,
      'destinationPath': destinationPath,
    });
  }

  static void _extractZipTask(Map<String, String> params) {
    final zipPath        = params['zipPath']!;
    final destinationPath = params['destinationPath']!;
    final fontsPath      = p.join(destinationPath, 'fonts');
    try {
      Directory(fontsPath).createSync(recursive: true);

      // Lecture en streaming — le ZIP n'est jamais chargé entièrement en RAM.
      final inputStream = InputFileStream(zipPath);
      final archive     = ZipDecoder().decodeStream(inputStream);

      int processed = 0;
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;
        if (name.contains('__MACOSX') ||
            name.startsWith('.') ||
            name.contains('/.')) {
          continue;
        }
        if (!name.toLowerCase().endsWith('.ttf')) continue;

        final outPath      = p.join(fontsPath, p.basename(name));
        final outputStream = OutputFileStream(outPath);
        file.writeContent(outputStream);
        outputStream.close();

        processed++;
        if (processed % 50 == 0) {
          // ignore: avoid_print
          print('Extraction polices: $processed fichiers');
        }
      }

      inputStream.close();
      // ignore: avoid_print
      print('Extraction terminée: $processed fichiers TTF dans $fontsPath');
    } catch (e) {
      // ignore: avoid_print
      print('Erreur isolate extraction polices: $e');
      rethrow;
    }
  }

  /// Charge la police QCF d'une page donnée.
  static Future<void> loadFont(int page) async {
    final family = 'QCF_P${page.toString().padLeft(3, '0')}';
    if (_loadedFamilies.contains(family)) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'fonts', '$family.TTF');
    final file = File(path);
    if (!await file.exists()) return;
    final fontData = await file.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(Future.value(ByteData.sublistView(fontData)));
    await loader.load();
    _loadedFamilies.add(family);
  }

  /// Charge QCF_P000.TTF comme police 'suraNameFont'.
  static Future<void> loadSuraNameFont() async {
    const family = 'suraNameFont';
    if (_loadedFamilies.contains(family)) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'fonts', 'QCF_P000.TTF');
    final file = File(path);
    if (!await file.exists()) return;
    final fontData = await file.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(Future.value(ByteData.sublistView(fontData)));
    await loader.load();
    _loadedFamilies.add(family);
  }

  static Map<String, dynamic> getDownloadStatus() => {
        'isDownloading': _isDownloading,
        'isExtracting': _isExtracting,
        'downloadProgress': _downloadProgress,
        'extractionProgress': _extractionProgress,
      };

  static Future<void> clearCache() async {
    await _ensurePaths();
    try {
      final fontsFolder = Directory(_fontsPath!);
      if (await fontsFolder.exists()) {
        await fontsFolder.delete(recursive: true);
      }
      _loadedFamilies.clear();
      debugPrint('Cache des polices supprimé');
    } catch (e) {
      debugPrint('Erreur suppression cache polices: $e');
      rethrow;
    }
  }
}
