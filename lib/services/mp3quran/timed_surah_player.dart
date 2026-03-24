// lib/services/mp3quran/timed_surah_player.dart
//
// Player seek-based générique pour tout récitateur ayant :
//   - un MP3 de sourate complète sur un serveur HTTP
//   - des timings de versets via l'API mp3quran
//
// Flux de lecture :
//   1. ensureDownloaded()  → télécharge le MP3 complet si absent du cache local
//   2. setAudioSource()    → charge le fichier local dans just_audio
//   3. getAyahTiming()     → récupère start_time / end_time du verset
//   4. seek(start)         → positionne le player
//   5. play()              → lecture
//   6. auto-stop à end     → via positionStream (défaut) ou Timer
//
// Deux modes d'arrêt :
//   TimedStopMode.positionStream  (défaut) — ±200ms, robuste
//   TimedStopMode.timer           — ±50ms, démarre après buffering

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../models/ayah_timing.dart';
import '../../models/reciter_audio_source.dart';
import 'mp3quran_timing_cache.dart';
import 'timed_surah_downloader.dart';

enum TimedStopMode { positionStream, timer }

class TimedSurahPlayer {
  TimedSurahPlayer._() {
    _audio.playerStateStream.listen((state) {
      isPlayingNotifier.value  = state.playing;
      isBufferingNotifier.value =
          state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
    });
  }

  static final TimedSurahPlayer instance = TimedSurahPlayer._();

  final _audio      = AudioPlayer();
  final _cache      = Mp3QuranTimingCache.instance;
  final _downloader = TimedSurahDownloader.instance;

  // ── Notifiers publics ─────────────────────────────────────────────────────

  final ValueNotifier<bool>    isPlayingNotifier   = ValueNotifier(false);
  final ValueNotifier<bool>    isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<bool>    isDownloadingNotifier = ValueNotifier(false);
  final ValueNotifier<int?>    currentAyahNotifier = ValueNotifier(null);
  final ValueNotifier<String?> errorNotifier       = ValueNotifier(null);

  Stream<Duration>  get positionStream => _audio.positionStream;
  Stream<Duration?> get durationStream => _audio.durationStream;
  Duration          get position       => _audio.position;

  // ── État interne ──────────────────────────────────────────────────────────

  ReciterAudioSource? _loadedSource;
  int?                _loadedSurah;
  int                 _token = 0;

  Timer? _stopTimer;
  StreamSubscription<Duration>? _posSub;

  // ── Chargement sourate ────────────────────────────────────────────────────

  Future<void> _ensureLoaded(
    ReciterAudioSource source,
    int surah,
    int token,
  ) async {
    // Déjà chargé
    if (_loadedSource?.localCacheId == source.localCacheId &&
        _loadedSurah == surah) { return; }

    // 1. Télécharger si absent
    isDownloadingNotifier.value = true;
    final String localPath;
    try {
      localPath = await _downloader.ensureDownloaded(source, surah);
    } finally {
      isDownloadingNotifier.value = false;
    }

    if (token != _token) return;

    // 2. Charger dans just_audio depuis le fichier local
    debugPrint('TimedSurahPlayer: chargement local $localPath');
    await _audio.setAudioSource(
      AudioSource.uri(
        Uri.file(localPath),
        tag: MediaItem(
          id: '${source.localCacheId}-$surah',
          title: 'Sourate $surah • ${source.localCacheId}',
          artist: source.localCacheId,
          album: 'Coran',
        ),
      ),
    );

    if (token != _token) return;
    _loadedSource = source;
    _loadedSurah  = surah;
    debugPrint('TimedSurahPlayer: prêt — ${source.localCacheId}/S$surah');
  }

  // ── Arrêt automatique ─────────────────────────────────────────────────────

