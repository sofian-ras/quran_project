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
  AudioService._() {
    _player.setLoopMode(loopModeNotifier.value);
    _player.processingStateStream.listen((state) {
      isBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });

    // Écouter les changements de piste pour mettre à jour le titre
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        final surahId = index + 1;
        currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      }
    });
  }

  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlist;

  final ValueNotifier<String> currentTitleNotifier = ValueNotifier("Aucune lecture");
  final ValueNotifier<String> currentReciterNotifier = ValueNotifier("Mishari Alafasy");
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);
  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);

  String get currentTitle => currentTitleNotifier.value;
  String get currentReciterName => currentReciterNotifier.value;
  int? get currentSurahId => _player.currentIndex == null ? null : _player.currentIndex! + 1;
  List<AudioSource> get playlistSources => _playlist?.children ?? [];
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  
  set currentReciterName(String val) {
     if(currentReciterNotifier.value != val) {
        currentReciterNotifier.value = val;
        // Invalider la playlist pour qu'elle soit regénérée avec le nouveau récitateur
        _playlist = null; 
     }
  }

  String currentServer = "https://download.quranicaudio.com/quran/mishari_rashid_alafasy";

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get isActiveStream => _player.processingStateStream.map((state) => state != ProcessingState.idle);

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

  Future<void> loadPlaylistAndPlay(int surahId) async {
    try {
      // Si la playlist n'existe pas (premier lancement ou changement de récitateur), on la crée.
      if (_playlist == null) {
        final List<AudioSource> sources = [];
        for (int i = 1; i <= 114; i++) {
          final surahNum = i.toString().padLeft(3, '0');
          final url = '$currentServer/$surahNum.mp3';
          sources.add(AudioSource.uri(Uri.parse(url), tag: i));
        }
        _playlist = ConcatenatingAudioSource(children: sources);
      }
      
      await _player.setAudioSource(
        _playlist!,
        initialIndex: surahId - 1, // L'index est 0-based
      );
      play();
    } catch (e) {
      debugPrint("Erreur lors du chargement de la playlist: $e");
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

  Future<void> dispose() => _player.dispose();

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
}