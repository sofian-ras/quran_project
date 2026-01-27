import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Pack hors-ligne (traduction + tafsir + arabe) téléchargé à la demande.
/// Tu héberges un ZIP (GitHub Releases) puis on extrait dans Documents/quran_text/fr
class QuranTextPackService {
  static final QuranTextPackService instance = QuranTextPackService._();
  QuranTextPackService._();

  /// TODO: remplace par TON lien GitHub Release (comme quran_pages.zip)
  /// Exemple attendu: .../releases/download/vX.Y.Z/quran_text_fr.zip
  static const String frPackZipUrl = 'https://example.com/quran_text_fr.zip';
  static const String frPackZipName = 'quran_text_fr.zip';

  /// Fichiers attendus après extraction (dans Documents/quran_text/fr/)
  static const String frArabicFile = 'arabic.json';
  static const String frTranslationFile = 'translation_fr.json';
  static const String frTafsirFile = 'tafsir_fr.json';

  final Dio _dio = Dio();

  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);

  Future<String> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'quran_text');
  }

  Future<String> _frDir() async => p.join(await _baseDir(), 'fr');

  Future<bool> isFrenchPackReady() async {
    final dir = await _frDir();
    return File(p.join(dir, frArabicFile)).existsSync() &&
        File(p.join(dir, frTranslationFile)).existsSync() &&
        File(p.join(dir, frTafsirFile)).existsSync();
  }

  Future<void> downloadAndExtractFrenchPack() async {
    if (isBusy.value) return;

    isBusy.value = true;
    downloadProgress.value = 0.0;

    try {
      final base = await _baseDir();
      final frDir = await _frDir();

      await Directory(base).create(recursive: true);
      await Directory(frDir).create(recursive: true);

      final zipPath = p.join(base, frPackZipName);

      // Download ZIP
      await _dio.download(
        frPackZipUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = received / total;
          }
        },
      );

      // Extract
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final f in archive) {
        if (!f.isFile) continue;
        final outPath = p.join(frDir, f.name);
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(f.content as List<int>);
      }

      // Optionnel : supprimer le zip
      try {
        await File(zipPath).delete();
      } catch (_) {}
    } finally {
      isBusy.value = false;
    }
  }

  /// Lecture JSON (supporte 2 formats):
  /// - Liste de listes: [[...],[...],...]
  /// - Map { "1:1": "...", ... } -> converti en liste par sourate si besoin (ici on ne le fait pas)
  Future<List<List<String>>> loadSurahListsFromFile(String filePath) async {
    final raw = await File(filePath).readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      // Format: List<List<String>>
      return decoded
          .map<List<String>>((s) => (s as List).map((e) => e.toString()).toList())
          .toList();
    }

    throw StateError('Format JSON non supporté: attendu List<List<String>>');
  }

  Future<_FrenchPackData> loadFrenchPack() async {
    final frDir = await _frDir();

    final arabicPath = p.join(frDir, frArabicFile);
    final trPath = p.join(frDir, frTranslationFile);
    final tafsirPath = p.join(frDir, frTafsirFile);

    final arabic = await compute(_loadListList, arabicPath);
    final translation = await compute(_loadListList, trPath);
    final tafsir = await compute(_loadListList, tafsirPath);

    return _FrenchPackData(
      arabic: arabic,
      translation: translation,
      tafsir: tafsir,
    );
  }

  static Future<List<List<String>>> _loadListList(String path) async {
    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .map<List<String>>((s) => (s as List).map((e) => e.toString()).toList())
          .toList();
    }
    throw StateError('Format JSON non supporté (List<List<String>> attendu)');
  }
}

class _FrenchPackData {
  final List<List<String>> arabic;      // index 0 => sourate 1
  final List<List<String>> translation; // index 0 => sourate 1
  final List<List<String>> tafsir;      // index 0 => sourate 1

  _FrenchPackData({
    required this.arabic,
    required this.translation,
    required this.tafsir,
  });
}