  void _cancelAutoStop() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _posSub?.cancel();
    _posSub = null;
  }

  void _scheduleStop(Duration end, TimedStopMode mode, int token) {
    _cancelAutoStop();
    if (mode == TimedStopMode.timer) {
      _scheduleTimer(end, token);
    } else {
      _scheduleStream(end, token);
    }
  }

  /// Timer : attend que le player soit en train de jouer, puis lance le timer
  /// depuis la position réelle (pas depuis l'instant du seek).
  void _scheduleTimer(Duration end, int token) {
    StreamSubscription<PlayerState>? stateSub;
    stateSub = _audio.playerStateStream.listen((state) {
      if (token != _token) { stateSub?.cancel(); return; }
      if (state.playing && state.processingState == ProcessingState.ready) {
        stateSub?.cancel();
        final remaining = end - _audio.position;
        if (remaining <= Duration.zero) {
          _audio.pause();
          currentAyahNotifier.value = null;
          return;
        }
        _stopTimer = Timer(remaining, () {
          if (token != _token) return;
          _audio.pause();
          currentAyahNotifier.value = null;
          debugPrint('TimedSurahPlayer [timer]: stop pos=${_audio.position.inMs}ms');
        });
      }
    });
  }

  /// positionStream : surveille la position, pause dès que ≥ end.
  void _scheduleStream(Duration end, int token) {
    _posSub = _audio.positionStream.listen((pos) {
      if (token != _token) { _posSub?.cancel(); return; }
      if (pos >= end) {
        _audio.pause();
        _posSub?.cancel();
        _posSub = null;
        currentAyahNotifier.value = null;
        debugPrint('TimedSurahPlayer [stream]: stop pos=${pos.inMs}ms cible=${end.inMs}ms');
      }
    });
  }

  // ── playAyah ──────────────────────────────────────────────────────────────

  /// Joue un verset unique.
  /// Télécharge la sourate si absente du cache local.
  Future<void> playAyah(
    ReciterAudioSource source,
    int surah,
    int ayah, {
    TimedStopMode stopMode = TimedStopMode.positionStream,
  }) async {
    if (!source.isConfigured) {
      errorNotifier.value =
          'mp3quranReadId non configuré pour ${source.localCacheId}';
      return;
    }

    final token = ++_token;
    _cancelAutoStop();
    errorNotifier.value = null;

    try {
      // Charger sourate + timing en parallèle
      final results = await Future.wait([
        _ensureLoaded(source, surah, token),
        _cache.getAyahTiming(source, surah, ayah),
      ]);
      if (token != _token) return;

      final timing = results[1] as AyahTiming?;
      if (timing == null) {
        errorNotifier.value = 'Timing introuvable : S$surah:$ayah';
        return;
      }

      currentAyahNotifier.value = ayah;
      _scheduleStop(timing.end, stopMode, token);

      await _audio.seek(timing.start);
      if (token != _token) return;

      await _audio.play();
      debugPrint(
        'TimedSurahPlayer: playAyah ${source.localCacheId} '
        'S$surah:$ayah [${timing.start.inMs}ms → ${timing.end.inMs}ms]',
      );
    } catch (e) {
      if (token != _token) return;
      errorNotifier.value = 'Erreur S$surah:$ayah — $e';
      debugPrint('TimedSurahPlayer: $e');
    }
  }

  // ── playAyahRange ─────────────────────────────────────────────────────────

  /// Lecture séquentielle de [fromAyah] à [toAyah] inclus.
  Future<void> playAyahRange(
    ReciterAudioSource source,
    int surah,
    int fromAyah,
    int toAyah, {
    TimedStopMode stopMode = TimedStopMode.positionStream,
  }) async {
    if (!source.isConfigured) {
      errorNotifier.value =
          'mp3quranReadId non configuré pour ${source.localCacheId}';
      return;
    }

    final token = ++_token;
    _cancelAutoStop();
    errorNotifier.value = null;

    try {
      final results = await Future.wait([
        _ensureLoaded(source, surah, token),
        _cache.getTimings(source, surah),
      ]);
      if (token != _token) return;

      final allTimings = results[1] as List<AyahTiming>;
      final range = allTimings
          .where((t) => t.ayah >= fromAyah && t.ayah <= toAyah)
          .toList()
        ..sort((a, b) => a.ayah.compareTo(b.ayah));

      if (range.isEmpty) {
        errorNotifier.value =
            'Aucun timing pour ${source.localCacheId} S$surah:$fromAyah–$toAyah';
        return;
      }

      for (final timing in range) {
        if (token != _token) return;

        currentAyahNotifier.value = timing.ayah;
        await _audio.seek(timing.start);
        if (token != _token) return;

        await _audio.play();
        debugPrint(
          'TimedSurahPlayer: range → ayah=${timing.ayah} '
          '[${timing.start.inMs}ms → ${timing.end.inMs}ms]',
        );

        await _waitUntilEnd(timing.end, stopMode, token);
        if (token != _token) return;

        await _audio.pause();
      }

      currentAyahNotifier.value = null;
    } catch (e) {
      if (token != _token) return;
      errorNotifier.value =
          'Erreur range ${source.localCacheId} S$surah:$fromAyah–$toAyah — $e';
      debugPrint('TimedSurahPlayer: $e');
    }
  }

  Future<void> _waitUntilEnd(
    Duration end,
    TimedStopMode mode,
    int token,
  ) {
    final completer = Completer<void>();
    void done() { if (!completer.isCompleted) completer.complete(); }

    if (mode == TimedStopMode.timer) {
      StreamSubscription<PlayerState>? sub;
      sub = _audio.playerStateStream.listen((state) {
        if (token != _token) { sub?.cancel(); done(); return; }
        if (state.playing && state.processingState == ProcessingState.ready) {
          sub?.cancel();
          final rem = end - _audio.position;
          Timer(rem > Duration.zero ? rem : Duration.zero, done);
        }
      });
    } else {
      StreamSubscription<Duration>? sub;
      sub = _audio.positionStream.listen((pos) {
        if (token != _token || pos >= end) { sub?.cancel(); done(); }
      });
    }

    return completer.future;
  }

  // ── Contrôles ─────────────────────────────────────────────────────────────

  Future<void> pause() async { _cancelAutoStop(); await _audio.pause(); }
  Future<void> resume() async => _audio.play();

  Future<void> stop() async {
    ++_token;
    _cancelAutoStop();
    currentAyahNotifier.value = null;
    await _audio.stop();
    _loadedSource = null;
    _loadedSurah  = null;
  }

  /// Précharge : télécharge la sourate + les timings en arrière-plan.
  void prefetch(ReciterAudioSource source, int surah) {
    if (!source.isConfigured) return;
    _cache.prefetchTimings(source, surah);
    _downloader.ensureDownloaded(source, surah).catchError((Object e) {
      debugPrint('TimedSurahPlayer: prefetch ${source.localCacheId}/$surah — $e');
      return '';
    });
  }

  void dispose() {
    ++_token;
    _cancelAutoStop();
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
