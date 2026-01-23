import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';

class PlayerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> surahList;
  final Map<String, dynamic> currentSurah;
  final VoidCallback onReciterChangeRequested;
  final Function(Map<String, dynamic>) onSurahChange;

  const PlayerBottomSheet({
    super.key,
    required this.surahList,
    required this.currentSurah,
    required this.onReciterChangeRequested,
    required this.onSurahChange,
  });

  @override
  State<PlayerBottomSheet> createState() => _PlayerBottomSheetState();
}

class _PlayerBottomSheetState extends State<PlayerBottomSheet> {
  final AudioService _audio = AudioService.instance;
  late Map<String, dynamic> _currentSurah;

  @override
  void initState() {
    super.initState();
    _currentSurah = widget.currentSurah;
    // Listen for title changes from the service to update the current surah
    _audio.currentTitleNotifier.addListener(_updateCurrentSurahFromTitle);
  }

  @override
  void dispose() {
    _audio.currentTitleNotifier.removeListener(_updateCurrentSurahFromTitle);
    super.dispose();
  }

  void _updateCurrentSurahFromTitle() {
    final newTitle = _audio.currentTitle;
    final newSurah = widget.surahList.firstWhere(
      (s) => s['nameFr'] == newTitle,
      orElse: () => _currentSurah,
    );
    if (newSurah['id'] != _currentSurah['id']) {
      setState(() {
        _currentSurah = newSurah;
      });
    }
  }

  void _playNext() {
    final currentIndex = widget.surahList.indexWhere((s) => s['id'] == _currentSurah['id']);
    if (currentIndex < widget.surahList.length - 1) {
      final nextSurah = widget.surahList[currentIndex + 1];
      widget.onSurahChange(nextSurah);
    }
  }

  void _playPrevious() {
    final currentIndex = widget.surahList.indexWhere((s) => s['id'] == _currentSurah['id']);
    if (currentIndex > 0) {
      final prevSurah = widget.surahList[currentIndex - 1];
      widget.onSurahChange(prevSurah);
    }
  }

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
    const gold = Color(0xFFC8A165);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B3D2E), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Surah Info
          ValueListenableBuilder<String>(
            valueListenable: _audio.currentTitleNotifier,
            builder: (context, title, _) => Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _audio.currentReciterNotifier,
            builder: (context, name, _) => Text(name, style: const TextStyle(color: gold, fontSize: 14)),
          ),
          const SizedBox(height: 10),
          // Slider and duration
          StreamBuilder<PositionData>(
            stream: _audio.positionDataStream,
            builder: (context, snapshot) {
              final positionData = snapshot.data;
              final position = positionData?.position ?? Duration.zero;
              final duration = positionData?.duration ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    activeColor: gold,
                    inactiveColor: Colors.white24,
                    max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                    value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                    onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
          ),
          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32), onPressed: _playPrevious),
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;
                  
                  if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                    return const SizedBox(width: 64, height: 64, child: Center(child: CircularProgressIndicator(color: gold)));
                  }
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: gold, size: 64),
                    onPressed: _audio.togglePlayPause,
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 32), onPressed: _playNext),
            ],
          ),
          const SizedBox(height: 10),
          // Additional Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.mic, color: Colors.white70),
                label: const Text("Récitant", style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  Navigator.pop(context); // Close sheet before opening another
                  widget.onReciterChangeRequested();
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70),
                label: const Text("Arrêter", style: TextStyle(color: Colors.white70)),
                onPressed: () {
                   _audio.stop();
                   Navigator.pop(context); // Close sheet after stopping
                }
              ),
            ],
          )
        ],
      ),
    );
  }
}
