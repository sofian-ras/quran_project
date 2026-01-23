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

class _MusicPlayerFullScreenState extends State<MusicPlayerFullScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService.instance;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    // Ne pas démarrer automatiquement, attendre que l'audio joue
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fond flouté avec effet
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black54.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar personnalisée
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.chevron_down,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Lecteur Audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // Bouton sourate
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // TODO: Ouvrir sélecteur de sourate
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sélecteur de sourate à implémenter'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.list_bullet,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Bouton récitateur
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (sheetContext) =>
                                      ReciterSelectorSheet(
                                    onSelected: (name, server) {
                                      _audio.setReciter(name, server);
                                      final id = _audio.currentSurahId;
                                      if (id != null) {
                                        _audio.loadPlaylistAndPlay(id);
                                      }
                                    },
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_2,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // Artwork circulaire avec animation
                            StreamBuilder<PlayerState>(
                              stream: _audio.playerStateStream,
                              builder: (context, snapshot) {
                                final isPlaying =
                                    snapshot.data?.playing ?? false;

                                if (isPlaying) {
                                  _animationController.repeat();
                                } else {
                                  _animationController.stop();
                                }

                                return RotationTransition(
                                  turns: _animationController,
                                  child: Container(
                                    width: 240,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          gold.withOpacity(0.3),
                                          gold.withOpacity(0.1),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gold.withOpacity(0.3),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.1),
                                          border: Border.all(
                                            color: gold.withOpacity(0.5),
                                            width: 3,
                                          ),
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.music_note_2,
                                          color: gold,
                                          size: 80,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            // Titre et récitant
                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentTitleNotifier,
                              builder: (context, title, _) => Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            const SizedBox(height: 8),

                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentReciterNotifier,
                              builder: (context, reciter, _) => Text(
                                reciter,
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Barre de progression
                            _buildProgressBar(),

                            const SizedBox(height: 24),

                            // Contrôles de lecture
                            _buildControls(gold),

                            const SizedBox(height: 16),

                            // Contrôles secondaires
                            _buildSecondaryControls(gold),

                            const SizedBox(height: 20),
                          ],
                        ), // Fermeture Column interne
                      ), // Fermeture Padding
                    ), // Fermeture SingleChildScrollView
                  ), // Fermeture Expanded
                ], // Fermeture children de Column SafeArea
            ), // Fermeture Column SafeArea
          ), // Fermeture SafeArea
        ], // Fermeture children de Stack
      ), // Fermeture Stack body
    ); // Fermeture Scaffold
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
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16.0),
                activeTrackColor: gold,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: gold,
                overlayColor: gold.withOpacity(0.3),
              ),
              child: Slider(
                max: duration.inMilliseconds
                    .toDouble()
                    .clamp(1.0, double.infinity),
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, duration.inMilliseconds.toDouble()),
                onChanged: (value) =>
                    _audio.seek(Duration(milliseconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Précédent
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _audio.skipToPrevious,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.backward_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),

        // Play/Pause
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
                  color: gold.withOpacity(0.3),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: gold,
                    strokeWidth: 3,
                  ),
                ),
              );
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _audio.togglePlayPause,
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            );
          },
        ),

        // Suivant
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _audio.skipToNext,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.forward_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mode répétition
        ValueListenableBuilder<LoopMode>(
          valueListenable: _audio.loopModeNotifier,
          builder: (context, loopMode, _) {
            final isActive = loopMode != LoopMode.off;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _audio.cycleLoopMode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? gold.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? gold.withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    loopMode == LoopMode.one
                        ? CupertinoIcons.repeat_1
                        : CupertinoIcons.repeat,
                    color: isActive ? gold : Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),

        // Shuffle (placeholder pour future implémentation)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // TODO: Implémenter shuffle
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.shuffle,
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
          ),
        ),

        // Stop
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _audio.stop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.stop_fill,
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
