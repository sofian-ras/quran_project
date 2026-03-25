// lib/services/mp3quran/timed_surah_player.dart
//
// Player seek-based — lecture continue d'une sourate complète.
//
// Architecture (calquée sur Quran Android) :
//   1. ensureLoaded()       → télécharge le MP3 complet si absent
//   2. play(from, to)       → charge timings + seek vers fromAyah + lance
//   3. positionStream poll  → _ayahAt(pos) retourne l'ayah courant
//   4. currentAyahNotifier  → notifie l'UI de chaque changement d'ayah
//   5. auto-pause           → quand pos ≥ fin du dernier ayah demandé
//
// Contrairement à l'ancienne approche (ayah-par-ayah avec seek/stop en boucle),
// le MP3 joue en continu ; les transitions entre versets sont instantanées.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../models/ayah_timing.dart';
import '../../models/reciter_audio_source.dart';
import 'mp3quran_timing_cache.dart';
import 'timed_surah_downloader.dart';

class TimedSurahPlayer {
  TimedSurahPlayer._() {
    _audio.playerStateStream.listen((state) {
      isPlayingNotifier.value   = state.playing;
      isBufferingNotifier.value =
          state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      // Fin naturelle du fichier (pas via auto-pause interne)
      if (state.processingState == ProcessingState.completed) {
        _cancelPositionSub();
        currentAyahNotifier.value = null;
      }
    });
  }

  static final TimedSurahPlayer instance = TimedSurahPlayer._();

  final _audio      = AudioPlayer();
  final _cache      = Mp3QuranTimingCache.instance;
  final _downloader = TimedSurahDownloader.instance;

  // ── Notifiers publics ─────────────────────────────────────────────────────

  final ValueNotifier<bool>    isPlayingNotifier     = ValueNotifier(false);
  final ValueNotifier<bool>    isBufferingNotifier   = ValueNotifier(false);
  final ValueNotifier<bool>    isDownloadingNotifier = ValueNotifier(false);
  final ValueNotifier<int?>    currentAyahNotifier   = ValueNotifier(null);
  final ValueNotifier<String?> errorNotifier         = ValueNotifier(null);

  Stream<Duration>  get positionStream => _audio.positionStream;
  Stream<Duration?> get durationStream => _audio.durationStream;
  Duration          get position       => _audio.position;

  // ── État interne ──────────────────────────────────────────────────────────

  ReciterAudioSource? _loadedSource;
  int?                _loadedSurah;
  int                 _token = 0;

  List<AyahTiming>              _timings = [];
  Duration?                     _stopAt;   // fin du dernier ayah demandé
  StreamSubscription<Duration>? _posSub;

  // ── Chargement sourate ────────────────────────────────────────────────────

  Future<void> _ensureLoaded(
    ReciterAudioSource source,
    int surah,
    int token,
  ) async {
    if (_loadedSource?.localCacheId == source.localCacheId &&
        _loadedSurah == surah) { return; }

    isDownloadingNotifier.value = true;
    final String localPath;
    try {
      localPath = await _downloader.ensureDownloaded(source, surah);
    } finally {
      isDownloadingNotifier.value = false;
    }
    if (token != _token) return;

    debugPrint('TimedSurahPlayer: chargement $localPath');
    await _audio.setAudioSource(
      AudioSource.uri(
        Uri.file(localPath),
        tag: MediaItem(
          id:     '${source.localCacheId}-$surah',
          title:  'Sourate $surah • ${source.localCacheId}',
          artist: source.localCacheId,
          album:  'Coran',
        ),
      ),
    );
    if (token != _token) return;
    _loadedSource = source;
    _loadedSurah  = surah;
    debugPrint('TimedSurahPlayer: prêt — ${source.localCacheId}/S$surah');
  }

  // ── Surveillance de position ──────────────────────────────────────────────

  void _cancelPositionSub() {
    _posSub?.cancel();
    _posSub = null;
  }

  /// Retourne l'ayah dont la plage [start, end[ contient [pos].
  int? _ayahAt(Duration pos) {
    for (final t in _timings) {
      if (pos >= t.start && pos < t.end) return t.ayah;
    }
    return null;
  }

  void _startPositionSub(int token) {
    _cancelPositionSub();
    _posSub = _audio.positionStream.listen((pos) {
      if (token != _token) { _cancelPositionSub(); return; }

      // Mise à jour de l'ayah courant
      final ayah = _ayahAt(pos);
      if (ayah != currentAyahNotifier.value) {
        currentAyahNotifier.value = ayah;
      }

      // Auto-pause quand on dépasse la fin du dernier ayah demandé
      if (_stopAt != null && pos >= _stopAt!) {
        _audio.pause();
        _cancelPositionSub();
        currentAyahNotifier.value = null;
        debugPrint('TimedSurahPlayer: auto-stop pos=${pos.inMs}ms cible=${_stopAt!.inMs}ms');
      }
    });
  }

