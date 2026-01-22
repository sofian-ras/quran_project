import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final AudioService _audio = AudioService.instance;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20), // Un vert foncé de la palette
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // Poignée pour indiquer qu'on peut glisser
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Spacer(),

              // Zone pour l'information de la sourate
              Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                ),
                child: const Center(
                  child: Icon(Icons.music_note, color: Colors.white54, size: 80),
                ),
              ),
              const SizedBox(height: 30),

              // Titre de la sourate et nom du récitateur
              ValueListenableBuilder<String>(
                valueListenable: _audio.currentTitleNotifier,
                builder: (_, title, __) => Text(
                  title,
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: _audio.currentReciterNotifier,
                builder: (_, reciter, __) => Text(
                  reciter,
                  style: const TextStyle(fontSize: 16, color: gold),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),

              // Barre de progression (à venir)
              
              const Spacer(),

              // Rangée de contrôles principaux
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton Répétition
                  ValueListenableBuilder<LoopMode>(
                    valueListenable: _audio.loopModeNotifier,
                    builder: (context, loopMode, _) {
                      IconData iconData;
                      Color iconColor = Colors.white70;
                      switch (loopMode) {
                        case LoopMode.one:
                          iconData = Icons.repeat_one;
                          iconColor = gold;
                          break;
                        case LoopMode.all:
                          iconData = Icons.repeat;
                          iconColor = gold;
                          break;
                        default:
                          iconData = Icons.repeat;
                          break;
                      }
                      return IconButton(
                        icon: Icon(iconData, color: iconColor),
                        iconSize: 28,
                        onPressed: _audio.cycleLoopMode,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    iconSize: 42,
                    onPressed: _audio.skipToPrevious,
                  ),
                  // Bouton Play/Pause
                   StreamBuilder<PlayerState>(
                    stream: _audio.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;
                      
                      if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                        return const SizedBox(width: 70, height: 70, child: Center(child: CircularProgressIndicator(color: Colors.white)));
                      }
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                        iconSize: 70,
                        onPressed: _audio.togglePlayPause,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    iconSize: 42,
                    onPressed: _audio.skipToNext,
                  ),
                  // Bouton pour la liste des récitateurs (à venir)
                  IconButton(
                    icon: const Icon(Icons.person_search, color: Colors.white70),
                    iconSize: 28,
                    onPressed: () { /* TODO */ },
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
