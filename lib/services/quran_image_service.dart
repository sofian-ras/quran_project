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

  static final Dio _dio = Dio();
  static bool _isDownloading = false;
  static bool _isExtracting = false;
  static double _downloadProgress = 0.0;
  static final double _extractionProgress = 0.0;

  /// Vérifie si les images sont déjà téléchargées et extraites
  static Future<bool> areImagesDownloaded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsFolder = Directory(p.join(dir.path, 'hafs'));
      final warshFolder = Directory(p.join(dir.path, 'warsh'));

      if (!await hafsFolder.exists() || !await warshFolder.exists()) {
        return false;
      }

      final hafsFiles = await hafsFolder.list().toList();
      final warshFiles = await warshFolder.list().toList();

      // Vérifier qu'on a au moins 600 pages dans chaque dossier
      return hafsFiles.length >= 600 && warshFiles.length >= 600;
    } catch (e) {
      debugPrint('Erreur lors de la vérification des images: $e');
      return false;
    }
  }

  /// Récupère le fichier d'une page spécifique
  static Future<File> getPageFile(String reading, int page) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = reading == 'hafs' ? 'png' : 'jpg';
    final pagePath = p.join(dir.path, reading, '$page.$ext');
    final pageFile = File(pagePath);

    // Si la page existe déjà, la retourner
    if (await pageFile.exists()) {
      return pageFile;
    }

    // Sinon, télécharger les images si nécessaire
    if (!await areImagesDownloaded()) {
      await downloadAndExtractImages();
    }

    // Vérifier à nouveau
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
    if (_isDownloading || _isExtracting) {
      debugPrint('Téléchargement/extraction déjà en cours');
      return;
    }

    // Vérifier si déjà téléchargé
    if (await areImagesDownloaded()) {
      debugPrint('Images déjà téléchargées');
      return;
    }

    try {
      _isDownloading = true;
      final dir = await getApplicationDocumentsDirectory();
      final zipPath = p.join(dir.path, zipFileName);

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
      await _extractZipInIsolate(
        zipPath,
        dir.path,
        onExtractionProgress,
      );

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
    Function(double)? onProgress,
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
    final dir = await getApplicationDocumentsDirectory();
    final ext = reading == 'hafs' ? 'png' : 'jpg';
    final pagePath = p.join(dir.path, reading, '$page.$ext');
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
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsFolder = Directory(p.join(dir.path, 'hafs'));
      final warshFolder = Directory(p.join(dir.path, 'warsh'));

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
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsFolder = Directory(p.join(dir.path, 'hafs'));
      final warshFolder = Directory(p.join(dir.path, 'warsh'));

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
