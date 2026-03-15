import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AudioDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

class DownloadProgress {
  final int surahId;
  final double progress; // 0.0 to 1.0
  final AudioDownloadStatus status;

  DownloadProgress(this.surahId, this.progress, this.status);
}

class AudioDownloadService {
  AudioDownloadService._();

  static final AudioDownloadService instance = AudioDownloadService._();

  final Dio _dio = Dio();
  final Map<int, AudioDownloadStatus> _downloadStatuses = {};
  final Map<int, ValueNotifier<DownloadProgress>> _progressNotifiers = {};

  String _currentServer = "https://server8.mp3quran.net/afs";

  void updateServer(String server) {
    _currentServer = server;
  }

  Future<Directory> get _audioDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'quran_audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  Future<File> getAudioFile(int surahId) async {
    final dir = await _audioDirectory;
    final surahNum = surahId.toString().padLeft(3, '0');
    return File(p.join(dir.path, '$surahNum.mp3'));
  }

  Future<bool> isDownloaded(int surahId) async {
    final file = await getAudioFile(surahId);
    return await file.exists();
  }

  AudioDownloadStatus getAudioDownloadStatus(int surahId) {
    return _downloadStatuses[surahId] ?? AudioDownloadStatus.notDownloaded;
  }

  ValueNotifier<DownloadProgress> getProgressNotifier(int surahId) {
    return _progressNotifiers.putIfAbsent(
      surahId,
      () => ValueNotifier(DownloadProgress(surahId, 0.0, AudioDownloadStatus.notDownloaded)),
    );
  }

  Future<void> downloadSurah(int surahId) async {
    if (_downloadStatuses[surahId] == AudioDownloadStatus.downloading) {
      return; // Already downloading
    }

    final progressNotifier = getProgressNotifier(surahId);
    _downloadStatuses[surahId] = AudioDownloadStatus.downloading;
    progressNotifier.value = DownloadProgress(surahId, 0.0, AudioDownloadStatus.downloading);

    try {
      final file = await getAudioFile(surahId);
      final surahNum = surahId.toString().padLeft(3, '0');
      final url = '$_currentServer/$surahNum.mp3';

      await _dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            progressNotifier.value = DownloadProgress(surahId, progress, AudioDownloadStatus.downloading);
          }
        },
      );

      _downloadStatuses[surahId] = AudioDownloadStatus.downloaded;
      progressNotifier.value = DownloadProgress(surahId, 1.0, AudioDownloadStatus.downloaded);
    } catch (e) {
      debugPrint("Erreur de téléchargement pour la sourate $surahId: $e");
      _downloadStatuses[surahId] = AudioDownloadStatus.failed;
      progressNotifier.value = DownloadProgress(surahId, 0.0, AudioDownloadStatus.failed);
    }
  }

  Future<void> deleteSurah(int surahId) async {
    try {
      final file = await getAudioFile(surahId);
      if (await file.exists()) {
        await file.delete();
        _downloadStatuses[surahId] = AudioDownloadStatus.notDownloaded;
        final progressNotifier = getProgressNotifier(surahId);
        progressNotifier.value = DownloadProgress(surahId, 0.0, AudioDownloadStatus.notDownloaded);
      }
    } catch (e) {
      debugPrint("Erreur lors de la suppression de la sourate $surahId: $e");
    }
  }

  Future<List<int>> getDownloadedSurahs() async {
    final results = await Future.wait(
      List.generate(114, (i) async {
        return await isDownloaded(i + 1) ? i + 1 : 0;
      }),
    );
    return results.where((id) => id > 0).toList();
  }

  Future<int> getTotalDownloadedSize() async {
    final downloaded = await getDownloadedSurahs();
    final sizes = await Future.wait<int>(
      downloaded.map((surahId) async {
        final file = await getAudioFile(surahId);
        return await file.exists() ? await file.length() : 0;
      }),
    );
    return sizes.fold<int>(0, (a, b) => a + b);
  }
}
