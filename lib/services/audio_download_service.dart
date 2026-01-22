import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

class DownloadProgress {
  final int surahId;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;

  DownloadProgress(this.surahId, this.progress, this.status);
}

class AudioDownloadService {
  AudioDownloadService._();

  static final AudioDownloadService instance = AudioDownloadService._();

  final Dio _dio = Dio();
  final Map<int, DownloadStatus> _downloadStatuses = {};
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

  DownloadStatus getDownloadStatus(int surahId) {
    return _downloadStatuses[surahId] ?? DownloadStatus.notDownloaded;
  }

  ValueNotifier<DownloadProgress> getProgressNotifier(int surahId) {
    return _progressNotifiers.putIfAbsent(
      surahId,
      () => ValueNotifier(DownloadProgress(surahId, 0.0, DownloadStatus.notDownloaded)),
    );
  }

  Future<void> downloadSurah(int surahId) async {
    if (_downloadStatuses[surahId] == DownloadStatus.downloading) {
      return; // Already downloading
    }

    final progressNotifier = getProgressNotifier(surahId);
    _downloadStatuses[surahId] = DownloadStatus.downloading;
    progressNotifier.value = DownloadProgress(surahId, 0.0, DownloadStatus.downloading);

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
            progressNotifier.value = DownloadProgress(surahId, progress, DownloadStatus.downloading);
          }
        },
      );

      _downloadStatuses[surahId] = DownloadStatus.downloaded;
      progressNotifier.value = DownloadProgress(surahId, 1.0, DownloadStatus.downloaded);
    } catch (e) {
      debugPrint("Erreur de téléchargement pour la sourate $surahId: $e");
      _downloadStatuses[surahId] = DownloadStatus.failed;
      progressNotifier.value = DownloadProgress(surahId, 0.0, DownloadStatus.failed);
    }
  }

  Future<void> deleteSurah(int surahId) async {
    try {
      final file = await getAudioFile(surahId);
      if (await file.exists()) {
        await file.delete();
        _downloadStatuses[surahId] = DownloadStatus.notDownloaded;
        final progressNotifier = getProgressNotifier(surahId);
        progressNotifier.value = DownloadProgress(surahId, 0.0, DownloadStatus.notDownloaded);
      }
    } catch (e) {
      debugPrint("Erreur lors de la suppression de la sourate $surahId: $e");
    }
  }

  Future<List<int>> getDownloadedSurahs() async {
    final List<int> downloaded = [];
    for (int i = 1; i <= 114; i++) {
      if (await isDownloaded(i)) {
        downloaded.add(i);
      }
    }
    return downloaded;
  }

  Future<int> getTotalDownloadedSize() async {
    final downloaded = await getDownloadedSurahs();
    int totalSize = 0;
    for (final surahId in downloaded) {
      final file = await getAudioFile(surahId);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }
}
