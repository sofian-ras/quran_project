import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/reciter_photos.dart';
import '../../data/surah_name.dart';
import '../../services/audio_service.dart';
import '../../services/navigation_service.dart';
import '../screens/music_player_fullscreen.dart';
import 'mini_audio_player.dart';

// ─────────────────────────────────────────────────────────────────────────────

class ModernBottomNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onCenterTap;

  const ModernBottomNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onCenterTap,
  });

  @override
  State<ModernBottomNavBar> createState() => _ModernBottomNavBarState();
}

class _ModernBottomNavBarState extends State<ModernBottomNavBar>
    with TickerProviderStateMixin {

  // ── FAB ──────────────────────────────────────────────────────────────────
  late final AnimationController _fabCtrl;
  late final Animation<double>    _fabScale;

  // ── Halo FAB ──────────────────────────────────────────────────────────────
  late final AnimationController _haloCtrl;
  late final Animation<double>    _haloScale;
  late final Animation<double>    _haloOpacity;

  // ── Press icônes ──────────────────────────────────────────────────────────
  final Map<int, AnimationController> _iconCtrl  = {};
  final Map<int, Animation<double>>   _iconScale = {};

  // ── Audio state ───────────────────────────────────────────────────────────
  bool _isAudioActive = false;
  bool _isPlayerMode  = true;
  late final StreamSubscription<bool> _activeSub;

  @override
  void initState() {
    super.initState();

    _fabCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _fabScale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

    _haloCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _haloScale   = Tween<double>(begin: 1.0,  end: 1.18)
        .animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut));
    _haloOpacity = Tween<double>(begin: 0.18, end: 0.0)
        .animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut));

    for (int i = 0; i < 4; i++) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 120));
      _iconCtrl[i]  = c;
      _iconScale[i] = Tween<double>(begin: 1.0, end: 0.70)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }

    _activeSub = AudioService.instance.isActiveStream.listen((active) {
      if (mounted) {
        setState(() {
          _isAudioActive = active;
          if (!active) _isPlayerMode = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _activeSub.cancel();
    _fabCtrl.dispose();
    _haloCtrl.dispose();
    for (final c in _iconCtrl.values) { c.dispose(); }
    super.dispose();
  }

  void _tapItem(int i) {
    if (i == widget.index) return;
    HapticFeedback.selectionClick();
    _iconCtrl[i]!.forward().then((_) => _iconCtrl[i]!.reverse());
    widget.onChanged(i);
  }

  // ── FAB ──────────────────────────────────────────────────────────────────
  Widget _fabLogo(double fabSize, Color goldLight) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fabScale, _haloScale, _haloOpacity]),
      builder: (_, __) => GestureDetector(
        onTapDown:   (_) => _fabCtrl.forward(),
        onTapUp:     (_) {
          _fabCtrl.reverse();
          HapticFeedback.mediumImpact();
          widget.onCenterTap();
        },
        onTapCancel: () => _fabCtrl.reverse(),
        child: Semantics(
          button: true,
          label: 'Ouvrir le Coran',
          child: Transform.scale(
            scale: _fabScale.value,
            child: SizedBox(
              width: fabSize,
              height: fabSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _haloScale.value,
                    child: Container(
                      width: fabSize,
                      height: fabSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: goldLight.withValues(alpha: _haloOpacity.value),
                      ),
                    ),
                  ),
                  Container(
                    width: fabSize,
                    height: fabSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.55),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/images/navbar/Quran_Kareem.svg',
                              width: 52,
                              height: 52,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF1B5E20),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pill (barre droite) ───────────────────────────────────────────────────
  Widget _navPill(double barH) {
    final showPlayer = _isAudioActive && _isPlayerMode;
    const double pillHNav    = 52.0;
    const double pillHPlayer = 64.0;
    final double pillH = showPlayer ? pillHPlayer : pillHNav;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Verre dépoli ───────────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pillH / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(pillH / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(pillH / 2),
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      // ── Contenu animé ──────────────────────────────────
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: pillHNav,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: showPlayer
                                  ? _PlayerPillContent(
                                      key: const ValueKey('player'),
                                      onDismiss: AudioService.instance.stopAll,
                                    )
                                  : _NavIconsContent(
                                      key: const ValueKey('nav'),
                                      selectedIndex: widget.index,
                                      iconCtrl: _iconCtrl,
                                      iconScale: _iconScale,
                                      barH: pillHNav,
                                      onTap: _tapItem,
                                    ),
                            ),
                          ),
                          if (showPlayer)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                              child: SeekBar(
                                audio: AudioService.instance,
                                accent: const Color(0xFF38C172),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Cercle récitateur (déborde sur le côté actif) ─────────────
            if (_isAudioActive)
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: showPlayer
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(showPlayer ? -22 : 22, 0),
                    child: _ReciterCircle(
                      onToggle: () =>
                          setState(() => _isPlayerMode = !_isPlayerMode),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double fabSize  = 72.0;
    const double barH     = 52.0;
    const double hMargin  = 14.0;
    const double vMargin  = 14.0;
    const double gap      = 10.0;
    const Color  goldLight = Color(0xFFD4AF37);

    final double totalH = fabSize + vMargin + bottomInset + 16;

    return SizedBox(
      height: totalH,
      child: Padding(
        padding: EdgeInsets.only(
          left: hMargin,
          right: hMargin,
          bottom: vMargin + bottomInset,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _fabLogo(fabSize, goldLight),
            const SizedBox(width: gap),
            _navPill(barH),
          ],
        ),
      ),
    );
  }
}

// ── Contenu : 4 icônes de navigation ────────────────────────────────────────

class _NavIconsContent extends StatelessWidget {
  final int selectedIndex;
  final Map<int, AnimationController> iconCtrl;
  final Map<int, Animation<double>>   iconScale;
  final double barH;
  final ValueChanged<int> onTap;

  const _NavIconsContent({
    super.key,
    required this.selectedIndex,
    required this.iconCtrl,
    required this.iconScale,
    required this.barH,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_rounded,
      Icons.mosque_rounded,
      Icons.volunteer_activism_rounded,
      Icons.more_horiz_rounded,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalW = constraints.maxWidth;
        final double itemW  = totalW / 4;
        const double pillW  = 44.0;

        final double pillLeft = (selectedIndex == 0 || selectedIndex == 3)
            ? selectedIndex * itemW
            : selectedIndex * itemW + (itemW - pillW) / 2;
        final double pillWidth = (selectedIndex == 0 || selectedIndex == 3)
            ? itemW
            : pillW;

        return Stack(
          children: [
            // Pill actif
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: pillLeft,
              top: 0,
              width: pillWidth,
              height: barH,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barH / 2),
                  color: const Color(0xFF1B5E20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),

            // Icônes
            Row(
              children: [
                ...List.generate(4, (i) {
                  final bool sel = selectedIndex == i;
                  return SizedBox(
                    width: itemW,
                    height: barH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown:   (_) { if (!sel) iconCtrl[i]!.forward(); },
                      onTapUp:     (_) { iconCtrl[i]!.reverse(); onTap(i); },
                      onTapCancel: ()  => iconCtrl[i]!.reverse(),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: iconScale[i]!,
                          builder: (_, child) => Transform.scale(
                            scale: iconScale[i]!.value,
                            child: child,
                          ),
                          child: AnimatedScale(
                            scale: sel ? 1.18 : 1.0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.elasticOut,
                            child: Icon(
                              icons[i],
                              size: 21,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Contenu : mini player dans la pill ───────────────────────────────────────

class _PlayerPillContent extends StatefulWidget {
  final VoidCallback onDismiss;

  const _PlayerPillContent({
    super.key,
    required this.onDismiss,
  });

  @override
  State<_PlayerPillContent> createState() => _PlayerPillContentState();
}

class _PlayerPillContentState extends State<_PlayerPillContent> {
  final _audio = AudioService.instance;
  double _dx = 0;
  double _dy = 0;
  bool _showHints = false;

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
    final id       = _audio.currentSurahId ?? 1;
    final prevName = id > 1   ? surahFr[id - 1] : null;
    final nextName = id < 114 ? surahFr[id + 1] : null;

    return Listener(
      onPointerDown:   (_) => setState(() => _showHints = true),
      onPointerUp:     (_) => setState(() => _showHints = false),
      onPointerCancel: (_) => setState(() => _showHints = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Swipe bas → stop
        onVerticalDragUpdate: (d) {
          if (d.delta.dy > 0 || _dy > 0) {
            setState(() => _dy = (_dy + d.delta.dy).clamp(0.0, 60.0));
          }
        },
        onVerticalDragEnd: (d) {
          if (_dy > 30 || d.velocity.pixelsPerSecond.dy > 400) {
            widget.onDismiss();
          }
          setState(() => _dy = 0);
        },
        onVerticalDragCancel: () => setState(() => _dy = 0),
        // Swipe droite → précédent, gauche → suivant
        onHorizontalDragUpdate: (d) {
          setState(() => _dx = (_dx + d.delta.dx).clamp(-100.0, 100.0));
        },
        onHorizontalDragEnd: (d) {
          final vx = d.velocity.pixelsPerSecond.dx;
          if (_dx > 50 || vx > 400) { _audio.skipToPrevious(); }
          else if (_dx < -50 || vx < -400) { _audio.skipToNext(); }
          setState(() => _dx = 0);
        },
        onHorizontalDragCancel: () => setState(() => _dx = 0),
        child: Transform.translate(
          offset: Offset(_dx, _dy),
          child: Stack(
            children: [
              // ── Ligne principale ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 4),
                child: Row(
                  children: [
                    // Titre + récitateur
                    Expanded(
                      child: GestureDetector(
                        onTap: _openFullPlayer,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentTitleNotifier,
                              builder: (_, title, __) => Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentReciterNotifier,
                              builder: (_, name, __) => Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF374151),
                                ),
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
                        final state     = snapshot.data;
                        final isPlaying = state?.playing ?? false;
                        final loading   =
                            state?.processingState == ProcessingState.loading ||
                                state?.processingState ==
                                    ProcessingState.buffering;
                        if (loading) {
                          return const SizedBox(
                            width: 32, height: 32,
                            child: Center(
                              child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF38C172), strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFF111827),
                            size: 28,
                          ),
                          onPressed: _audio.togglePlayPause,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        );
                      },
                    ),

                  ],
                ),
              ),

              // ── Hints prev/next ───────────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          opacity: _showHints && prevName != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.only(
                                left: 12, right: 6),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xBB38C172),
                                  Colors.transparent
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 10),
                                Text(
                                  prevName ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: _showHints && nextName != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xBB38C172)
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white, size: 10),
                                Text(
                                  nextName ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

// ── Cercle récitateur (déborde de la pill, tap = toggle mode) ────────────────

class _ReciterCircle extends StatelessWidget {
  final VoidCallback onToggle;

  const _ReciterCircle({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const double size = 44.0;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: ValueListenableBuilder<String>(
            valueListenable: AudioService.instance.currentReciterNotifier,
            builder: (_, name, __) {
              final url = getReciterPhoto(name);
              if (url != null) {
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _soundBarsContainer(),
                );
              }
              return _soundBarsContainer();
            },
          ),
        ),
      ),
    );
  }

  Widget _soundBarsContainer() => Container(
        color: const Color(0xFFE8F5E9),
        child: const Center(
          child: AnimatedSoundBars(),
        ),
      );
}

