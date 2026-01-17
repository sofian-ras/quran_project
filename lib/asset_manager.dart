import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';

/// Nom du fichier ZIP dans assets/assetpacks/
const String zipAssetPath = 'assets/assetpacks/quran_pages.zip';
const String zipFileName = 'quran_pages.zip';

/// Décompresse le ZIP dans le dossier local
Future<void> downloadAndExtractZip() async {
  final dir = await getApplicationDocumentsDirectory();
  final zipFile = File(p.join(dir.path, zipFileName));

  // Copie du ZIP depuis les assets si pas déjà présent
  if (!await zipFile.exists()) {
    print('Copie du ZIP depuis assets...');
    final bytes = await rootBundle.load(zipAssetPath);
    await zipFile.writeAsBytes(bytes.buffer.asUint8List());
    print('ZIP copié dans ${zipFile.path}');
  } else {
    print('ZIP déjà présent dans ${zipFile.path}');
  }

  // Décompression
  final bytes = await zipFile.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final file in archive) {
    final filePath = p.join(dir.path, file.name); // garde la structure des dossiers
    if (file.isFile) {
      final outFile = File(filePath);
      await outFile.create(recursive: true); // crée les dossiers automatiquement
      await outFile.writeAsBytes(file.content as List<int>);
      print('Fichier écrit : $filePath');
    }
  }

  print('ZIP décompressé !');
}

/// Retourne le fichier d'une page
Future<File> getPageFile(String reading, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, reading, fileName); // hafs/1.png ou warsh/1.jpg
  final file = File(path);

  if (!await file.exists()) {
    throw Exception(
        'Fichier $fileName non trouvé dans $reading. Vérifie que le ZIP a été décompressé.');
  }

  return file;
}

/// Précharge les premières pages (optionnel)
Future<void> preloadAllPages(String reading, int count) async {
  for (int i = 1; i <= count; i++) {
    final ext = reading == 'hafs' ? 'png' : 'jpg';
    final fileName = '$i.$ext';
    try {
      await getPageFile(reading, fileName);
    } catch (e) {
      debugPrint('Page $fileName non trouvée : $e');
    }
  }
}
