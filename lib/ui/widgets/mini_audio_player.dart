import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/reciter_photos.dart';
import '../../services/audio_service.dart';
import '../../services/navigation_service.dart';
import '../screens/music_player_fullscreen.dart';

// ── Nav bar height constant (must match ModernBottomNavBar) ───────────────────
// fabSize(72) + vMargin(14) + extra(16) = 102
const double _kNavBarAboveSafeArea = 102.0;

// ── Glassmorphic container helper ─────────────────────────────────────────────
Widget _glass({required Widget child, EdgeInsets margin = EdgeInsets.zero}) {
  const radius = BorderRadius.all(Radius.circular(16));
  return Container(
    margin: margin,
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          child: child,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

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
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF374151);
    const iconColor = Color(0xFF111827);

    return ValueListenableBuilder<bool>(
      valueListenable: _audio.isRadioModeNotifier,
      builder: (_, isRadio, __) {
        if (isRadio) {
          return _buildRadioMode(
            context,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            iconColor: iconColor,
          );
        }
        return _glass(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Barre de progression ──────────────────────────────────────
              _SeekBar(audio: _audio, accent: accent),

              // ── Ligne principale ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
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
                                style:
                                    TextStyle(color: textSecondary, fontSize: 12),
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
                            state?.processingState == ProcessingState.loading ||
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
                                    color: Color(0xFF38C172), strokeWidth: 2),
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
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        );
                      },
                    ),

                    // → Réduire en cercle
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: iconColor, size: 26),
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
        );
      },
    );
  }

  Widget _buildRadioMode(
    BuildContext context, {
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color iconColor,
  }) {
    return _glass(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            // Icône radio
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
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
                      _dragging = Duration(milliseconds: (f * maxMs).toInt());
                    });
                  },
                  onHorizontalDragUpdate: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    setState(() {
                      _dragging = Duration(milliseconds: (f * maxMs).toInt());
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
                    height: 10,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: trackBg,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
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
      return Align(
        alignment: Alignment.centerRight,
        child: _CollapsedCirclePlayer(
          onExpand: () => setState(() => _isCollapsed = false),
        ),
      );
    }

    final totalDisp = _offsetX.abs() > _offsetY ? _offsetX.abs() : _offsetY;
    final absDx      = _offsetX.abs();
    final thresholdReached = absDx > 60;

    // Intensité du dégradé : 0 → 0.45 progressivement
    final gradientAlpha = (absDx / 80).clamp(0.0, 0.45);
    // Icône centrale : apparaît et pulse quand seuil atteint
    final iconScale = thresholdReached ? 1.15 : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // ── Swipe bas → dismiss ───────────────────────────────────────────────
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 0 || _offsetY > 0) {
          setState(() => _offsetY = (_offsetY + d.delta.dy).clamp(0.0, 140.0));
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
        setState(() => _offsetX = (_offsetX + d.delta.dx).clamp(-150.0, 150.0));
      },
      onHorizontalDragEnd: (d) {
        final vx = d.velocity.pixelsPerSecond.dx;
        if (_offsetX > 60 || vx > 400) {
          _audio.skipToPrevious();
        } else if (_offsetX < -60 || vx < -400) {
          _audio.skipToNext();
        }
        setState(() => _offsetX = 0);
      },
      onHorizontalDragCancel: () => setState(() => _offsetX = 0),
      child: Transform.translate(
        offset: Offset(_offsetX, _offsetY),
        child: Opacity(
          opacity: (1.0 - totalDisp / 150.0 * 0.75).clamp(0.20, 1.0),
          child: Stack(
            children: [
              MiniAudioPlayer(
                onCollapse: () => setState(() => _isCollapsed = true),
              ),

              // ── Flash directionnel ──────────────────────────────────────
              if (_offsetX != 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: _offsetX > 0
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: _offsetX > 0
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: [
                              const Color(0xFF38C172).withValues(alpha: gradientAlpha),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Icône centrale au dépassement du seuil ──────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedScale(
                      scale: iconScale,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.elasticOut,
                      child: Icon(
                        _offsetX > 0
                            ? Icons.skip_previous_rounded
                            : Icons.skip_next_rounded,
                        color: const Color(0xFF38C172),
                        size: 36,
                        shadows: const [
                          Shadow(
                            color: Color(0x6638C172),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
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
  late final StreamSubscription<PlayerState> _sub;

  static const _phases = [0.0, 0.33, 0.66];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _sub = AudioService.instance.playerStateStream.listen(_onState);
  }

  void _onState(PlayerState state) {
    if (state.playing) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      if (_ctrl.isAnimating) _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double _sine(double t) =>
      (1 + math.sin(t * 2 * math.pi)) / 2;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.55),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (i) {
                final t = (_ctrl.value + _phases[i]) % 1.0;
                final h = 8.0 + 16.0 * _sine(t);
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
                  bottom: bottomInset + _kNavBarAboveSafeArea,
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
