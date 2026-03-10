// lib/services/audio_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'download_service.dart';

import '../surah_name.dart';
import 'qul_audio/models/qul_reciter.dart';
import 'qul_audio/qul_catalog_service.dart';
import 'qul_audio/qul_audio_resolver.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

enum AyahPlayMode { single, continuous, repeatOne }

class AudioService {
  final ValueNotifier<bool> isFullPlayerOpenNotifier = ValueNotifier<bool>(false);
  /// Mettre à true quand un écran affiche son propre lecteur audio.
  final ValueNotifier<bool> suppressGlobalPlayer = ValueNotifier<bool>(false);

  AudioService._() {
    // Player sourate complète
    _player.setLoopMode(loopModeNotifier.value);

    _player.processingStateStream.listen((state) {
      isBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });

    _currentIndexSub = _player.currentIndexStream.listen((index) {
      final int? surahId = index == null ? null : index + 1;
      currentPlayingSurahIdNotifier.value = surahId;
      if (surahId != null) {
        currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      }
    });

    // Player verset par verset
    _ayahPlayer.processingStateStream.listen((state) {
      isAyahBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });

    _ayahPlayer.playerStateStream.listen((st) {
      isAyahPlayingNotifier.value = st.playing;
    });
    _ayahPlayer.sequenceStateStream.listen((seq) {
      final tag = seq?.currentSource?.tag;
      if (tag is String) {
        currentAyahKeyNotifier.value = tag; // ex: "2:255"
        currentAyahTitleNotifier.value = tag;
      }
    });

    // Vitesse lecture verset
    _ayahPlayer.setSpeed(ayahSpeedNotifier.value);
    ayahSpeedNotifier.addListener(() {
      _ayahPlayer.setSpeed(ayahSpeedNotifier.value);
    });
  }

  static final AudioService instance = AudioService._();

  // =======================
  //  A) Sourate complète
  // =======================
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool _audioSourceReady = false;

  final ValueNotifier<int?> currentPlayingSurahIdNotifier = ValueNotifier<int?>(null);
  StreamSubscription<int?>? _currentIndexSub;

  final ValueNotifier<String> currentTitleNotifier = ValueNotifier("Aucune lecture");
  final ValueNotifier<String> currentReciterNotifier = ValueNotifier("Abdelrashid as-Soufy");
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> isShuffleEnabled = ValueNotifier(false);

  String get currentTitle => currentTitleNotifier.value;
  String get currentReciterName => currentReciterNotifier.value;

  int? get currentSurahId => _player.currentIndex == null ? null : _player.currentIndex! + 1;

  List<AudioSource> get playlistSources => _playlist?.children ?? [];
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  // Serveur par défaut mp3quran.net (lecture sourate complète)
  String currentServer = "https://server16.mp3quran.net/download/soufi/Rewayat-Hafs-A-n-Assem";

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<bool> get isActiveStream => _player.processingStateStream.map((state) => state != ProcessingState.idle);

