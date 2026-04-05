import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/surah_name.dart';
import '../../services/audio_service.dart';
import '../../services/navigation_service.dart';
import '../screens/music_player_fullscreen.dart';
import '../../services/radio_service.dart';
import '../screens/radio_browser_screen.dart';
import '../screens/radio_player_screen.dart';
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
  bool     _isAudioActive = false;
  bool     _isPlayerMode  = true;
  bool     _isRadioMode   = false;
  double?  _seekFraction;
  Duration? _seekDragPos;
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
    AudioService.instance.isRadioModeNotifier.addListener(_onRadioModeChanged);
  }

  void _onRadioModeChanged() {
    if (!mounted) return;
    final isRadio = AudioService.instance.isRadioModeNotifier.value;
    setState(() {
      _isRadioMode = isRadio;
      if (isRadio) {
        // Forcer le mode player + nettoyer le state seek quand la radio démarre.
        _isPlayerMode = true;
        _seekFraction = null;
        _seekDragPos  = null;
      }
    });
  }

  @override
  void dispose() {
    _activeSub.cancel();
    AudioService.instance.isRadioModeNotifier.removeListener(_onRadioModeChanged);
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
    const double seekH = 10.0;
    final double radius = barH / 2;
    final double pillH  = showPlayer ? (_isRadioMode ? barH : barH + seekH) : barH;

    return Expanded(
      child: LayoutBuilder(builder: (_, constraints) {
        final pillW = constraints.maxWidth;
        return AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Verre dépoli ─────────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Contenu principal (toujours barH)
                          SizedBox(
                            height: barH,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: showPlayer
                                  ? (_isRadioMode
                                      ? _RadioPillContent(
                                          key: const ValueKey('radio'),
                                          onDismiss: AudioService.instance.stopAll,
                                        )
                                      : _PlayerPillContent(
                                          key: const ValueKey('player'),
                                          onDismiss: AudioService.instance.stopAll,
                                        ))
                                  : _NavIconsContent(
                                      key: const ValueKey('nav'),
                                      selectedIndex: widget.index,
                                      iconCtrl: _iconCtrl,
                                      iconScale: _iconScale,
                                      barH: barH,
                                      onTap: _tapItem,
                                      hasCircle: _isAudioActive,
                                    ),
                            ),
                          ),
                          // Seek bar — cachée en mode radio (stream live)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            clipBehavior: Clip.hardEdge,
                            child: (showPlayer && !_isRadioMode)
                                ? SizedBox(
                                    height: seekH,
                                    child: SeekBar(
                                      audio: AudioService.instance,
                                      accent: const Color(0xFF38C172),
                                      compact: true,
                                      onDragChanged: (f, pos) => setState(() {
                                        _seekFraction = f;
                                        _seekDragPos  = pos;
                                      }),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Cercle récitateur / radio (toggle nav↔player) ───────────
            if (_isAudioActive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: barH,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: showPlayer
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: _isRadioMode
                        ? _RadioCircle(
                            onToggle: () {
                              final station = RadioService.instance
                                  .currentStationNotifier.value;
                              if (station == null) return;
                              Navigator.of(context, rootNavigator: true).push(
                                PageRouteBuilder<void>(
                                  opaque: true,
                                  pageBuilder: (_, __, ___) =>
                                      RadioPlayerScreen(station: station),
                                  transitionsBuilder: (_, anim, __, child) =>
                                      SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 1),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                            parent: anim,
                                            curve: Curves.easeOutCubic)),
                                        child: child,
                                      ),
                                  transitionDuration:
                                      const Duration(milliseconds: 300),
                                ),
                              );
                            },
                          )
                        : _ReciterCircle(
                            onToggle: () => setState(() {
                              _isPlayerMode = !_isPlayerMode;
                              if (!_isPlayerMode) {
                                _seekFraction = null;
                                _seekDragPos  = null;
                              }
                            }),
                          ),
                  ),
                ),
              ),

            // ── Temps total (hors ClipRRect, sous la pill) ──────────────
            if (showPlayer && !_isRadioMode && _seekDragPos == null)
              Positioned(
                right: 8,
                bottom: -12,
                child: StreamBuilder<PositionData>(
                  stream: AudioService.instance.positionDataStream,
                  builder: (_, snap) {
                    final total = snap.data?.duration ?? Duration.zero;
                    if (total == Duration.zero) return const SizedBox.shrink();
                    return Text(
                      _fmtDur(total),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF38C172),
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),

            // ── Tooltip position drag (suit le pouce) ───────────────────
            if (showPlayer && !_isRadioMode && _seekDragPos != null)
              Positioned(
                left: ((_seekFraction ?? 0) * pillW - 18).clamp(0.0, pillW - 36.0),
                bottom: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38C172),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _fmtDur(_seekDragPos!),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        );   // AnimatedContainer
      }),    // LayoutBuilder
    );       // Expanded
  }

  String _fmtDur(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
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
  final bool hasCircle;

  const _NavIconsContent({
    super.key,
    required this.selectedIndex,
    required this.iconCtrl,
    required this.iconScale,
    required this.barH,
    required this.onTap,
    this.hasCircle = false,
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
        // Reserve 48px on the right when circle is present
        final double navW  = hasCircle ? totalW - 48 : totalW;
        final double itemW = navW / 4;
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

// ── Contenu radio : nom + badge LIVE + play/pause ────────────────────────────

class _RadioPillContent extends StatefulWidget {
  final VoidCallback onDismiss;
  const _RadioPillContent({super.key, required this.onDismiss});
  @override
  State<_RadioPillContent> createState() => _RadioPillContentState();
}

class _RadioPillContentState extends State<_RadioPillContent> {
  final _audio = AudioService.instance;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 0 || _dy > 0) {
          setState(() => _dy = (_dy + d.delta.dy).clamp(0.0, 60.0));
        }
      },
      onVerticalDragEnd: (d) {
        if (_dy > 30 || d.velocity.pixelsPerSecond.dy > 400) widget.onDismiss();
        setState(() => _dy = 0);
      },
      onVerticalDragCancel: () => setState(() => _dy = 0),
      child: Transform.translate(
        offset: Offset(0, _dy),
        child: Padding(
          padding: const EdgeInsets.only(left: 56, right: 8),
          child: Row(
            children: [
              // ── Nom tappable ──────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () => RadioBrowserScreen.show(context),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _audio.currentTitleNotifier,
                    builder: (_, name, __) => Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // ── Badge LIVE ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // ── Play / Pause ──────────────────────────────────────────
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (_, snap) {
                  final st      = snap.data;
                  final playing = st?.playing ?? false;
                  final loading = st?.processingState == ProcessingState.loading ||
                      st?.processingState == ProcessingState.buffering;
                  if (loading) {
                    return const SizedBox(
                      width: 36, height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            color: Color(0xFFDC2626), strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return IconButton(
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF111827),
                      size: 28,
                    ),
                    onPressed: _audio.togglePlayPause,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  );
                },
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
          child: ValueListenableBuilder<String?>(
            valueListenable: AudioService.instance.currentReciterAssetNotifier,
            builder: (_, assetPath, __) {
              if (assetPath != null && assetPath.isNotEmpty) {
                return Image.asset(
                  assetPath,
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

// ── Cercle radio (toggle nav↔player en mode radio) ────────────────────────────

class _RadioCircle extends StatelessWidget {
  final VoidCallback onToggle;
  const _RadioCircle({required this.onToggle});

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
          color: const Color(0xFFDC2626),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.radio_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

