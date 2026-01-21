import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class BottomAudioBar extends StatefulWidget {
  const BottomAudioBar({super.key});

  @override
  State<BottomAudioBar> createState() => _BottomAudioBarState();
}

class _BottomAudioBarState extends State<BottomAudioBar> {
  final AudioService _audio = AudioService.instance;
  static const gold = Color(0xFFC8A165);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds" 
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D2E), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Indicateur de chargement
              ValueListenableBuilder<bool>(
                valueListenable: _audio.isBuffering,
                builder: (context, loading, _) => loading 
                  ? const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: gold, strokeWidth: 2)))
                  : const SizedBox.shrink(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _audio.currentTitleNotifier,
                      builder: (context, title, _) => Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: _audio.currentReciterNotifier,
                      builder: (context, name, _) => Text(name, style: const TextStyle(color: gold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.stop_rounded, color: Colors.white70), onPressed: () => _audio.stop()),
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: gold, size: 40),
                    onPressed: () => _audio.togglePlayPause(),
                  );
                },
              ),
            ],
          ),
          StreamBuilder<PositionData>(
            stream: _audio.positionDataStream,
            builder: (context, snapshot) {
              final positionData = snapshot.data;
              final position = positionData?.position ?? Duration.zero;
              final duration = positionData?.duration ?? Duration.zero;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                    child: Slider(
                      activeColor: gold,
                      inactiveColor: Colors.white24,
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                      onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        Text(_formatDuration(duration), style: const TextStyle(color: Colors.white60, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}