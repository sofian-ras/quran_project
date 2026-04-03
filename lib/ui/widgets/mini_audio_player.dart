import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/reciter_photos.dart';
import '../../services/audio_service.dart';
import '../../services/navigation_service.dart';
import '../screens/music_player_fullscreen.dart';

class MiniAudioPlayer extends StatefulWidget {
  final VoidCallback onCollapse;
  const MiniAudioPlayer({super.key, required this.onCollapse});

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
    final iconColor =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return ValueListenableBuilder<bool>(
      valueListenable: _audio.isRadioModeNotifier,
      builder: (_, isRadio, __) {
        if (isRadio) {
          return _buildRadioMode(
            context,
            accent: accent,
            bg: bg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            iconColor: iconColor,
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: bg,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Barre de progression interactive ────────────────────────
                _SeekBar(audio: _audio, accent: accent),

                // ── Ligne principale ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
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
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ▶/⏸
                      StreamBuilder<PlayerState>(
                        stream: _audio.playerStateStream,
                        builder: (_, snapshot) {
                          final state = snapshot.data;
                          final isPlaying = state?.playing ?? false;
                          final loading =
                              state?.processingState ==
                                      ProcessingState.loading ||
                                  state?.processingState ==
                                      ProcessingState.buffering;
                          if (loading) {
                            return const SizedBox(
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
                            );
                          }
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: iconColor,
                              size: 32,
                            ),
                            onPressed: _audio.togglePlayPause,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          );
                        },
                      ),

                      // → Réduire en cercle
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                            color: iconColor, size: 26),
                        onPressed: widget.onCollapse,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadioMode(
    BuildContext context, {
    required Color accent,
    required Color bg,
    required Color textPrimary,
    required Color textSecondary,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: bg,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              // Icône radio
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark(context)
                      ? const Color(0xFF253554)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.radio, color: accent, size: 22),
              ),

              const SizedBox(width: 12),

              // Titre + domaine
              Expanded(
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
                      builder: (_, domain, __) => Text(
                        domain,
                        style: TextStyle(color: textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge LIVE + play/pause
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (_, snapshot) {
                  final state = snapshot.data;
                  final isPlaying = state?.playing ?? false;
                  final loading =
                      state?.processingState == ProcessingState.loading ||
                          state?.processingState == ProcessingState.buffering;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LiveBadge(),
                      const SizedBox(width: 4),
                      loading
                          ? SizedBox(
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
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: iconColor,
                                size: 32,
                              ),
                              onPressed: _audio.togglePlayPause,
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
      ),
    );
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
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

// ── Conteneur principal : gère collapse + swipe prev/next/dismiss ─────────────

class _MiniPlayerContainer extends StatefulWidget {
  final VoidCallback onDismiss;
  const _MiniPlayerContainer({required this.onDismiss});

  @override
  State<_MiniPlayerContainer> createState() => _MiniPlayerContainerState();
}

class _MiniPlayerContainerState extends State<_MiniPlayerContainer> {
  final AudioService _audio = AudioService.instance;
  double _offsetY = 0;
  double _offsetX = 0;
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (_isCollapsed) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Align(
          key: const ValueKey('collapsed'),
          alignment: Alignment.centerRight,
          child: _CollapsedCirclePlayer(
            onExpand: () => setState(() => _isCollapsed = false),
          ),
        ),
      );
    }

    final totalDisp = _offsetX.abs() > _offsetY ? _offsetX.abs() : _offsetY;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        key: const ValueKey('expanded'),
        behavior: HitTestBehavior.opaque,
        // ── Swipe bas → dismiss ───────────────────────────────────────────────
        onVerticalDragUpdate: (d) {
          if (d.delta.dy > 0 || _offsetY > 0) {
            setState(
                () => _offsetY = (_offsetY + d.delta.dy).clamp(0.0, 140.0));
          }
        },
        onVerticalDragEnd: (d) {
          if (_offsetY > 60 || d.velocity.pixelsPerSecond.dy > 400) {
            widget.onDismiss();
            return;
          }
          setState(() => _offsetY = 0);
        },
        onVerticalDragCancel: () => setState(() => _offsetY = 0),
        // ── Swipe droite → précédent, gauche → suivant ────────────────────────
        onHorizontalDragUpdate: (d) {
          setState(
              () => _offsetX = (_offsetX + d.delta.dx).clamp(-150.0, 150.0));
        },
        onHorizontalDragEnd: (d) {
          final vx = d.velocity.pixelsPerSecond.dx;
          if (_offsetX > 60 || vx > 400) {
            _audio.skipToPrevious();
            setState(() => _offsetX = 0);
          } else if (_offsetX < -60 || vx < -400) {
            _audio.skipToNext();
            setState(() => _offsetX = 0);
          } else {
            setState(() => _offsetX = 0);
          }
        },
        onHorizontalDragCancel: () => setState(() => _offsetX = 0),
        child: Transform.translate(
          offset: Offset(_offsetX, _offsetY),
          child: Opacity(
            opacity: (1.0 - totalDisp / 150.0).clamp(0.3, 1.0),
            child: MiniAudioPlayer(
              onCollapse: () => setState(() => _isCollapsed = true),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cercle réduit (état collapsed) ───────────────────────────────────────────

class _CollapsedCirclePlayer extends StatelessWidget {
  final VoidCallback onExpand;
  const _CollapsedCirclePlayer({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    return GestureDetector(
      onTap: onExpand,
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF38C172), width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: ValueListenableBuilder<String>(
            valueListenable: audio.currentReciterNotifier,
            builder: (_, name, __) {
              final url = getReciterPhoto(name);
              if (url != null) {
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _AnimatedSoundBars(),
                );
              }
              return const _AnimatedSoundBars();
            },
          ),
        ),
      ),
    );
  }
}

// ── Barres de son animées (fallback image récitateur) ─────────────────────────

class _AnimatedSoundBars extends StatefulWidget {
  const _AnimatedSoundBars();

  @override
  State<_AnimatedSoundBars> createState() => _AnimatedSoundBarsState();
}

class _AnimatedSoundBarsState extends State<_AnimatedSoundBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _barCount = 3;
  // Phase offsets so each bar bounces at a different rhythm
  static const _phases = [0.0, 0.33, 0.66];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8F5E9);

    return ColoredBox(
      color: bg,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_barCount, (i) {
                // Sinusoidal height for each bar
                final t = (_ctrl.value + _phases[i]) % 1.0;
                final h = 8.0 + 16.0 * (0.5 + 0.5 * _sine(t));
                return Container(
                  width: 5,
                  height: h,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38C172),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  // t in [0,1] → normalized sine in [0,1]
  double _sine(double t) =>
      (1 + math.sin(t * 2 * math.pi)) / 2;
}

// ── Overlay global ────────────────────────────────────────────────────────────

class GlobalMiniPlayerOverlay extends StatelessWidget {
  const GlobalMiniPlayerOverlay({super.key});

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
                  return const SizedBox.shrink();
                }

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  child: _MiniPlayerContainer(
                    onDismiss: audio.stopAll,
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

// ── Badge "LIVE" ─────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
