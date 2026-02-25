// lib/services/qul_pack_service.dart
//
// Service générique "packs QUL" : gère le stockage local + téléchargement.
// Dossier racine: Documents/qul/
//
// API:
//   QulPackService.baseDir()
//   QulPackService.pathOf(relPath)
//   QulPackService.exists(relPath)
//   QulPackService.ensureDir(relDir)
//   QulPackService.downloadToFile(url, relPath)

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class QulPackService {
  static Future<Directory> baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'qul'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> pathOf(String relPath) async {
    final base = await baseDir();
    return p.join(base.path, relPath);
  }

  static Future<bool> exists(String relPath) async {
    final full = await pathOf(relPath);
    return File(full).exists();
  }

  static Future<void> ensureDir(String relDir) async {
    final base = await baseDir();
    final dir = Directory(p.join(base.path, relDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Télécharge une ressource vers Documents/qul/<relPath>.
  /// - Crée les dossiers nécessaires
  /// - Télécharge en .part puis rename (évite fichiers corrompus)
  static Future<File> downloadToFile({
    required String url,
    required String relPath,
    Map<String, String>? headers,
  }) async {
    final fullPath = await pathOf(relPath);

    // Crée le dossier parent
    final parent = Directory(p.dirname(fullPath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tmpPath = '$fullPath.part';
    final tmpFile = File(tmpPath);

    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Download failed ${resp.statusCode} for $url');
    }

    await tmpFile.writeAsBytes(resp.bodyBytes, flush: true);

    // Remplace proprement l’ancien fichier
    final outFile = File(fullPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }
    return tmpFile.rename(fullPath);
  }
}