import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';
import '../music_player_fullscreen.dart';


class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  final AudioService _audio = AudioService.instance;

  void _openFullPlayer() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const MusicPlayerFullScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF38C172); // Vert mat

    return GestureDetector(
      onTap: _openFullPlayer,
      child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3D1F), Color(0xFF0F5A2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B3D1F).withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: _audio.currentTitleNotifier,
                          builder: (context, title, _) => Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: _audio.currentReciterNotifier,
                          builder: (context, name, _) => Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                    onPressed: _audio.skipToPrevious,
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _audio.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;
                      
                      if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                        return const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(color: green)));
                      }
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 48),
                        onPressed: _audio.togglePlayPause,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                    onPressed: _audio.skipToNext,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
                    onPressed: () => _audio.stop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildProgressBar(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildProgressBar() {
    const green = Color(0xFF38C172);
    return StreamBuilder<PositionData>(
      stream: _audio.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        final position = positionData?.position ?? Duration.zero;
        final duration = positionData?.duration ?? Duration.zero;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20, // Slider with reduced height
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                ),
                child: Slider(
                  activeColor: green,
                  inactiveColor: Colors.white24,
                  max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                  value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                  onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class GlobalMiniPlayerOverlay extends StatelessWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return StreamBuilder<bool>(
      stream: audio.isActiveStream,
      builder: (context, snapshot) {
        final isActive = snapshot.data ?? false;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: isActive ? 0 : -160,
          left: 0,
          right: 0,
          child: const Material(
            color: Colors.transparent,
            child: MiniAudioPlayer(),
          ),
        );
      },
    );
  }
}
