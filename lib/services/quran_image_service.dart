import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

/// Service pour le téléchargement et l'accès aux pages du Coran (Hafs 1024px).
class QuranImageService {
  static const String zipUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/v1.0.1/quran_hafs_1024.zip';
  static const String zipFileName = 'quran_hafs_1024.zip';
  static const int totalPages = 604;
  static String? _docsPath;
  static String? _hafsPath;
  static final Dio _dio = Dio();
  static bool _isDownloading = false;
  static bool _isExtracting = false;
  static double _downloadProgress = 0.0;
  static double _extractionProgress = 0.0;

  static Future<void> _ensurePaths() async {
    if (_docsPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _docsPath = dir.path;
    _hafsPath = p.join(_docsPath!, 'hafs');
  }

  /// Nom de fichier d'une page : page001.png, page010.png, page604.png…
  static String _pageFileName(int page) =>
      'page${page.toString().padLeft(3, '0')}.png';

  /// Vérifie si les images Hafs sont déjà téléchargées.
  static Future<bool> areImagesDownloaded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsPath = p.join(dir.path, 'hafs');
      final hafsFirst = File(p.join(hafsPath, _pageFileName(1)));
      final hafsLast = File(p.join(hafsPath, _pageFileName(totalPages)));
      return await hafsFirst.exists() && await hafsLast.exists();
    } catch (_) {
      return false;
    }
  }

  /// Récupère le fichier d'une page spécifique (toujours Hafs PNG).
  static Future<File> getPageFile(String reading, int page) async {
    await _ensurePaths();
    final pagePath = p.join(_hafsPath!, _pageFileName(page));
    final pageFile = File(pagePath);

    if (await pageFile.exists()) return pageFile;

    if (!await areImagesDownloaded()) {
      throw Exception('Images non téléchargées. Passez par QuranLoader.');
    }

    if (await pageFile.exists()) return pageFile;

    throw Exception('Page $page introuvable après téléchargement');
  }

  /// Télécharge et extrait le ZIP contenant les images Hafs 1024px.
  static Future<void> downloadAndExtractImages({
    Function(double)? onDownloadProgress,
    Function(double)? onExtractionProgress,
  }) async {
    if (_isDownloading || _isExtracting) {
      debugPrint('Téléchargement/extraction déjà en cours, attente...');
      while (_isDownloading || _isExtracting) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return;
    }

    if (await areImagesDownloaded()) {
      debugPrint('Images déjà téléchargées');
      return;
    }

    try {
      await _ensurePaths();
      _isDownloading = true;
      final zipPath = p.join(_docsPath!, zipFileName);

      debugPrint('Début du téléchargement depuis: $zipUrl');
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
      debugPrint('Extraction terminée avec succès');

      final zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await zipFile.delete();
        debugPrint('ZIP supprimé');
      }
    } catch (e) {
      _isDownloading = false;
      _isExtracting = false;
      debugPrint('Erreur téléchargement/extraction: $e');
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
    final zipPath = params['zipPath']!;
    final destinationPath = params['destinationPath']!;
    // Tous les PNG vont directement dans hafs/, quelle que soit la structure du ZIP
    final hafsPath = p.join(destinationPath, 'hafs');
    try {
      Directory(hafsPath).createSync(recursive: true);
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      int processed = 0;
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;
        if (name.contains('__MACOSX') ||
            name.startsWith('.') ||
            name.contains('/.')) {
          continue;
        }
        // On ne garde que les PNG ; on ignore la structure de dossiers du ZIP
        if (!name.toLowerCase().endsWith('.png')) { continue; }
        final baseName = p.basename(name); // ex : page001.png
        final outFile = File(p.join(hafsPath, baseName));
        outFile.writeAsBytesSync(file.content as List<int>);
        processed++;
        if (processed % 50 == 0) {
          // ignore: avoid_print
          print('Extraction: $processed fichiers');
        }
      }
      // ignore: avoid_print
      print('Extraction terminée: $processed fichiers PNG dans $hafsPath');
    } catch (e) {
      // ignore: avoid_print
      print('Erreur isolate extraction: $e');
      rethrow;
    }
  }

  /// Chemin local d'une page si elle existe déjà.
  static Future<String?> getPagePathIfExists(String reading, int page) async {
    await _ensurePaths();
    final pagePath = p.join(_hafsPath!, _pageFileName(page));
    if (await File(pagePath).exists()) return pagePath;
    return null;
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
      final hafsFolder = Directory(_hafsPath!);
      if (await hafsFolder.exists()) {
        await hafsFolder.delete(recursive: true);
      }
      debugPrint('Cache des images supprimé');
    } catch (e) {
      debugPrint('Erreur suppression cache: $e');
      rethrow;
    }
  }

  static Future<int> getCacheSize() async {
    await _ensurePaths();
    try {
      final hafsFolder = Directory(_hafsPath!);
      int total = 0;
      if (await hafsFolder.exists()) {
        await for (final f in hafsFolder.list(recursive: true)) {
          if (f is File) total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
