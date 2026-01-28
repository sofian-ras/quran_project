import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'dart:isolate';


class AssetManager {
  static const String zipUrl = 'https://github.com/sofian-ras/quran_project/releases/download/v1.0.0/quran_pages.zip';
  static const String zipFileName = 'quran_pages.zip';
  static bool? _assetsReadyCache; 
  static final Dio _dio = Dio();
  static bool _isDownloadingZip = false; // Pour éviter les téléchargements multiples du ZIP

  // Vérifie si les pages sont déjà téléchargées (ZIP extrait)
  static Future<bool> areAssetsDownloaded() async {
    if (_assetsReadyCache == true) return true;
    final dir = await getApplicationDocumentsDirectory();
    final hafsFolder = Directory(p.join(dir.path, 'hafs'));
    final warshFolder = Directory(p.join(dir.path, 'warsh'));
    
    // Vérifier que les deux dossiers existent avec des pages
    if (await hafsFolder.exists() && await warshFolder.exists()) {
      final hafsFiles = await hafsFolder.list().toList();
      final warshFiles = await warshFolder.list().toList();
      final ok = hafsFiles.length >= 600 && warshFiles.length >= 600;
      if (ok) _assetsReadyCache = true;
      return ok;
    }
    return false;
  }

  // Récupère le fichier d'une page (télécharge le ZIP si nécessaire)
  static Future<File> getPageFile(String reading, int page) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = (reading == "hafs") ? "png" : "jpg";
    final pagePath = p.join(dir.path, reading, "$page.$ext");
    final pageFile = File(pagePath);
    
    // Si la page existe déjà, la retourner
    if (await pageFile.exists()) {
      return pageFile;
    }
    
    // Si les assets ne sont pas téléchargés, télécharger le ZIP complet
    final assetsDownloaded = await areAssetsDownloaded();
    if (!assetsDownloaded) {
      await _downloadAndExtractZipIfNeeded();
    }
    
    // Vérifier à nouveau si la page existe maintenant
    if (await pageFile.exists()) {
      return pageFile;
    }
    
    // Si toujours pas là, erreur
    throw Exception('Page $page pour $reading introuvable après téléchargement');
  }
  
  // Télécharge et extrait le ZIP si pas déjà fait (avec protection contre téléchargements multiples)
  static Future<void> _downloadAndExtractZipIfNeeded() async {
    // Si déjà téléchargé, ne rien faire
    if (await areAssetsDownloaded()) {
      return;
    }
    
    // Si déjà en cours de téléchargement, attendre
    if (_isDownloadingZip) {
      while (_isDownloadingZip) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return;
    }
    
    _isDownloadingZip = true;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final zipPath = p.join(dir.path, zipFileName);

      debugPrint('Téléchargement du ZIP depuis: $zipUrl');
      
      // 1. Téléchargement
      await _dio.download(
        zipUrl,
        zipPath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      debugPrint('ZIP téléchargé, extraction en cours...');

      // 2. Décompression (dans un isolate pour éviter le freeze UI)
      await Isolate.run(() {
        final bytes = File(zipPath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;

          // Ignorer les métadonnées MacOS
          if (filename.contains('__MACOSX') || filename.startsWith('.')) {
            continue;
          }

          final filePath = p.join(dir.path, filename);
          if (file.isFile) {
            final data = file.content as List<int>;
            File(filePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory(filePath).createSync(recursive: true);
          }
        }
      });

      // Après extraction réussie
      _assetsReadyCache = true;


      debugPrint('Extraction terminée avec succès');

      // 3. Nettoyage (supprimer le zip)
      final zFile = File(zipPath);
      if (await zFile.exists()) {
        await zFile.delete();
      }

    } catch (e) {
      debugPrint("Erreur lors du téléchargement/extraction: $e");
      rethrow;
    } finally {
      _isDownloadingZip = false;
    }
  }
}