import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  late final AnimationController _fabCtrl;
  late final Animation<double> _fabScale;

  final Map<int, AnimationController> _iconCtrl = {};
  final Map<int, Animation<double>> _iconScale = {};

  // Pour le pulse logo au repos
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _fabCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _fabScale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.14)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(begin: 0.0, end: 0.25)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    for (int i = 0; i < 4; i++) {
      final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
      _iconCtrl[i] = ctrl;
      _iconScale[i] = Tween<double>(begin: 1.0, end: 0.72)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    _pulseCtrl.dispose();
    for (final c in _iconCtrl.values) c.dispose();
    super.dispose();
  }

  void _tapItem(int i) {
    if (i == widget.index) return;
    HapticFeedback.selectionClick();
    _iconCtrl[i]!.forward().then((_) => _iconCtrl[i]!.reverse());
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double fabSize = 60.0;
    const double barH = fabSize * 0.84;
    const double hMargin = 14.0;
    const double vMargin = 14.0;
    const double gap = 10.0;

    // ── Palette moderne ──────────────────────────────────────────────
    const Color accent     = Color(0xFF4CAF82);   // vert émeraude vif
    const Color accentDeep = Color(0xFF2E7D57);   // émeraude profond
    const Color inactive   = Color(0x66000000);
    const Color fabTop     = Color(0xFF43C98A);
    const Color fabBot     = Color(0xFF1B6B42);

    // ── navItem ──────────────────────────────────────────────────────
    Widget navItem(int i, IconData icon) {
      final bool sel = widget.index == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) { if (!sel) _iconCtrl[i]!.forward(); },
          onTapUp: (_)   { _iconCtrl[i]!.reverse(); _tapItem(i); },
          onTapCancel: () => _iconCtrl[i]!.reverse(),
          child: Center(
            child: AnimatedBuilder(
              animation: _iconScale[i]!,
              builder: (_, child) => Transform.scale(
                scale: _iconScale[i]!.value,
                child: child,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: sel ? accent.withValues(alpha: 0.50) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: sel ? 1.20 : 1.0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey(sel),
                        size: 21,
                        color: sel ? accent : inactive,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── FAB logo ─────────────────────────────────────────────────────
    Widget fabLogo() {
      return AnimatedBuilder(
        animation: Listenable.merge([_fabScale, _pulseScale, _pulseOpacity]),
        builder: (_, __) {
          return GestureDetector(
            onTapDown: (_) => _fabCtrl.forward(),
            onTapUp: (_) {
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
                      // Halo pulsant doux
                      Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: fabSize,
                          height: fabSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: _pulseOpacity.value),
                          ),
                        ),
                      ),
                      // Corps
                      Container(
                        width: fabSize,
                        height: fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [fabTop, fabBot],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentDeep.withValues(alpha: 0.50),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: accent.withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/images/navbar/Quran_Kareem.svg',
                            width: 32,
                            height: 32,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

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
            fabLogo(),
            const SizedBox(width: gap),
            Expanded(
              child: SizedBox(
                height: barH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(barH / 2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barH / 2),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.72),
                        child: Material(
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              navItem(0, Icons.home_rounded),
                              navItem(1, Icons.mosque_rounded),
                              navItem(2, Icons.auto_awesome_rounded),
                              navItem(3, Icons.more_horiz_rounded),
                            ],
                          ),
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
    );
  }
}