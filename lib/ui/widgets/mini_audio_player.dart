import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/audio_service.dart';
import '../../services/navigation_service.dart';
import '../music_player_fullscreen.dart';

class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  final AudioService _audio = AudioService.instance;

  void _openFullPlayer() {
    final ctx = NavigationService.navigatorKey.currentContext ?? context;

    _audio.isFullPlayerOpenNotifier.value = true;

    showModalBottomSheet(
      context: ctx,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (_, controller) => MusicPlayerFullScreen(scrollController: controller),
      ),
    ).whenComplete(() {
      _audio.isFullPlayerOpenNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF38C172);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgTop = isDark ? const Color(0xFF0B1A3A) : const Color(0xFFFFFFFF);
    final bgBottom = isDark ? const Color(0xFF132B5C) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFFB6C7E8) : const Color(0xFF6B7280);
    final iconColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final dividerColor = isDark ? const Color(0xFF1E3A6E) : const Color(0xFFE5E7EB);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgTop, bgBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(color: dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _openFullPlayer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: _audio.currentTitleNotifier,
                            builder: (context, title, _) => Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: _audio.currentReciterNotifier,
                            builder: (context, name, _) => Text(
                              name,
                              style: TextStyle(color: textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: iconColor, size: 32),
                    onPressed: _audio.skipToPrevious,
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _audio.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                          child: CircularProgressIndicator(color: green),
                        ),
                      );
                    }
                    return IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: iconColor,
                        size: 48,
                      ),
                      onPressed: _audio.togglePlayPause,
                    );
                  },
                ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: iconColor, size: 32),
                    onPressed: _audio.skipToNext,
                  ),
                  IconButton(
                    icon: Icon(Icons.stop_circle_outlined, color: iconColor, size: 28),
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
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildProgressBar() {
    const green = Color(0xFF38C172);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? const Color(0xFFB6C7E8) : const Color(0xFF6B7280);
    final inactiveTrack = isDark ? const Color(0xFF1E3A6E) : const Color(0xFFE5E7EB);
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
              height: 20,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                ),
                child: Slider(
                  activeColor: green,
                  inactiveColor: inactiveTrack,
                  max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                  value: position.inMilliseconds
                      .toDouble()
                      .clamp(0.0, duration.inMilliseconds.toDouble()),
                  onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position),
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                  Text(_formatDuration(duration),
                      style: TextStyle(color: textSecondary, fontSize: 12)),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: audio.isFullPlayerOpenNotifier,
      builder: (context, isFullOpen, _) {
        return StreamBuilder<bool>(
          stream: audio.isActiveStream,
          builder: (context, snapshot) {
            final isActive = snapshot.data ?? false;

            // ✅ Si fullscreen ouvert OU pas d'audio → on ne construit rien (sinon ça reste au-dessus)
            if (isFullOpen || !isActive) {
              return const SizedBox.shrink();
            }

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: bottomInset,
              left: 0,
              right: 0,
              child: const Material(
                color: Colors.transparent,
                child: MiniAudioPlayer(),
              ),
            );
          },
        );
      },
    );
  }

}
