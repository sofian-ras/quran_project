import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import 'package:just_audio/just_audio.dart';

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
      if (mounted) setState(() => _playing = st.playing);
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
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Lecture en cours", style: TextStyle(color: Colors.white70, fontSize: 10)),
                // Affiche le titre du service ou le widget.title par défaut
                Text(
                  _audio.currentTitle.isNotEmpty ? _audio.currentTitle : widget.title, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Bouton Précédent (à configurer plus tard)
          const IconButton(icon: Icon(Icons.skip_previous, color: Colors.white70), onPressed: null),
          // Bouton Suivant (à configurer plus tard)
          const IconButton(icon: Icon(Icons.skip_next, color: gold), onPressed: null),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}