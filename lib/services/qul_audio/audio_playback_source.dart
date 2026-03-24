// lib/services/qul_audio/audio_playback_source.dart
//
// Sélecteur de source audio : local (offline) en priorité, sinon distant (QUL).
//
// Logique :
//   1. Fichier local téléchargé → lecture offline
//   2. URL distante résolue via QUL → streaming
//   3. Aucune des deux → null (indisponible)

import 'models/qul_reciter.dart';
import 'qul_audio_resolver.dart';
import 'audio_download_manager.dart';

class PlaybackSource {
  final String url;
  final bool isLocal;
  const PlaybackSource({required this.url, required this.isLocal});
}

class AudioPlaybackSource {
  AudioPlaybackSource._();
  static final AudioPlaybackSource instance = AudioPlaybackSource._();

  final _resolver  = QulAudioResolver.instance;
  final _dlManager = AudioDownloadManager.instance;

  // ── Verset ────────────────────────────────────────────────────────────────

  /// Retourne la meilleure source pour un verset :
  /// fichier local → URL distante QUL/mp3quran → null (indisponible)
  Future<PlaybackSource?> forAyah(QulReciter reciter, int surah, int ayah) async {
    if (!reciter.isAvailable) return null;

    // Récitateur everyayah direct : URL construite sans cache local
    if (reciter.isEveryayah) {
      final remote = await _resolver.resolveAyah(reciter, surah, ayah);
      return remote != null ? PlaybackSource(url: remote, isLocal: false) : null;
    }

    final qid = reciter.quranComId!;

    // 1. Fichier local disponible ?
    final key   = AudioDownloadManager.ayahKey(qid, surah, ayah);
    final path  = await _dlManager.ayahPath(qid, surah, ayah);
    final local = await _dlManager.localPathIfAvailable(key, path);
    if (local != null) {
      return PlaybackSource(url: Uri.file(local).toString(), isLocal: true);
    }

    // 2. URL distante QUL
    final remote = await _resolver.resolveAyah(reciter, surah, ayah);
    if (remote != null) {
      return PlaybackSource(url: remote, isLocal: false);
    }

    // 3. Indisponible
    return null;
  }

  // ── Sourate ───────────────────────────────────────────────────────────────

  /// Retourne la meilleure source pour une sourate complète.
  Future<PlaybackSource?> forSurah(QulReciter reciter, int surah) async {
    if (!reciter.isAvailable || reciter.isEveryayah) return null;
    final qid = reciter.quranComId!;

    // 1. Fichier local disponible ?
    final key   = AudioDownloadManager.surahKey(qid, surah);
    final path  = await _dlManager.surahPath(qid, surah);
    final local = await _dlManager.localPathIfAvailable(key, path);
    if (local != null) {
      return PlaybackSource(url: Uri.file(local).toString(), isLocal: true);
    }

    // 2. URL distante
    final remote = await _resolver.resolveSurah(reciter, surah);
    if (remote != null) {
      return PlaybackSource(url: remote, isLocal: false);
    }

    return null;
  }
}
