import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

class BottomAudioBar extends StatefulWidget {
  final String title;

  const BottomAudioBar({super.key, this.title = ''});

  @override
  State<BottomAudioBar> createState() => _BottomAudioBarState();
}

class _BottomAudioBarState extends State<BottomAudioBar> {
  final AudioService _audio = AudioService.instance;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _audio.playerStateStream.listen((st) {
      final playing = st.playing;
      if (mounted) setState(() => _playing = playing);
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF0B3D2E);
    const gold = Color(0xFFC8A165);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [darkGreen, Colors.green]),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _audio.togglePlayPause();
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('Aucun audio configuré')));
              }
            },
          ),
          Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white70), onPressed: null),
          IconButton(icon: const Icon(Icons.skip_next, color: gold), onPressed: null),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // do not dispose the global audio player here
    super.dispose();
  }
}
