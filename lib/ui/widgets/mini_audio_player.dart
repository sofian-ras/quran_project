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
        builder: (_, controller) =>
            MusicPlayerFullScreen(scrollController: controller),
      ),
    ).whenComplete(() {
      _audio.isFullPlayerOpenNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38C172);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFFFFF);
    final textPrimary =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final textSecondary =
        isDark ? const Color(0xFFB6C7E8) : const Color(0xFF6B7280);
    final iconBg = isDark ? const Color(0xFF253554) : const Color(0xFFE8F5E9);
    final iconColor =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return Material(
      color: bg,
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barre de progression interactive en haut ─────────────────────
          _SeekBar(audio: _audio, accent: accent),

          // ── Ligne principale ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                // Icône son
                GestureDetector(
                  onTap: _openFullPlayer,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note,
                        color: accent, size: 22),
                  ),
                ),

                const SizedBox(width: 12),

                // Titre + récitateur
                Expanded(
                  child: GestureDetector(
                    onTap: _openFullPlayer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: _audio.currentTitleNotifier,
                          builder: (_, title, __) => Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: _audio.currentReciterNotifier,
                          builder: (_, name, __) => Text(
                            name,
                            style:
                                TextStyle(color: textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Contrôles ⏮ ▶/⏸ ⏭
                StreamBuilder<PlayerState>(
                  stream: _audio.playerStateStream,
                  builder: (_, snapshot) {
                    final state = snapshot.data;
                    final isPlaying = state?.playing ?? false;
                    final loading =
                        state?.processingState == ProcessingState.loading ||
                            state?.processingState ==
                                ProcessingState.buffering;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.skip_previous,
                              color: iconColor, size: 28),
                          onPressed: _audio.skipToPrevious,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                        loading
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: accent, strokeWidth: 2),
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: iconColor,
                                  size: 32,
                                ),
                                onPressed: _audio.togglePlayPause,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                        IconButton(
                          icon: Icon(Icons.skip_next,
                              color: iconColor, size: 28),
                          onPressed: _audio.skipToNext,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barre de progression interactive (glissable) ──────────────────────────────

class _SeekBar extends StatefulWidget {
  final AudioService audio;
  final Color accent;

  const _SeekBar({required this.audio, required this.accent});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  Duration? _dragging;

  String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackBg = isDark ? const Color(0xFF2A3A5C) : const Color(0xFFE5E7EB);
    final accent = widget.accent;

    return StreamBuilder<PositionData>(
      stream: widget.audio.positionDataStream,
      builder: (_, snapshot) {
        final dur = snapshot.data?.duration ?? Duration.zero;
        final pos = _dragging ?? snapshot.data?.position ?? Duration.zero;
        final maxMs = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final fraction = (pos.inMilliseconds / maxMs).clamp(0.0, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_dragging != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(pos),
                      style: TextStyle(
                          fontSize: 10,
                          color: accent,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _fmt(dur),
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (ctx, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    setState(() {
                      _dragging =
                          Duration(milliseconds: (f * maxMs).toInt());
                    });
                  },
                  onHorizontalDragUpdate: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    setState(() {
                      _dragging =
                          Duration(milliseconds: (f * maxMs).toInt());
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_dragging != null) {
                      widget.audio.seek(_dragging!);
                      setState(() => _dragging = null);
                    }
                  },
                  onTapDown: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    widget.audio
                        .seek(Duration(milliseconds: (f * maxMs).toInt()));
                  },
                  child: SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: trackBg,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Overlay global (glisser vers le bas pour arrêter) ────────────────────────

class GlobalMiniPlayerOverlay extends StatefulWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  State<GlobalMiniPlayerOverlay> createState() =>
      _GlobalMiniPlayerOverlayState();
}

class _GlobalMiniPlayerOverlayState extends State<GlobalMiniPlayerOverlay> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: audio.suppressGlobalPlayer,
      builder: (_, isSuppressed, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: audio.isFullPlayerOpenNotifier,
          builder: (_, isFullOpen, __) {
            return StreamBuilder<bool>(
              stream: audio.isActiveStream,
              builder: (_, snapshot) {
                final isActive = snapshot.data ?? false;

                if (isSuppressed || isFullOpen || !isActive) {
                  // Reset offset quand le player se cache
                  if (_dragOffset != 0) _dragOffset = 0;
                  return const SizedBox.shrink();
                }

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) {
                      if (d.delta.dy > 0) {
                        setState(() => _dragOffset += d.delta.dy);
                      }
                    },
                    onVerticalDragEnd: (d) {
                      final dismiss = _dragOffset > 60 ||
                          d.velocity.pixelsPerSecond.dy > 400;
                      setState(() => _dragOffset = 0);
                      if (dismiss) audio.stop();
                    },
                    onVerticalDragCancel: () {
                      setState(() => _dragOffset = 0);
                    },
                    child: Transform.translate(
                      offset: Offset(0, _dragOffset.clamp(0.0, 120.0)),
                      child: Opacity(
                        opacity:
                            (1.0 - _dragOffset / 120.0).clamp(0.3, 1.0),
                        child: const MiniAudioPlayer(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
