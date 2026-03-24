// lib/services/mp3quran/timed_surah_downloader.dart
//
// Télécharge et met en cache local les MP3 de sourates complètes
// pour les récitateurs seek-based.
//
// Structure des fichiers locaux :
//   {appDocumentsDir}/timed_audio/{localCacheId}/{surah:3}.mp3
//
// Usage :
//   final path = await TimedSurahDownloader.instance.ensureDownloaded(source, 20);
//   // path = chemin local absolu vers 020.mp3

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/reciter_audio_source.dart';

enum TimedDownloadStatus { notDownloaded, downloading, downloaded, error }

class TimedSurahDownloader {
  TimedSurahDownloader._();
  static final TimedSurahDownloader instance = TimedSurahDownloader._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10), // sourates = fichiers larges
  ));

  // ── Progrès ────────────────────────────────────────────────────────────────

  // Clé : "{localCacheId}/{surah:3}"
  final Map<String, ValueNotifier<double>>         _progress = {};
  final Map<String, TimedDownloadStatus>           _status   = {};

  String _key(ReciterAudioSource source, int surah) =>
      '${source.localCacheId}/${surah.toString().padLeft(3, '0')}';

  ValueNotifier<double> progressNotifier(ReciterAudioSource source, int surah) =>
      _progress.putIfAbsent(_key(source, surah), () => ValueNotifier(0.0));

  TimedDownloadStatus statusOf(ReciterAudioSource source, int surah) =>
      _status[_key(source, surah)] ?? TimedDownloadStatus.notDownloaded;

  // ── Chemins ────────────────────────────────────────────────────────────────

  Future<String> _localPath(ReciterAudioSource source, int surah) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'timed_audio', source.localCacheId,
        '${surah.toString().padLeft(3, '0')}.mp3');
  }

  Future<bool> isDownloaded(ReciterAudioSource source, int surah) async {
    final path = await _localPath(source, surah);
    return File(path).exists();
  }

  // ── Téléchargement ────────────────────────────────────────────────────────

  /// Retourne le chemin local du fichier.
  /// Si déjà téléchargé : retourne immédiatement.
  /// Sinon : télécharge (avec progression) puis retourne.
  Future<String> ensureDownloaded(
    ReciterAudioSource source,
    int surah,
  ) async {
    final path   = await _localPath(source, surah);
    final key    = _key(source, surah);
    final file   = File(path);

    // Déjà présent
    if (await file.exists()) {
      _status[key] = TimedDownloadStatus.downloaded;
      return path;
    }

    // Déjà en cours — attendre la fin
    if (_status[key] == TimedDownloadStatus.downloading) {
      return _waitForDownload(key, path);
    }

    // Lancer le téléchargement
    _status[key] = TimedDownloadStatus.downloading;
    progressNotifier(source, surah).value = 0.0;

    await Directory(p.dirname(path)).create(recursive: true);

    final url = source.surahUrl(surah);
    debugPrint('TimedSurahDownloader: téléchargement $url → $path');

    try {
      await _dio.download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier(source, surah).value = received / total;
          }
        },
      );
      _status[key] = TimedDownloadStatus.downloaded;
      progressNotifier(source, surah).value = 1.0;
      debugPrint('TimedSurahDownloader: téléchargement terminé → $path');
      return path;
    } catch (e) {
      _status[key] = TimedDownloadStatus.error;
      // Nettoyer le fichier partiel
      if (await file.exists()) await file.delete();
      debugPrint('TimedSurahDownloader: erreur téléchargement — $e');
      rethrow;
    }
  }

  /// Attend qu'un téléchargement en cours se termine.
  Future<String> _waitForDownload(String key, String path) async {
    while (_status[key] == TimedDownloadStatus.downloading) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (_status[key] == TimedDownloadStatus.downloaded) return path;
    throw StateError('Téléchargement échoué pour $key');
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> delete(ReciterAudioSource source, int surah) async {
    final path = await _localPath(source, surah);
    final file = File(path);
    if (await file.exists()) await file.delete();
    final key = _key(source, surah);
    _status.remove(key);
    _progress[key]?.value = 0.0;
    debugPrint('TimedSurahDownloader: supprimé $path');
  }

  Future<void> deleteAll(ReciterAudioSource source) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
        p.join(dir.path, 'timed_audio', source.localCacheId));
    if (await folder.exists()) await folder.delete(recursive: true);
    _status.removeWhere((k, _) => k.startsWith(source.localCacheId));
    debugPrint('TimedSurahDownloader: dossier supprimé — ${source.localCacheId}');
  }
}
