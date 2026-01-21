import 'package:just_audio/just_audio.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();
  final AudioPlayer _player = AudioPlayer();

  // --- LA LIGNE À AJOUTER EST ICI ---
  String currentTitle = "Aucune lecture"; 

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;

  Future<void> setUrl(String url) async {
    try {
      await _player.setUrl(url);
    } catch (e) {
      print("Erreur lors du chargement de l'URL audio: $e");
    }
  }


  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> dispose() => _player.dispose();
}