import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class AssetManager {
  static const String zipUrl = 'https://github.com/sofian-ras/quran_project/releases/download/v1.0.0/quran_pages.zip';
  static const String zipFileName = 'quran_pages.zip';

  // Vérifie si le dossier "hafs" existe déjà pour éviter de retélécharger
  static Future<bool> areAssetsDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final hafsFolder = Directory(p.join(dir.path, 'hafs'));
    return await hafsFolder.exists();
  }

  // Télécharge et extrait le ZIP
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
      print("Erreur AssetManager: $e");
      rethrow;
    }
  }

  // Récupère le fichier d'une page
  static Future<File> getPageFile(String reading, int page) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = (reading == "hafs") ? "png" : "jpg";
    return File(p.join(dir.path, reading, "$page.$ext"));
  }
}