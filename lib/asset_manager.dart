import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class AssetManager {
  static const String zipUrl = 'https://github.com/sofian-ras/quran_project/releases/download/v1.0.0/quran_pages.zip';
  static const String zipFileName = 'quran_pages.zip';
  
  // URLs par type de lecture
  static const Map<String, String> readingUrls = {
    'hafs': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/hafs',
    'warsh': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/warsh',
    'sousi': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/sousi',
    'shouba': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/shouba',
    'qaloon': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/qaloon',
    'doori': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/doori',
    'bazzi': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/bazzi',
    'qumbul': 'https://raw.githubusercontent.com/sofian-ras/quran_project/main/assets/qumbul',
  };
  
  static final Dio _dio = Dio();
  static final Set<int> _downloadingPages = {}; // Pour éviter les téléchargements en double

  // Vérifie si le dossier "hafs" existe (mode ancien - plus utilisé par défaut)
  static Future<bool> areAssetsDownloaded() async {
    // Ne vérifie plus le dossier complet, juste si on a déjà téléchargé des pages
    final dir = await getApplicationDocumentsDirectory();
    final hafsFolder = Directory(p.join(dir.path, 'hafs'));
    
    // Si le dossier existe et contient au moins 10 pages, considéré comme "téléchargé"
    if (await hafsFolder.exists()) {
      final files = await hafsFolder.list().toList();
      return files.length > 10;
    }
    return false;
  }

  // Récupère le fichier d'une page (télécharge si nécessaire)
  static Future<File> getPageFile(String reading, int page) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = (reading == "hafs") ? "png" : "jpg";
    final pagePath = p.join(dir.path, reading, "$page.$ext");
    final pageFile = File(pagePath);
    
    // Si la page existe déjà, la retourner
    if (await pageFile.exists()) {
      return pageFile;
    }
    
    // Sinon, la télécharger à la demande
    await _downloadSinglePage(reading, page);
    return pageFile;
  }
  
  // Télécharge une seule page à la demande
  static Future<void> _downloadSinglePage(String reading, int page) async {
    // Éviter les téléchargements en double
    if (_downloadingPages.contains(page)) {
      // Attendre que le téléchargement en cours se termine
      while (_downloadingPages.contains(page)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    
    _downloadingPages.add(page);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = (reading == "hafs") ? "png" : "jpg";
      final pagePath = p.join(dir.path, reading, "$page.$ext");
      
      // Créer le dossier si nécessaire
      final folder = Directory(p.join(dir.path, reading));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      
      // URL de la page individuelle basée sur le type de lecture
      final baseUrl = readingUrls[reading] ?? readingUrls['hafs']!;
      final pageUrl = '$baseUrl/$page.$ext';
      
      // Télécharger la page
      await _dio.download(
        pageUrl,
        pagePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      debugPrint('Page $page téléchargée avec succès');
    } catch (e) {
      debugPrint('Erreur téléchargement page $page: $e');
      // Si erreur, essayer avec un fallback depuis les assets bundled
      await _copyFromAssets(reading, page);
    } finally {
      _downloadingPages.remove(page);
    }
  }
  
  // Fallback: copier depuis les assets si disponibles
  static Future<void> _copyFromAssets(String reading, int page) async {
    // Cette méthode peut être utilisée comme fallback si vous avez des pages dans assets/hafs/
    // Par exemple, vous pourriez bundler les premières pages (1-10) dans l'app
    // pour un démarrage instantané même sans connexion
    
    try {
      // TODO: Implémenter la copie depuis rootBundle si vous bundlez des pages
      // final dir = await getApplicationDocumentsDirectory();
      // final ext = (reading == "hafs") ? "png" : "jpg";
      // final assetPath = 'assets/$reading/$page.$ext';
      // final destPath = p.join(dir.path, reading, "$page.$ext");
      // final bytes = await rootBundle.load(assetPath);
      // final file = File(destPath);
      // await file.writeAsBytes(bytes.buffer.asUint8List());
      
      debugPrint('Fallback assets pour page $page non disponible');
    } catch (e) {
      debugPrint('Erreur fallback assets: $e');
    }
  }

  // Télécharge et extrait le ZIP (gardé pour compatibilité mais déprécié)
  @Deprecated('Utiliser le téléchargement à la demande via getPageFile()')
  static Future<void> downloadAndExtract({required Function(double) onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = p.join(dir.path, zipFileName);
    final dio = Dio();

    try {
      // 1. Téléchargement
      await dio.download(
        zipUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // 2. Décompression
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
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

      // 3. Nettoyage (supprimer le zip)
      final zFile = File(zipPath);
      if (await zFile.exists()) await zFile.delete();

    } catch (e) {
      // use debugPrint instead of print for better control and lint compliance
      // ignore: avoid_print
      // debugPrint is preferred in Flutter for logging
      debugPrint("Erreur AssetManager: $e");
      rethrow;
    }
  }
}