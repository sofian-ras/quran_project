import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';

enum DownloadType {
  page,
  surah,
  audio,
}

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  error,
  cancelled,
}

class DownloadItem {
  final String id;
  final String url;
  final String fileName;
  final DownloadType type;
  final int? surahId;
  final int? pageNumber;
  final String? reciterName;
  
  double progress;
  DownloadStatus status;
  String? error;
  CancelToken? cancelToken;
  
  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    this.surahId,
    this.pageNumber,
    this.reciterName,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.error,
    this.cancelToken,
  });
}

class DownloadService {
  static final DownloadService instance = DownloadService._();
  DownloadService._();
  
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  final Map<String, DownloadItem> _downloads = {};
  
  // BehaviorSubject pour exposer les téléchargements comme stream
  final _downloadsSubject = BehaviorSubject<List<DownloadItem>>.seeded([]);
  
  // Stream des téléchargements
  Stream<List<DownloadItem>> get downloadsStream => _downloadsSubject.stream;
  
  // Liste actuelle des téléchargements
  List<DownloadItem> get downloads => _downloadsSubject.value;
  
  // Chemins de stockage
  Future<String> get _basePath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
  
  Future<String> get pagesPath async => p.join(await _basePath, 'quran', 'pages');
  Future<String> get surahsPath async => p.join(await _basePath, 'quran', 'surahs');
  Future<String> audioPath(String reciter) async => p.join(await _basePath, 'audio', reciter);
  
  void _notifyListeners() {
    _downloadsSubject.add(_downloads.values.toList());
  }
  
  // Vérifier si un fichier existe
  Future<bool> isDownloaded(DownloadType type, String fileName) async {
    String path;
    if (type == DownloadType.page) {
      path = p.join(await pagesPath, fileName);
    } else if (type == DownloadType.surah) {
      path = p.join(await surahsPath, fileName);
    } else {
      return false;
    }
    return await File(path).exists();
  }
  
  Future<bool> isAudioDownloaded(String reciter, String fileName) async {
    final path = p.join(await audioPath(reciter), fileName);
    return await File(path).exists();
  }
  
  // Télécharger une page
  Future<String?> downloadPage(int pageNumber, {String? url}) async {
    final fileName = '$pageNumber.png';
    final id = 'page_$pageNumber';
    
    if (await isDownloaded(DownloadType.page, fileName)) {
      debugPrint('Page $pageNumber déjà téléchargée');
      return p.join(await pagesPath, fileName);
    }
    
    final actualUrl = url ?? 'https://example.com/pages/$pageNumber.png'; // Remplacer par vraie URL
    
    final item = DownloadItem(
      id: id,
      url: actualUrl,
      fileName: fileName,
      type: DownloadType.page,
      pageNumber: pageNumber,
      cancelToken: CancelToken(),
    );
    
    return await _download(item, await pagesPath);
  }
  
  // Télécharger une sourate (toutes les pages)
  Future<void> downloadSurah(int surahNumber, int startPage, int endPage) async {
    for (int i = startPage; i <= endPage; i++) {
      await downloadPage(i);
    }
    
    // Sauvegarder dans les préférences
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList('downloaded_surahs') ?? [];
    if (!downloaded.contains(surahNumber.toString())) {
      downloaded.add(surahNumber.toString());
      await prefs.setStringList('downloaded_surahs', downloaded);
    }
  }
  
  // Télécharger audio d'une sourate
  Future<String?> downloadAudio(String reciter, int surahNumber, {String? url}) async {
    final surahNum = surahNumber.toString().padLeft(3, '0');
    final fileName = '$surahNum.mp3';
    final id = 'audio_${reciter}_$surahNumber';
    
    if (await isAudioDownloaded(reciter, fileName)) {
      debugPrint('Audio $reciter - Sourate $surahNumber déjà téléchargé');
      return p.join(await audioPath(reciter), fileName);
    }
    
    final actualUrl = url ?? 'https://server8.mp3quran.net/afs/$surahNum.mp3';
    
    final item = DownloadItem(
      id: id,
      url: actualUrl,
      fileName: fileName,
      type: DownloadType.audio,
      surahId: surahNumber,
      reciterName: reciter,
      cancelToken: CancelToken(),
    );
    
    return await _download(item, await audioPath(reciter));
  }
  
