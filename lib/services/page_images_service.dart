import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

/// Service pour le téléchargement des images de pages du Mushaf.
class PageImagesService {
  static const String zipUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/version1.0.0/pages_hafs_1920.zip';
  static const String zipFileName = 'pages_hafs_1920.zip';

  static final Dio _dio = Dio();
  static bool _isDownloading = false;
  static bool _isExtracting = false;
  static double _downloadProgress = 0.0;
  static double _extractionProgress = 0.0;

  static String? _localPagesPath;

  /// Retourne le chemin local du dossier des images (après init).
  static String? get localPagesPath => _localPagesPath;

  static Future<String> _getPagesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'pages');
  }

  /// Initialise le chemin local (à appeler au démarrage).
  static Future<void> init() async {
    _localPagesPath = await _getPagesPath();
  }

  /// Vérifie si les images sont déjà téléchargées.
  static Future<bool> areImagesDownloaded() async {
    try {
      final path = await _getPagesPath();
      final first = File(p.join(path, '1.png'));
      final last  = File(p.join(path, '604.png'));
      return await first.exists() && await last.exists();
    } catch (_) {
      return false;
    }
  }

  /// Télécharge et extrait le ZIP des images de pages.
  static Future<void> downloadAndExtract({
    Function(double)? onDownloadProgress,
    Function(double)? onExtractionProgress,
  }) async {
    if (_isDownloading || _isExtracting) {
      while (_isDownloading || _isExtracting) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return;
    }

    if (await areImagesDownloaded()) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final zipPath = p.join(dir.path, zipFileName);

      _isDownloading = true;
      debugPrint('Téléchargement des images de pages depuis: $zipUrl');
      await _dio.download(
        zipUrl,
        zipPath,
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(minutes: 30),
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

      await compute(_extractZipTask, {
        'zipPath': zipPath,
        'destinationPath': dir.path,
      });

      _extractionProgress = 1.0;
      onExtractionProgress?.call(1.0);
      _isExtracting = false;

      final zipFile = File(zipPath);
      if (await zipFile.exists()) await zipFile.delete();

      _localPagesPath = await _getPagesPath();
      debugPrint('Images de pages extraites dans: $_localPagesPath');
    } catch (e) {
      _isDownloading = false;
      _isExtracting = false;
      debugPrint('Erreur téléchargement images: $e');
      rethrow;
    }
  }

  static void _extractZipTask(Map<String, String> params) {
    final zipPath         = params['zipPath']!;
    final destinationPath = params['destinationPath']!;
    final pagesPath       = p.join(destinationPath, 'pages');

    Directory(pagesPath).createSync(recursive: true);

    final inputStream = InputFileStream(zipPath);
    final archive    = ZipDecoder().decodeStream(inputStream);

    int processed = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name.contains('__MACOSX') || name.startsWith('.') || name.contains('/.')) continue;
      if (!name.toLowerCase().endsWith('.png')) continue;

      final outPath      = p.join(pagesPath, p.basename(name));
      final outputStream = OutputFileStream(outPath);
      file.writeContent(outputStream);
      outputStream.close();

      processed++;
      if (processed % 50 == 0) {
        // ignore: avoid_print
        print('Extraction images: $processed fichiers');
      }
    }

    inputStream.close();
    // ignore: avoid_print
    print('Extraction terminée: $processed images PNG dans $pagesPath');
  }

  static Map<String, dynamic> getStatus() => {
    'isDownloading':      _isDownloading,
    'isExtracting':       _isExtracting,
    'downloadProgress':   _downloadProgress,
    'extractionProgress': _extractionProgress,
  };

  static Future<void> clearCache() async {
    final path = await _getPagesPath();
    final dir  = Directory(path);
    if (await dir.exists()) await dir.delete(recursive: true);
    _localPagesPath = null;
    debugPrint('Cache des images supprimé');
  }
}
