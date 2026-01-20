import 'package:just_audio/just_audio.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;

  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
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
