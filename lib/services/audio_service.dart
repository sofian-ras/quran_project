// lib/services/audio_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../surah_name.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioService {
  final ValueNotifier<bool> isFullPlayerOpenNotifier = ValueNotifier<bool>(false);

  AudioService._() {
    _player.setLoopMode(loopModeNotifier.value);

    _player.processingStateStream.listen((state) {
      isBuffering.value =
          state == ProcessingState.buffering || state == ProcessingState.loading;
    });

    // Update title/index for SURAH mode or AYAH mode
    _currentIndexSub = _player.currentIndexStream.listen((index) {
      if (_ayahMode) {
        final seq = _player.sequence;
        if (index == null || index < 0 || seq == null || index >= seq.length) return;

        final tag = seq[index].tag;
        if (tag is String && tag.contains(':')) {
          final parts = tag.split(':');
          final s = int.tryParse(parts[0]);
          final a = int.tryParse(parts[1]);
          if (s != null && a != null) {
            currentPlayingSurahIdNotifier.value = s;
            currentTitleNotifier.value =
                '${surahFr[s] ?? 'Sourate $s'} - $a';
          }
        }
        return;
      }

      // SURAH mode (old behavior)
      final int? surahId = index == null ? null : index + 1;
      currentPlayingSurahIdNotifier.value = surahId;
      if (surahId != null) {
        currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      }
    });
  }

  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool _audioSourceReady = false;

  final ValueNotifier<int?> currentPlayingSurahIdNotifier =
      ValueNotifier<int?>(null);
  StreamSubscription<int?>? _currentIndexSub;

  final ValueNotifier<String> currentTitleNotifier =
      ValueNotifier("Aucune lecture");
  final ValueNotifier<String> currentReciterNotifier =
      ValueNotifier("Abdelrashid as-Soufy");

  final ValueNotifier<bool> isBuffering = ValueNotifier(false);
  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> isShuffleEnabled = ValueNotifier(false);

  String get currentTitle => currentTitleNotifier.value;
  String get currentReciterName => currentReciterNotifier.value;

  int? get currentSurahId =>
      _player.currentIndex == null ? null : _player.currentIndex! + 1;

  List<AudioSource> get playlistSources => _playlist?.children ?? [];
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<bool> get isActiveStream =>
      _player.processingStateStream.map((state) => state != ProcessingState.idle);

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      ).asBroadcastStream();

  // --- SURAH audio server (mp3quran) ---
  String currentServer =
      "https://server16.mp3quran.net/download/soufi/Rewayat-Hafs-A-n-Assem";

  // --- AYAH mode (EveryAyah) ---
  bool _ayahMode = false;

  /// Base EveryAyah (files like 001001.mp3)
  /// You can change this to another folder later.
  String currentAyahServer = 'https://everyayah.com/data/Alafasy_128kbps/';

  // 1) Change reciter for SURAH mode and invalidate playlist
  void setReciter(String name, String server) {
    if (currentReciterNotifier.value != name || currentServer != server) {
      currentReciterNotifier.value = name;
      currentServer = server;
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  // Optional: set ayah reciter folder (EveryAyah)
  void setAyahReciter(String folderName) {
    // Example: Alafasy_128kbps/
    var f = folderName.trim();
    if (f.isEmpty) return;
    if (!f.endsWith('/')) f = '$f/';
    currentAyahServer = 'https://everyayah.com/data/$f';
  }

  Future<void> loadPlaylistAndPlay(int surahId) async {
    _ayahMode = false;
    try {
      if (_playlist == null) {
        _playlist = _createPlaylist();
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

      await play();
    } catch (e) {
      debugPrint("Erreur lors du chargement de la playlist: $e");
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  ConcatenatingAudioSource _createPlaylist() {
    final List<AudioSource> sources = [];
    for (int i = 1; i <= 114; i++) {
      final surahNum = i.toString().padLeft(3, '0');
      final url = '$currentServer/$surahNum.mp3';
      sources.add(AudioSource.uri(Uri.parse(url), tag: i));
    }
    return ConcatenatingAudioSource(children: sources);
  }

  String _ayahFileName(int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$s$a.mp3';
  }

  Uri _ayahUri(int surah, int ayah) {
    final file = _ayahFileName(surah, ayah);
    return Uri.parse('$currentAyahServer$file');
  }

  Future<void> _setAyahSource(List<AudioSource> children,
      {int initialIndex = 0}) async {
    _ayahMode = true;
    _playlist = ConcatenatingAudioSource(children: children);
    _audioSourceReady = false;
    await _player.setAudioSource(_playlist!, initialIndex: initialIndex);
    _audioSourceReady = true;
  }

  /// Play a single ayah (surah:ayah)
  Future<void> playAyah(int surah, int ayah) async {
    try {
      currentPlayingSurahIdNotifier.value = surah;
      currentTitleNotifier.value =
          '${surahFr[surah] ?? 'Sourate $surah'} - $ayah';
      final src = AudioSource.uri(_ayahUri(surah, ayah), tag: '$surah:$ayah');
      await _setAyahSource([src], initialIndex: 0);
      await play();
    } catch (e) {
      debugPrint("Erreur playAyah: $e");
    }
  }

  /// Play a range of ayat (inclusive)
  Future<void> playAyahRange(int surah, int startAyah, int endAyah) async {
    try {
      currentPlayingSurahIdNotifier.value = surah;
      currentTitleNotifier.value =
          '${surahFr[surah] ?? 'Sourate $surah'} - $startAyah..$endAyah';

      final children = <AudioSource>[
        for (int a = startAyah; a <= endAyah; a++)
          AudioSource.uri(_ayahUri(surah, a), tag: '$surah:$a'),
      ];

      await _setAyahSource(children, initialIndex: 0);
      await play();
    } catch (e) {
      debugPrint("Erreur playAyahRange: $e");
    }
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

  Future<void> dispose() async {
    await _currentIndexSub?.cancel();
    _currentIndexSub = null;
    await _player.dispose();
  }
}
