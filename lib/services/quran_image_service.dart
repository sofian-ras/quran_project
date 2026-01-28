import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

/// Service robuste pour gérer le téléchargement et l'accès aux pages du Coran
class QuranImageService {
  static const String zipUrl =
      'https://github.com/sofian-ras/quran_project/releases/download/v1.0.0/quran_pages.zip';
  static const String zipFileName = 'quran_pages.zip';
  static const int totalPages = 604;
  static String? _docsPath;
  static String? _hafsPath;
  static String? _warshPath;
  static final Dio _dio = Dio();
  static bool _isDownloading = false;
  static bool _isExtracting = false;
  static double _downloadProgress = 0.0;
  static final double _extractionProgress = 0.0;

  static Future<void> _ensurePaths() async {
    if (_docsPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _docsPath = dir.path;
    _hafsPath = p.join(_docsPath!, 'hafs');
    _warshPath = p.join(_docsPath!, 'warsh');
  }

  /// Vérifie si les images sont déjà téléchargées et extraites
  static Future<bool> areImagesDownloaded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsPath = p.join(dir.path, 'hafs');
      final warshPath = p.join(dir.path, 'warsh');

      final hafsFolder = Directory(hafsPath);
      final warshFolder = Directory(warshPath);

      if (!await hafsFolder.exists() || !await warshFolder.exists()) return false;

      final hafsFirst = File(p.join(hafsPath, '1.png'));
      final hafsLast = File(p.join(hafsPath, '${totalPages}.png'));
      final warshFirst = File(p.join(warshPath, '1.jpg'));
      final warshLast = File(p.join(warshPath, '${totalPages}.jpg'));

      return await hafsFirst.exists() &&
          await hafsLast.exists() &&
          await warshFirst.exists() &&
          await warshLast.exists();
    } catch (_) {
      return false;
    }
  }


  /// Récupère le fichier d'une page spécifique
  static Future<File> getPageFile(String reading, int page) async {
    await _ensurePaths();

    final ext = reading == 'hafs' ? 'png' : 'jpg';
    final basePath = reading == 'hafs' ? _hafsPath! : _warshPath!;
    final pagePath = p.join(basePath, '$page.$ext');
    final pageFile = File(pagePath);

    if (await pageFile.exists()) {
      return pageFile;
    }

    // Si pas prêt, on ne télécharge pas ici.
    // Le téléchargement doit être fait via QuranLoader.
    if (!await areImagesDownloaded()) {
      throw Exception('Images non téléchargées. Passez par QuranLoader.');
    }


    if (await pageFile.exists()) {
      return pageFile;
    }

    throw Exception('Page $page pour $reading introuvable après téléchargement');
  }

  /// Télécharge et extrait le ZIP contenant les images
  static Future<void> downloadAndExtractImages({
    Function(double)? onDownloadProgress,
    Function(double)? onExtractionProgress,
  }) async {
    // Éviter les téléchargements multiples
    // IMPORTANT: si déjà en cours, on ATTEND la fin au lieu de return,
    // sinon getPageFile() peut throw pendant un téléchargement en cours.
    if (_isDownloading || _isExtracting) {
      debugPrint('Téléchargement/extraction déjà en cours, attente...');
      while (_isDownloading || _isExtracting) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return;
    }

    // Vérifier si déjà téléchargé
    if (await areImagesDownloaded()) {
      debugPrint('Images déjà téléchargées');
      return;
    }

    try {
      await _ensurePaths();

      _isDownloading = true;
      final zipPath = p.join(_docsPath!, zipFileName);

      // Étape 1: Téléchargement
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
            debugPrint(
                'Téléchargement: ${(_downloadProgress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      _isDownloading = false;
      _isExtracting = true;
      debugPrint('Téléchargement terminé, début de l\'extraction...');

      // Étape 2: Extraction dans un Isolate séparé (pour ne pas bloquer l'UI)
      onExtractionProgress?.call(0.0);

      await _extractZipInIsolate(
        zipPath,
        _docsPath!,
      );

      onExtractionProgress?.call(1.0);


      _isExtracting = false;
      debugPrint('Extraction terminée avec succès');

      // Étape 3: Nettoyage du ZIP
      final zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await zipFile.delete();
        debugPrint('ZIP supprimé');
      }
    } catch (e) {
      _isDownloading = false;
      _isExtracting = false;
      debugPrint('Erreur lors du téléchargement/extraction: $e');
      rethrow;
    }
  }

  /// Extrait le ZIP dans un Isolate séparé pour éviter de bloquer l'UI
  static Future<void> _extractZipInIsolate(
    String zipPath,
    String destinationPath,
  ) async {
    // Utiliser compute pour exécuter dans un Isolate
    await compute(_extractZipTask, {
      'zipPath': zipPath,
      'destinationPath': destinationPath,
    });
  }

  /// Tâche d'extraction exécutée dans un Isolate
  static void _extractZipTask(Map<String, String> params) {
    final zipPath = params['zipPath']!;
    final destinationPath = params['destinationPath']!;

    try {
      // Lire le fichier ZIP
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      int processedFiles = 0;
      final totalFiles = archive.length;

      // Extraire chaque fichier
      for (final file in archive) {
        final filename = file.name;

        // Ignorer les métadonnées MacOS et fichiers cachés
        if (filename.contains('__MACOSX') ||
            filename.startsWith('.') ||
            filename.contains('/.')) {
          continue;
        }

        final filePath = p.join(destinationPath, filename);

        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(filePath);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
        } else {
          Directory(filePath).createSync(recursive: true);
        }

        processedFiles++;
        // Log progression tous les 50 fichiers
        if (processedFiles % 50 == 0) {
          debugPrint('Extraction: $processedFiles/$totalFiles fichiers');
        }
      }

      debugPrint('Extraction terminée: $processedFiles fichiers extraits');
    } catch (e) {
      debugPrint('Erreur dans l\'Isolate d\'extraction: $e');
      rethrow;
    }
  }

  /// Récupère le chemin local d'une page (sans forcer le téléchargement)
  static Future<String?> getPagePathIfExists(String reading, int page) async {
    await _ensurePaths();

    final ext = reading == 'hafs' ? 'png' : 'jpg';
    final basePath = reading == 'hafs' ? _hafsPath! : _warshPath!;
    final pagePath = p.join(basePath, '$page.$ext');
    final pageFile = File(pagePath);

    if (await pageFile.exists()) {
      return pagePath;
    }
    return null;
  }

  /// Obtient le statut actuel du téléchargement
  static Map<String, dynamic> getDownloadStatus() {
    return {
      'isDownloading': _isDownloading,
      'isExtracting': _isExtracting,
      'downloadProgress': _downloadProgress,
      'extractionProgress': _extractionProgress,
    };
  }

  /// Supprime toutes les images téléchargées (pour libérer de l'espace)
  static Future<void> clearCache() async {
    await _ensurePaths();
    try {
      final hafsFolder = Directory(_hafsPath!);
      final warshFolder = Directory(_warshPath!);

      if (await hafsFolder.exists()) {
        await hafsFolder.delete(recursive: true);
      }
      if (await warshFolder.exists()) {
        await warshFolder.delete(recursive: true);
      }

      debugPrint('Cache des images supprimé');
    } catch (e) {
      debugPrint('Erreur lors de la suppression du cache: $e');
      rethrow;
    }
  }

  /// Calcule la taille totale des images téléchargées
  static Future<int> getCacheSize() async {
    await _ensurePaths();
    try {
      final hafsFolder = Directory(_hafsPath!);
      final warshFolder = Directory(_warshPath!);

      int totalSize = 0;

      if (await hafsFolder.exists()) {
        await for (final file in hafsFolder.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      if (await warshFolder.exists()) {
        await for (final file in warshFolder.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Erreur lors du calcul de la taille du cache: $e');
      return 0;
    }
  }
}