  // Télécharger tous les audios d'un réciteur
  Future<void> downloadAllAudio(String reciter, {Function(int current, int total)? onProgress}) async {
    for (int i = 1; i <= 114; i++) {
      await downloadAudio(reciter, i);
      onProgress?.call(i, 114);
    }
  }
  
  // Fonction de téléchargement principale
  Future<String?> _download(DownloadItem item, String destinationPath) async {
    try {
      _downloads[item.id] = item;
      item.status = DownloadStatus.downloading;
      _notifyListeners();
      
      // Créer le dossier si nécessaire
      final dir = Directory(destinationPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final filePath = p.join(destinationPath, item.fileName);
      
      await _dio.download(
        item.url,
        filePath,
        cancelToken: item.cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.progress = received / total;
            _notifyListeners();
          }
        },
      );
      
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      _notifyListeners();
      
      return filePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        item.status = DownloadStatus.cancelled;
      } else {
        item.status = DownloadStatus.error;
        item.error = e.toString();
      }
      _notifyListeners();
      debugPrint('Erreur téléchargement ${item.id}: $e');
      return null;
    }
  }
  
  // Mettre en pause
  void pauseDownload(String id) {
    final item = _downloads[id];
    if (item != null && item.status == DownloadStatus.downloading) {
      item.cancelToken?.cancel('Pause');
      item.status = DownloadStatus.paused;
      _notifyListeners();
    }
  }
  
  // Reprendre
  Future<void> resumeDownload(String id) async {
    final item = _downloads[id];
    if (item != null && item.status == DownloadStatus.paused) {
      item.cancelToken = CancelToken();
      String destPath;
      if (item.type == DownloadType.page) {
        destPath = await pagesPath;
      } else if (item.type == DownloadType.surah) {
        destPath = await surahsPath;
      } else {
        destPath = await audioPath(item.reciterName ?? 'default');
      }
      await _download(item, destPath);
    }
  }
  
  // Annuler
  void cancelDownload(String id) {
    final item = _downloads[id];
    if (item != null) {
      item.cancelToken?.cancel('Cancelled');
      item.status = DownloadStatus.cancelled;
      _downloads.remove(id);
      _notifyListeners();
    }
  }
  
  // Supprimer un fichier
  Future<void> deleteFile(DownloadType type, String fileName, {String? reciter}) async {
    try {
      String path;
      if (type == DownloadType.page) {
        path = p.join(await pagesPath, fileName);
      } else if (type == DownloadType.surah) {
        path = p.join(await surahsPath, fileName);
      } else if (type == DownloadType.audio && reciter != null) {
        path = p.join(await audioPath(reciter), fileName);
      } else {
        return;
      }
      
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Fichier supprimé: $path');
      }
    } catch (e) {
      debugPrint('Erreur suppression: $e');
    }
  }
  
  // Supprimer tout pour un réciteur
  Future<void> deleteAllAudio(String reciter) async {
    try {
      final dir = Directory(await audioPath(reciter));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('Tous les audios de $reciter supprimés');
      }
    } catch (e) {
      debugPrint('Erreur suppression réciteur: $e');
    }
  }
  
  // Obtenir la taille totale des téléchargements
  Future<int> getTotalSize() async {
    int total = 0;
    
    try {
      final base = await _basePath;
      final dir = Directory(p.join(base, 'quran'));
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
      
      final audioDir = Directory(p.join(base, 'audio'));
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur calcul taille: $e');
    }
    
    return total;
  }
  
  // Formater la taille en MB
  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  // Obtenir les téléchargements actifs
  List<DownloadItem> getActiveDownloads() {
    return _downloads.values
        .where((item) => item.status == DownloadStatus.downloading)
        .toList();
  }
  
  // Obtenir tous les téléchargements
  List<DownloadItem> getAllDownloads() {
    return _downloads.values.toList();
  }
}
