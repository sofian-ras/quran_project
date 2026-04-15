import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service d'accès aux pages du Coran (Hafs 1024px).
/// Chaque page est téléchargée individuellement à la demande et mise en cache localement.
class QuranImageService {
  QuranImageService._();
  static final QuranImageService instance = QuranImageService._();

  static const String _cdnBase =
      'https://quran.islam-db.com/data/pages/quranpages_1024/images';

  static const int totalPages = 604;

  final Dio _dio = Dio();
  String? _hafsPath;

  // Évite les téléchargements simultanés de la même page.
  final Map<int, Future<File>> _inProgress = {};

  // Cache synchrone : pages dont le fichier local est confirmé disponible.
  final Map<int, File> _syncCache = {};

  // État du téléchargement global (toutes les pages).
  bool _isDownloadingAll = false;
  double _downloadAllProgress = 0.0;

  /// Retourne le fichier immédiatement si déjà connu, sans I/O.
  File? getSyncCached(int page) => _syncCache[page];

  Future<void> _ensurePaths() async {
    if (_hafsPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _hafsPath = p.join(dir.path, 'hafs');
    await Directory(_hafsPath!).create(recursive: true);
  }

  String _pageFileName(int page) =>
      'page${page.toString().padLeft(3, '0')}.png';

  /// Retourne le fichier local de la page, en le téléchargeant depuis le CDN si absent.
  Future<File> getPageFile(
    String reading,
    int page, {
    void Function(double progress)? onProgress,
  }) async {
    await _ensurePaths();
    final localFile = File(p.join(_hafsPath!, _pageFileName(page)));

    if (_syncCache.containsKey(page)) {
      onProgress?.call(1.0);
      return _syncCache[page]!;
    }

    if (await localFile.exists()) {
      onProgress?.call(1.0);
      _syncCache[page] = localFile;
      return localFile;
    }

    // Déduplique les téléchargements simultanés pour la même page.
    if (_inProgress.containsKey(page)) return _inProgress[page]!;

    final future = _downloadPage(page, localFile, onProgress: onProgress);
    _inProgress[page] = future;
    try {
      return await future;
    } finally {
      _inProgress.remove(page);
    }
  }

  Future<File> _downloadPage(
    int page,
    File dest, {
    void Function(double)? onProgress,
  }) async {
    final url = '$_cdnBase/${_pageFileName(page)}';
    final tmpPath = '${dest.path}.tmp';
    try {
      await _dio.download(
        url,
        tmpPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      await File(tmpPath).rename(dest.path);
      _syncCache[page] = dest;
      return dest;
    } catch (e) {
      final tmp = File(tmpPath);
      if (await tmp.exists()) await tmp.delete();
      debugPrint('Erreur téléchargement page $page: $e');
      rethrow;
    }
  }

  /// Vérifie si le fichier local d'une page existe déjà.
  Future<bool> isPageCached(int page) async {
    await _ensurePaths();
    return File(p.join(_hafsPath!, _pageFileName(page))).exists();
  }

  /// Compatibilité : vérifie si toutes les pages sont présentes (anciens utilisateurs avec ZIP).
  Future<bool> areImagesDownloaded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hafsPath = p.join(dir.path, 'hafs');
      final first = File(p.join(hafsPath, _pageFileName(1)));
      final last = File(p.join(hafsPath, _pageFileName(totalPages)));
      return await first.exists() && await last.exists();
    } catch (_) {
      return false;
    }
  }

  /// Chemin local d'une page si elle existe déjà.
  Future<String?> getPagePathIfExists(String reading, int page) async {
    await _ensurePaths();
    final path = p.join(_hafsPath!, _pageFileName(page));
    if (await File(path).exists()) return path;
    return null;
  }

  Map<String, dynamic> getDownloadStatus() => {
        'isDownloading': _isDownloadingAll,
        'isExtracting': false,
        'downloadProgress': _downloadAllProgress,
        'extractionProgress': 0.0,
      };

  /// Télécharge toutes les 604 pages en arrière-plan (5 pages en parallèle).
  /// Saute les pages déjà présentes localement.
  Future<void> downloadAndExtractImages({
    Function(double)? onDownloadProgress,
    Function(double)? onExtractionProgress,
  }) async {
    if (_isDownloadingAll) return;
    _isDownloadingAll = true;
    _downloadAllProgress = 0.0;

    await _ensurePaths();

    int done = 0;
    const batchSize = 5;

    try {
      for (int start = 1; start <= totalPages; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, totalPages);
        final batch = <Future<void>>[];

        for (int page = start; page <= end; page++) {
          final localFile = File(p.join(_hafsPath!, _pageFileName(page)));
          if (await localFile.exists()) {
            done++;
          } else {
            final captured = page;
            batch.add(
              _downloadPage(captured, localFile).then((_) {}).catchError((_) {}),
            );
          }
        }

        await Future.wait(batch);
        done += batch.length;
        _downloadAllProgress = done / totalPages;
        onDownloadProgress?.call(_downloadAllProgress);
      }
    } finally {
      _isDownloadingAll = false;
    }
  }

  Future<void> clearCache() async {
    await _ensurePaths();
    try {
      final folder = Directory(_hafsPath!);
      if (await folder.exists()) await folder.delete(recursive: true);
      _syncCache.clear();
      _hafsPath = null;
      debugPrint('Cache des images supprimé');
    } catch (e) {
      debugPrint('Erreur suppression cache: $e');
      rethrow;
    }
  }

  Future<int> getCacheSize() async {
    await _ensurePaths();
    try {
      final folder = Directory(_hafsPath!);
      int total = 0;
      if (await folder.exists()) {
        await for (final f in folder.list(recursive: true)) {
          if (f is File) total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
