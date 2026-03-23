import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service de chargement des polices QCF à la demande.
/// Les polices de page sont récupérées depuis le CDN Quran Foundation (une par page).
/// QCF_P000 (noms des sourates) est téléchargé séparément depuis GitHub.
class FontDownloadService {
  static const String _cdnBase =
      'https://verses.quran.foundation/fonts/quran/hafs/v1/ttf';

  static const String _p000Url =
      'https://github.com/sofian-ras/quran_project/releases/download/v1.0.0.0/QCF_P000.TTF';

  static final Dio _dio = Dio();
  static String? _fontsPath;
  static final Set<String> _loadedFamilies = {};

  static Future<void> _ensurePaths() async {
    if (_fontsPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _fontsPath = p.join(dir.path, 'fonts');
    await Directory(_fontsPath!).create(recursive: true);
  }

  static String _localFileName(int page) =>
      'QCF_P${page.toString().padLeft(3, '0')}.TTF';

  /// Télécharge si nécessaire et charge la police QCF d'une page donnée.
  static Future<void> loadFont(int page) async {
    final family = 'QCF_P${page.toString().padLeft(3, '0')}';
    if (_loadedFamilies.contains(family)) return;

    await _ensurePaths();
    final localFile = File(p.join(_fontsPath!, _localFileName(page)));

    if (!await localFile.exists()) {
      final url = '$_cdnBase/p$page.ttf';
      try {
        await _dio.download(
          url,
          localFile.path,
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        );
      } catch (e) {
        debugPrint('Impossible de télécharger la police page $page: $e');
        return;
      }
    }

    try {
      final fontData = await localFile.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(fontData)));
      await loader.load();
      _loadedFamilies.add(family);
    } catch (e) {
      debugPrint('Erreur chargement police $family: $e');
    }
  }

  /// Télécharge si nécessaire et charge QCF_P000 comme police 'suraNameFont'.
  static Future<void> loadSuraNameFont() async {
    const family = 'suraNameFont';
    if (_loadedFamilies.contains(family)) return;

    await _ensurePaths();
    final localFile = File(p.join(_fontsPath!, 'QCF_P000.TTF'));

    if (!await localFile.exists()) {
      try {
        await _dio.download(
          _p000Url,
          localFile.path,
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        );
      } catch (e) {
        debugPrint('Impossible de télécharger QCF_P000: $e');
        return;
      }
    }

    try {
      final fontData = await localFile.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(fontData)));
      await loader.load();
      _loadedFamilies.add(family);
    } catch (e) {
      debugPrint('Erreur chargement suraNameFont: $e');
    }
  }

  /// Retourne true si le font de la page est déjà chargé en mémoire.
  static bool isFontLoaded(int page) {
    final family = 'QCF_P${page.toString().padLeft(3, '0')}';
    return _loadedFamilies.contains(family);
  }

  /// Toujours vrai — les polices sont désormais chargées à la demande.
  static Future<bool> areFontsDownloaded() async => true;

  static Future<void> clearCache() async {
    await _ensurePaths();
    try {
      final folder = Directory(_fontsPath!);
      if (await folder.exists()) await folder.delete(recursive: true);
      _loadedFamilies.clear();
      debugPrint('Cache des polices supprimé');
    } catch (e) {
      debugPrint('Erreur suppression cache polices: $e');
    }
  }
}
