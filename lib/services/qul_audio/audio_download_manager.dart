// lib/services/qul_audio/audio_download_manager.dart
//
// Gestionnaire de téléchargements audio QUL.
//
// Fonctionnalités :
//   - Téléchargement verset ou sourate
//   - Progression temps réel (ValueNotifier)
//   - Annulation / retry
//   - Vérification d'intégrité minimale (taille > 0)
//   - Persistance de l'état (SharedPreferences)
//   - Lecture locale prioritaire sur distante
//
// Structure des fichiers locaux :
//   <documents>/qul_audio/<quranComId>/<surah>_<ayah>.mp3  ← verset
//   <documents>/qul_audio/<quranComId>/surah_<surah>.mp3   ← sourate complète

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Modèles ───────────────────────────────────────────────────────────────────

enum DownloadStatus { idle, downloading, done, failed }

class DownloadEntry {
  final String key;        // ex: "7:2:255" (verset) ou "7:2" (sourate)
  final String url;        // URL distante QUL
  final String localPath;  // chemin fichier local
  DownloadStatus status;
  double progress;         // 0.0 → 1.0
  String? errorMessage;
  CancelToken? _cancelToken;

  DownloadEntry({
    required this.key,
    required this.url,
    required this.localPath,
    this.status   = DownloadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'key':       key,
    'url':       url,
    'localPath': localPath,
    'status':    status.index,
    'progress':  progress,
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> j) => DownloadEntry(
    key:       j['key']       as String,
    url:       j['url']       as String,
    localPath: j['localPath'] as String,
    status:    DownloadStatus.values[j['status'] as int],
    progress:  (j['progress'] as num).toDouble(),
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AudioDownloadManager {
  AudioDownloadManager._() { _loadState(); }
  static final AudioDownloadManager instance = AudioDownloadManager._();

  static const String _prefKey  = 'qul_downloads_v1';
  static const String _audioDir = 'qul_audio';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
  ));

  final Map<String, DownloadEntry> _entries = {};

  /// Notifier réactif : la UI écoute ce notifier pour mettre à jour les boutons.
  final ValueNotifier<Map<String, DownloadEntry>> entriesNotifier =
      ValueNotifier(const {});

  // ── Clés ──────────────────────────────────────────────────────────────────

  static String ayahKey(int quranComId, int surah, int ayah) =>
      '$quranComId:$surah:$ayah';

  static String surahKey(int quranComId, int surah) =>
      '$quranComId:$surah';

  // ── Chemins locaux ────────────────────────────────────────────────────────

  Future<String> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory(p.join(docs.path, _audioDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> ayahPath(int quranComId, int surah, int ayah) async {
    final base   = await _baseDir();
    final folder = p.join(base, quranComId.toString());
    await Directory(folder).create(recursive: true);
    return p.join(folder, '${surah}_$ayah.mp3');
  }

  Future<String> surahPath(int quranComId, int surah) async {
    final base   = await _baseDir();
    final folder = p.join(base, quranComId.toString());
    await Directory(folder).create(recursive: true);
    return p.join(folder, 'surah_$surah.mp3');
  }

  // ── Statuts ───────────────────────────────────────────────────────────────

  DownloadStatus statusOf(String key) =>
      _entries[key]?.status ?? DownloadStatus.idle;

  bool isDownloaded(String key) => statusOf(key) == DownloadStatus.done;

  DownloadEntry? entryOf(String key) => _entries[key];

  // ── Téléchargement verset ─────────────────────────────────────────────────

  Future<void> downloadAyah({
    required int    quranComId,
    required int    surah,
    required int    ayah,
    required String url,
  }) async {
    final key  = ayahKey(quranComId, surah, ayah);
    if (_entries[key]?.status == DownloadStatus.downloading) return;

    final path = await ayahPath(quranComId, surah, ayah);
    await _download(key: key, url: url, localPath: path);
  }

  // ── Téléchargement sourate ────────────────────────────────────────────────

  Future<void> downloadSurah({
    required int    quranComId,
    required int    surah,
    required String url,
  }) async {
    final key  = surahKey(quranComId, surah);
    if (_entries[key]?.status == DownloadStatus.downloading) return;

    final path = await surahPath(quranComId, surah);
    await _download(key: key, url: url, localPath: path);
  }

  // ── Annulation ────────────────────────────────────────────────────────────

  void cancel(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    entry._cancelToken?.cancel('Annulé par utilisateur');
    entry.status   = DownloadStatus.idle;
    entry.progress = 0.0;
    _notifyAndPersist();
  }

  // ── Suppression ───────────────────────────────────────────────────────────

  Future<void> delete(String key) async {
    final entry = _entries.remove(key);
    if (entry != null) {
      try {
        final f = File(entry.localPath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('AudioDownloadManager: erreur suppression $key — $e');
      }
    }
    _notifyAndPersist();
  }

  Future<void> deleteByReciter(int quranComId) async {
    final keys = _entries.keys
        .where((k) => k.startsWith('$quranComId:'))
        .toList();
    for (final k in keys) {
      await delete(k);
    }
  }

  // ── Chemin local si disponible ────────────────────────────────────────────

  /// Retourne le chemin du fichier local si téléchargé et existant.
  /// Nettoie l'état si le fichier a été supprimé manuellement.
  Future<String?> localPathIfAvailable(String key, String localPath) async {
    if (!isDownloaded(key)) return null;
    final f = File(localPath);
    if (await f.exists()) return localPath;
    // Fichier disparu → nettoyage
    _entries.remove(key);
    _notifyAndPersist();
    return null;
  }

  // ── Interne ───────────────────────────────────────────────────────────────

  Future<void> _download({
    required String key,
    required String url,
    required String localPath,
  }) async {
    final cancel = CancelToken();
    final entry  = DownloadEntry(
      key:       key,
      url:       url,
      localPath: localPath,
      status:    DownloadStatus.downloading,
    ).._cancelToken = cancel;

    _entries[key] = entry;
    _notifyAndPersist();

    final tmpPath = '$localPath.part';
    try {
      await _dio.download(
        url,
        tmpPath,
        cancelToken: cancel,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            entry.progress = received / total;
            _notifyOnly();
          }
        },
      );

      // Vérification minimale d'intégrité
      final tmp = File(tmpPath);
      if (!await tmp.exists() || await tmp.length() == 0) {
        throw Exception('Fichier vide ou manquant après téléchargement');
      }

      // Remplacement atomique
      final out = File(localPath);
      if (await out.exists()) await out.delete();
      await tmp.rename(localPath);

      entry.status   = DownloadStatus.done;
      entry.progress = 1.0;
      debugPrint('AudioDownloadManager: ✓ $key → $localPath');

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        entry.status   = DownloadStatus.idle;
        entry.progress = 0.0;
        try { File(tmpPath).deleteSync(); } catch (_) {}
        debugPrint('AudioDownloadManager: annulé $key');
      } else {
        entry.status       = DownloadStatus.failed;
        entry.errorMessage = e.message ?? 'Erreur réseau';
        debugPrint('AudioDownloadManager: erreur $key — $e');
      }
    } catch (e) {
      entry.status       = DownloadStatus.failed;
      entry.errorMessage = e.toString();
      debugPrint('AudioDownloadManager: erreur inattendue $key — $e');
    } finally {
      entry._cancelToken = null;
      _notifyAndPersist();
    }
  }

  // ── Persistance ───────────────────────────────────────────────────────────

  Timer? _persistDebounce;

  void _notifyOnly() {
    entriesNotifier.value = Map.unmodifiable(_entries);
  }

  void _notifyAndPersist() {
    _notifyOnly();
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 2), _saveState);
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json  = prefs.getString(_prefKey);
      if (json == null) return;
      final list = jsonDecode(json) as List<dynamic>;
      for (final item in list) {
        final e = DownloadEntry.fromJson(item as Map<String, dynamic>);
        // Remettre downloading → idle au redémarrage (pas de reprise auto)
        if (e.status == DownloadStatus.downloading) {
          e.status   = DownloadStatus.idle;
          e.progress = 0.0;
        }
        _entries[e.key] = e;
      }
      entriesNotifier.value = Map.unmodifiable(_entries);
    } catch (e) {
      debugPrint('AudioDownloadManager: erreur chargement état — $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list  = _entries.values.map((e) => e.toJson()).toList();
      await prefs.setString(_prefKey, jsonEncode(list));
    } catch (e) {
      debugPrint('AudioDownloadManager: erreur sauvegarde état — $e');
    }
  }
}