  // ── play ──────────────────────────────────────────────────────────────────

  /// Lecture continue de [fromAyah] à [toAyah] inclus.
  /// Si [toAyah] est null : joue jusqu'à la fin naturelle de la sourate.
  Future<void> play(
    ReciterAudioSource source,
    int surah,
    int fromAyah, {
    int? toAyah,
  }) async {
    if (!source.isConfigured) {
      errorNotifier.value =
          'mp3quranReadId non configuré pour ${source.localCacheId}';
      return;
    }

    final token = ++_token;
    _cancelPositionSub();
    // Reset pour éviter qu'une ancienne valeur soit combinée avec le nouveau surah
    currentAyahNotifier.value = null;
    errorNotifier.value       = null;

    try {
      final results = await Future.wait([
        _ensureLoaded(source, surah, token),
        _cache.getTimings(source, surah),
      ]);
      if (token != _token) return;

      _timings = results[1] as List<AyahTiming>;

      // Position de départ
      final startTiming = _timings.cast<AyahTiming?>()
          .firstWhere((t) => t!.ayah == fromAyah, orElse: () => null);
      if (startTiming == null) {
        errorNotifier.value = 'Timing introuvable : S$surah:$fromAyah';
        return;
      }

      // Position d'arrêt (fin du dernier ayah demandé + 400 ms de marge)
      // La marge évite de couper les dernières syllabes du mot.
      if (toAyah != null) {
        final stopTiming = _timings.cast<AyahTiming?>()
            .firstWhere((t) => t!.ayah == toAyah, orElse: () => null);
        _stopAt = stopTiming == null ? null : stopTiming.end + const Duration(milliseconds: 400);
      } else {
        _stopAt = null;
      }

      // Si on commence au verset 1, partir du début du fichier pour inclure
      // la Basmalah introductive (ayah 0) qui précède le premier verset.
      final seekTo = (fromAyah == 1) ? Duration.zero : startTiming.start;

      // Seek d'abord : on démarre la surveillance APRÈS pour que le premier
      // tick du positionStream reflète la position réelle (pas l'ancienne).
      await _audio.seek(seekTo);
      if (token != _token) return;

      _startPositionSub(token);
      await _audio.play();
      debugPrint(
        'TimedSurahPlayer: play ${source.localCacheId} S$surah '
        '$fromAyah→${toAyah ?? "fin"} depuis ${startTiming.start.inMs}ms',
      );
    } catch (e) {
      if (token != _token) return;
      errorNotifier.value = 'Erreur S$surah — $e';
      debugPrint('TimedSurahPlayer: $e');
    }
  }

  // ── Contrôles ─────────────────────────────────────────────────────────────

  /// Pause : conserve l'ayah courant dans le notifier (highlight visible).
  Future<void> pause() async {
    await _audio.pause();
    // Pas de reset de currentAyahNotifier : le highlight reste visible en pause
    // Pas de cancel du _posSub : il ne retourne rien tant que l'audio est en pause
  }

  /// Reprend la lecture depuis la position actuelle.
  Future<void> resume() async {
    await _audio.play();
    // _posSub est déjà actif — reprend immédiatement la surveillance
  }

  Future<void> stop() async {
    ++_token;
    _cancelPositionSub();
    _timings = [];
    _stopAt  = null;
    currentAyahNotifier.value = null;
    await _audio.stop();
    _loadedSource = null;
    _loadedSurah  = null;
  }

  /// Précharge en arrière-plan : MP3 + timings.
  void prefetch(ReciterAudioSource source, int surah) {
    if (!source.isConfigured) return;
    _cache.prefetchTimings(source, surah);
    _downloader.ensureDownloaded(source, surah).catchError((Object e) {
      debugPrint('TimedSurahPlayer: prefetch error — $e');
      return '';
    });
  }

  void dispose() {
    ++_token;
    _cancelPositionSub();
    _audio.dispose();
    isPlayingNotifier.dispose();
    isBufferingNotifier.dispose();
    isDownloadingNotifier.dispose();
    currentAyahNotifier.dispose();
    errorNotifier.dispose();
  }
}

extension on Duration {
  int get inMs => inMilliseconds;
}
