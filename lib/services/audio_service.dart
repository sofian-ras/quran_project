import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioService {
  AudioService._() {
    // Écouter l'état du lecteur pour le chargement
    _player.processingStateStream.listen((state) {
      isBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });
  }
  static final AudioService instance = AudioService._();
  
  final AudioPlayer _player = AudioPlayer();
  
  // Notifiers pour mise à jour automatique de l'UI
  final ValueNotifier<String> currentTitleNotifier = ValueNotifier("Aucune lecture");
  final ValueNotifier<String> currentReciterNotifier = ValueNotifier("Mishari Alafasy");
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);
  
  // Getters simples pour compatibilité avec ton code existant
  String get currentTitle => currentTitleNotifier.value;
  set currentTitle(String val) => currentTitleNotifier.value = val;

  String get currentReciterName => currentReciterNotifier.value;
  set currentReciterName(String val) => currentReciterNotifier.value = val;

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
      );

  Future<void> setUrl(String url) async {
    try {
      await _player.setUrl(url);
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'URL audio: $e");
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> dispose() => _player.dispose();
}