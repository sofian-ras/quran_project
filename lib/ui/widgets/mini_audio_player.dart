import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';

class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  final AudioService _audio = AudioService.instance;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);
    const darkGreen = Color(0xFF0B3D2E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen, Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -2),
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
                      builder: (context, name, _) => Text(name, style: const TextStyle(color: gold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 32),
                onPressed: _audio.skipToPrevious,
              ),
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;
                  
                  if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                    return const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(color: gold)));
                  }
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: gold, size: 48),
                    onPressed: _audio.togglePlayPause,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white70, size: 32),
                onPressed: _audio.skipToNext,
              ),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70, size: 28),
                onPressed: () => _audio.stop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildProgressBar(),
        ],
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
    const gold = Color(0xFFC8A165);
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
                  activeColor: gold,
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