  Stream<PositionData> get positionDataStream => Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      ).asBroadcastStream();

  void setReciter(String name, String server) {
    if (currentReciterNotifier.value != name || currentServer != server) {
      currentReciterNotifier.value = name;
      currentServer = server;
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  Future<void> loadPlaylistAndPlay(int surahId) async {
    try {
      if (_playlist == null) {
        _playlist = await _createPlaylist();
        _audioSourceReady = false;
      }

      currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      final targetIndex = surahId - 1;

      if (!_audioSourceReady || _player.audioSource == null) {
        await _player.setAudioSource(_playlist!, initialIndex: targetIndex);
        _audioSourceReady = true;
      } else {
        await _player.seek(Duration.zero, index: targetIndex);
      }

      play();
    } catch (e) {
      debugPrint("Erreur lors du chargement de la playlist: $e");
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  Future<ConcatenatingAudioSource> _createPlaylist() async {
    final ds      = DownloadService.instance;
    final base    = currentServer.endsWith('/') ? currentServer : '$currentServer/';
    final reciter = currentReciterNotifier.value;
    final sources = <AudioSource>[];
    for (int i = 1; i <= 114; i++) {
      final surahNum = i.toString().padLeft(3, '0');
      final url      = '$base$surahNum.mp3';
      final tag = MediaItem(
        id:     url,
        title:  surahFr[i] ?? 'Sourate $i',
        artist: reciter,
        album:  'Coran',
      );
      final localPath = await ds.quranAudioFilePath(currentServer, i);
      if (await File(localPath).exists()) {
        sources.add(AudioSource.uri(Uri.file(localPath), tag: tag));
      } else {
        sources.add(AudioSource.uri(Uri.parse(url), tag: tag));
      }
    }
    return ConcatenatingAudioSource(children: sources);
  }

  /// Remplace la source d'une sourate par un fichier local (sans interrompre la lecture).
  Future<void> updateSurahSource(int surahId, String localPath) async {
    if (_playlist == null) return;
    final index = surahId - 1;
    if (index < 0 || index >= _playlist!.length) return;
    // Ne pas remplacer la source en cours de lecture
    if (_player.currentIndex == index && _player.playing) return;
    await _playlist!.removeAt(index);
    await _playlist!.insert(index, AudioSource.uri(Uri.file(localPath), tag: MediaItem(
      id:     localPath,
      title:  surahFr[surahId] ?? 'Sourate $surahId',
      artist: currentReciterNotifier.value,
      album:  'Coran',
    )));
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToIndex(int index) => _player.seek(Duration.zero, index: index);

  Future<void> skipToPrevious() => _player.seekToPrevious();
  Future<void> skipToNext() => _player.seekToNext();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void cycleLoopMode() {
    final currentMode = loopModeNotifier.value;
    LoopMode newMode;
    if (currentMode == LoopMode.off) {
      newMode = LoopMode.one;
    } else if (currentMode == LoopMode.one) {
      newMode = LoopMode.all;
    } else {
      newMode = LoopMode.off;
    }
    loopModeNotifier.value = newMode;
    _player.setLoopMode(newMode);
  }

  Future<void> toggleShuffle() async {
    final newShuffleState = !isShuffleEnabled.value;
    isShuffleEnabled.value = newShuffleState;
    await _player.setShuffleModeEnabled(newShuffleState);
  }

  // =======================
  //  B) Verset par verset
  // =======================

  /// Récitateurs disponibles sur QUL.
  static List<QulReciter> get ayahReciters => QulCatalogService.instance.available;

  final ValueNotifier<QulReciter> currentAyahReciterNotifier =
      ValueNotifier<QulReciter>(QulCatalogService.instance.available.first);
  final AudioPlayer _ayahPlayer = AudioPlayer();
  final ValueNotifier<bool> isAyahBuffering = ValueNotifier(false);
  final ValueNotifier<String> currentAyahTitleNotifier = ValueNotifier("Aucun verset");

  final ValueNotifier<double> ayahSpeedNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<Duration> ayahAutoNextDelayNotifier = ValueNotifier<Duration>(Duration.zero);

  final ValueNotifier<String?> currentAyahKeyNotifier = ValueNotifier<String?>(null); // "2:255"
  final ValueNotifier<bool> isAyahPlayingNotifier = ValueNotifier(false);

  final ValueNotifier<AyahPlayMode> ayahPlayModeNotifier = ValueNotifier(AyahPlayMode.single);

  Stream<PlayerState> get ayahPlayerStateStream => _ayahPlayer.playerStateStream;

  Stream<PositionData> get ayahPositionDataStream => Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _ayahPlayer.positionStream,
        _ayahPlayer.bufferedPositionStream,
        _ayahPlayer.durationStream,
        (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      ).asBroadcastStream();

  Stream<bool> get isAyahActiveStream => _ayahPlayer.processingStateStream.map((state) => state != ProcessingState.idle);

  void setAyahReciter(QulReciter reciter) {
    currentAyahReciterNotifier.value = reciter;
  }

  StreamSubscription<PlayerState>? _ayahSeqSub;
  int? _seqSurah;
  int? _seqAyah;
  int? _seqEndAyah;

  Future<void> stopAyah() async {
    // Invalide tout _playAyahInternal en cours d'attente async.
    _ayahPlayToken++;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;
    _seqSurah = null;
    _seqAyah = null;
    _seqEndAyah = null;

    ayahPlayModeNotifier.value = AyahPlayMode.single;
    currentAyahKeyNotifier.value = null;

    await _ayahPlayer.setLoopMode(LoopMode.off);
    await _ayahPlayer.stop();
  }

  Future<void> pauseAyah() async => _ayahPlayer.pause();

  Future<void> resumeAyah() async {
    if (!_ayahPlayer.playing) {
      await _ayahPlayer.play();
    }
  }

  Future<void> toggleAyahPlayPause() async {
    if (_ayahPlayer.playing) {
      await _ayahPlayer.pause();
    } else {
      await _ayahPlayer.play();
    }
  }

  Future<void> seekAyah(Duration position) async => _ayahPlayer.seek(position);

  void setAyahSpeed(double speed) {
    ayahSpeedNotifier.value = speed.clamp(0.5, 2.0);
  }

  /// Lecture d’un seul verset (reset séquence)
  Future<void> playAyah(int surah, int ayah) async {
    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;
    _seqSurah = null;
    _seqAyah = null;
    _seqEndAyah = null;

    final mode = ayahPlayModeNotifier.value;
    await _ayahPlayer.setLoopMode(
      mode == AyahPlayMode.repeatOne ? LoopMode.one : LoopMode.off,
    );

    await _playAyahInternal(surah, ayah);
  }

  Future<void> playAyahRepeatOne(int surah, int ayah) async {
    ayahPlayModeNotifier.value = AyahPlayMode.repeatOne;
    await playAyah(surah, ayah);
  }

  /// Lecture verset par verset (range) : start -> end, séquentielle.
  Future<void> playAyahRange({
    required int surah,
    required int startAyah,
    required int endAyah,
  }) async {
    if (endAyah < startAyah) return;

    ayahPlayModeNotifier.value = AyahPlayMode.continuous;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah  = startAyah;
    _seqEndAyah = endAyah;

    await _ayahPlayer.setLoopMode(LoopMode.off);
    await _playAyahInternal(surah, startAyah);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState != ProcessingState.completed) return;
      if (_seqSurah == null || _seqAyah == null || _seqEndAyah == null) return;

      final next = _seqAyah! + 1;
      if (next > _seqEndAyah!) {
        await _ayahSeqSub?.cancel();
        _ayahSeqSub = null;
        _seqSurah = null;
        _seqAyah  = null;
        _seqEndAyah = null;
        ayahPlayModeNotifier.value = AyahPlayMode.single;
        return;
      }

      _seqAyah = next;
      try {
        final delay = ayahAutoNextDelayNotifier.value;
        if (delay > Duration.zero) await Future.delayed(delay);
        await _playAyahInternal(surah, next);
      } catch (_) {}
    });
  }

  /// Range en boucle : revient au start à la fin (∞ sur la plage), séquentielle.
  Future<void> playAyahRangeLoop({
    required int surah,
    required int startAyah,
    required int endAyah,
  }) async {
    if (endAyah < startAyah) return;

    ayahPlayModeNotifier.value = AyahPlayMode.continuous;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah  = startAyah;
    _seqEndAyah = endAyah;

    await _ayahPlayer.setLoopMode(LoopMode.off);
    await _playAyahInternal(surah, startAyah);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState != ProcessingState.completed) return;
      if (_seqSurah == null || _seqAyah == null || _seqEndAyah == null) return;

      var next = _seqAyah! + 1;
      if (next > _seqEndAyah!) next = startAyah; // boucle

      _seqAyah = next;
      try {
        final delay = ayahAutoNextDelayNotifier.value;
        if (delay > Duration.zero) await Future.delayed(delay);
        await _playAyahInternal(surah, next);
      } catch (_) {}
    });
  }

  /// Répéter un verset N fois (N>=1). Pour ∞, utiliser playAyahRepeatOne().
  Future<void> playAyahRepeatTimes(int surah, int ayah, int times) async {
    if (times <= 1) {
      ayahPlayModeNotifier.value = AyahPlayMode.single;
      await playAyah(surah, ayah);
      return;
    }

    ayahPlayModeNotifier.value = AyahPlayMode.single;
    await _ayahPlayer.setLoopMode(LoopMode.off);

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah = ayah;
    _seqEndAyah = ayah;

    var remaining = times;

    await _playAyahInternal(surah, ayah);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState == ProcessingState.completed) {
        remaining -= 1;
        if (remaining <= 0) {
          await _ayahSeqSub?.cancel();
          _ayahSeqSub = null;
          _seqSurah = null;
          _seqAyah = null;
          _seqEndAyah = null;
          ayahPlayModeNotifier.value = AyahPlayMode.single;
          return;
        }

        try {
          final delay = ayahAutoNextDelayNotifier.value;
          if (delay > Duration.zero) await Future.delayed(delay);
          await _playAyahInternal(surah, ayah);
        } catch (_) {}
      }
    });
  }

  /// Répéter une plage [start..end] N fois.
  /// - times == -1 : boucle infinie (équivalent playAyahRangeLoop)
  Future<void> playAyahRangeRepeatTimes({
    required int surah,
    required int startAyah,
    required int endAyah,
    required int times,
  }) async {
    if (endAyah < startAyah) return;
    if (times == -1) {
      await playAyahRangeLoop(surah: surah, startAyah: startAyah, endAyah: endAyah);
      return;
    }
    if (times <= 1) {
      await playAyahRange(surah: surah, startAyah: startAyah, endAyah: endAyah);
      return;
    }

    ayahPlayModeNotifier.value = AyahPlayMode.continuous;
    await _ayahPlayer.setLoopMode(LoopMode.off);

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah = startAyah;
    _seqEndAyah = endAyah;

    int remainingRanges = times;

    await _playAyahInternal(surah, startAyah);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState == ProcessingState.completed) {
        if (_seqSurah == null || _seqAyah == null || _seqEndAyah == null) return;

        var next = (_seqAyah ?? startAyah) + 1;

        if (next > (_seqEndAyah ?? endAyah)) {
          remainingRanges -= 1;
          if (remainingRanges <= 0) {
            await _ayahSeqSub?.cancel();
            _ayahSeqSub = null;
            _seqSurah = null;
            _seqAyah = null;
            _seqEndAyah = null;
            ayahPlayModeNotifier.value = AyahPlayMode.single;
            return;
          }
          next = startAyah;
        }

        _seqAyah = next;

        try {
          final delay = ayahAutoNextDelayNotifier.value;
          if (delay > Duration.zero) await Future.delayed(delay);
          await _playAyahInternal(surah, next);
        } catch (_) {}
      }
    });
  }

  /// Répéter chaque ayah de la plage N fois (1..25).
  /// Exemple: timesEach=3 => ayah1 x3 puis ayah2 x3 ...
  Future<void> playAyahRangeEachAyahRepeatTimes({
    required int surah,
    required int startAyah,
    required int endAyah,
    required int timesEach,
  }) async {
    if (endAyah < startAyah) return;
    if (timesEach <= 1) {
      await playAyahRange(surah: surah, startAyah: startAyah, endAyah: endAyah);
      return;
    }

    ayahPlayModeNotifier.value = AyahPlayMode.continuous;
    await _ayahPlayer.setLoopMode(LoopMode.off);

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah = startAyah;
    _seqEndAyah = endAyah;

    int current = startAyah;
    int remainingForCurrent = timesEach;

    await _playAyahInternal(surah, current);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState == ProcessingState.completed) {
        if (_seqSurah == null || _seqAyah == null || _seqEndAyah == null) return;

        remainingForCurrent -= 1;
        if (remainingForCurrent > 0) {
          try {
            final delay = ayahAutoNextDelayNotifier.value;
            if (delay > Duration.zero) await Future.delayed(delay);
            await _playAyahInternal(surah, current);
          } catch (_) {}
          return;
        }

        // passer au suivant
        current += 1;
        if (current > endAyah) {
          await _ayahSeqSub?.cancel();
          _ayahSeqSub = null;
          _seqSurah = null;
          _seqAyah = null;
          _seqEndAyah = null;
          ayahPlayModeNotifier.value = AyahPlayMode.single;
          return;
        }

        _seqAyah = current;
        remainingForCurrent = timesEach;

        try {
          final delay = ayahAutoNextDelayNotifier.value;
          if (delay > Duration.zero) await Future.delayed(delay);
          await _playAyahInternal(surah, current);
        } catch (_) {}
      }
    });
  }

  // Génération courante — s'incrémente à chaque nouvel appel.
  // Permet d'annuler silencieusement tout appel obsolète après un await.
  int _ayahPlayToken = 0;

  Future<void> _playAyahInternal(int surah, int ayah) async {
    final myToken = ++_ayahPlayToken;

    try {
      final reciter = currentAyahReciterNotifier.value;
      final url = await QulAudioResolver.instance.resolveAyah(reciter, surah, ayah);

      // Un appel plus récent a démarré → on abandonne celui-ci.
      if (myToken != _ayahPlayToken || _disposed) return;
      if (url == null) return;

      currentAyahKeyNotifier.value = '$surah:$ayah';
      currentAyahTitleNotifier.value =
          'S${surah.toString().padLeft(3, '0')}:${ayah.toString().padLeft(3, '0')} • ${reciter.displayName}';

      // Stop uniquement si le player est actif (loading/buffering/ready).
      // Si déjà en completed/idle, on évite le stop() pour réduire la latence
      // entre versets lors de la lecture séquentielle.
      final ps = _ayahPlayer.processingState;
      if (ps != ProcessingState.completed && ps != ProcessingState.idle) {
        await _ayahPlayer.stop();
        if (myToken != _ayahPlayToken) return;
      }

      // just_audio_background exige un MediaItem tag sur chaque AudioSource.
      await _ayahPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: '$surah:$ayah',
            title: 'Sourate $surah · Verset $ayah',
            artist: reciter.displayName,
            album: 'Coran',
          ),
        ),
      );
      if (myToken != _ayahPlayToken) return;

      await _ayahPlayer.play();
    } catch (e) {
      debugPrint('Erreur audio (_playAyahInternal): $e');
    }
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _currentIndexSub?.cancel();
    _currentIndexSub = null;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    await _player.dispose();
    await _ayahPlayer.dispose();
  }
}