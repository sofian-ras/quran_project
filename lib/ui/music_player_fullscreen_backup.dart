import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import 'widgets/reciter_selector.dart';

class MusicPlayerFullScreen extends StatefulWidget {
  const MusicPlayerFullScreen({super.key});

  @override
  State<MusicPlayerFullScreen> createState() => _MusicPlayerFullScreenState();
}

class _MusicPlayerFullScreenState extends State<MusicPlayerFullScreen> with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService.instance;  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();  late AnimationController _iconAnimationController;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1E3A2F);
    const gold = Color(0xFFD4AF77);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fond avec effet de flou
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      green.withOpacity(0.95),
                      green.withOpacity(0.98),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                // Header avec bouton fermer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white70, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Lecteur Audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 48), // Pour centrer le titre
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Image de couverture (cercle animé)
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [gold.withOpacity(0.3), gold.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.music_note_2,
                      size: 100,
                      color: gold.withOpacity(0.8),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Titre et récitateur
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: _audio.currentTitleNotifier,
                        builder: (_, title, __) => Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: _audio.currentReciterNotifier,
                        builder: (_, reciter, __) => Text(
                          reciter,
                          style: TextStyle(
                            fontSize: 18,
                            color: gold.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Barre de progression
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildProgressBar(gold),
                ),

                const SizedBox(height: 30),

                // Contrôles de lecture
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildControls(gold),
                ),

                const SizedBox(height: 20),

                // Contrôles secondaires
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _buildSecondaryControls(gold),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color gold) {
    return StreamBuilder<PositionData>(
      stream: _audio.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        final position = positionData?.position ?? Duration.zero;
        final duration = positionData?.duration ?? Duration.zero;
        
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: gold,
                inactiveTrackColor: Colors.white24,
                thumbColor: gold,
                overlayColor: gold.withOpacity(0.3),
              ),
              child: Slider(
                max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouton précédent
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: IconButton(
            icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white),
            iconSize: 32,
            onPressed: _audio.skipToPrevious,
          ),
        ),

        const SizedBox(width: 20),

        // Bouton play/pause (grand)
        StreamBuilder<PlayerState>(
          stream: _audio.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final isPlaying = playerState?.playing ?? false;
            final processingState = playerState?.processingState;
            
            if (processingState == ProcessingState.loading || 
                processingState == ProcessingState.buffering) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [gold, gold.withOpacity(0.8)],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              );
            }

            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [gold, gold.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gold.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                  color: Colors.white,
                ),
                iconSize: 40,
                onPressed: _audio.togglePlayPause,
              ),
            );
          },
        ),

        const SizedBox(width: 20),

        // Bouton suivant
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: IconButton(
            icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white),
            iconSize: 32,
            onPressed: _audio.skipToNext,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Bouton repeat
        ValueListenableBuilder<LoopMode>(
          valueListenable: _audio.loopModeNotifier,
          builder: (context, loopMode, _) {
            return IconButton(
              icon: Icon(
                loopMode == LoopMode.one
                    ? CupertinoIcons.repeat_1
                    : CupertinoIcons.repeat,
                color: loopMode == LoopMode.off ? Colors.white38 : gold,
              ),
              iconSize: 26,
              onPressed: _audio.cycleLoopMode,
            );
          },
        ),

        // Bouton stop
        IconButton(
          icon: const Icon(CupertinoIcons.stop_circle, color: Colors.white70),
          iconSize: 28,
          onPressed: () => _audio.stop(),
        ),

        // Bouton changement de récitateur
        IconButton(
          icon: const Icon(CupertinoIcons.person_2, color: Colors.white70),
          iconSize: 26,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => ReciterSelectorSheet(
                onSelected: (name, server) {
                  _audio.setReciter(name, server);
                  final id = _audio.currentSurahId;
                  if (id != null) _audio.loadPlaylistAndPlay(id);
                },
              ),
            );
          },
        ),
      ],
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
}
