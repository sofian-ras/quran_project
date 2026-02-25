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

  // Press FAB
  late final AnimationController _fabCtrl;
  late final Animation<double>    _fabScale;

  // Halo FAB
  late final AnimationController _haloCtrl;
  late final Animation<double>    _haloScale;
  late final Animation<double>    _haloOpacity;

  // Press icônes
  final Map<int, AnimationController> _iconCtrl = {};
  final Map<int, Animation<double>>   _iconScale = {};

  @override
  void initState() {
    super.initState();

    _fabCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _fabScale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

    _haloCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _haloScale   = Tween<double>(begin: 1.0,  end: 1.18)
        .animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut));
    _haloOpacity = Tween<double>(begin: 0.18, end: 0.0)
        .animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut));

    for (int i = 0; i < 4; i++) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
      _iconCtrl[i]  = c;
      _iconScale[i] = Tween<double>(begin: 1.0, end: 0.70)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    _haloCtrl.dispose();
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

    const double fabSize  = 62.0;
    const double barH     = fabSize * 0.84;
    const double hMargin  = 14.0;
    const double vMargin  = 14.0;
    const double gap      = 10.0;

    // ── Palette gold ────────────────────────────────────────────────
    const Color gold       = Color(0xFFB8860B);
    const Color goldLight  = Color(0xFFD4AF37);
    const Color goldVif    = Color(0xFFFFCF40);
    const Color inactive   = Color(0x55000000);

    final List<IconData> icons = [
      Icons.home_rounded,
      Icons.mosque_rounded,
      Icons.auto_awesome_rounded,
      Icons.more_horiz_rounded,
    ];

    // ── Barre avec indicateur glissant ──────────────────────────────
    Widget navBar() {
      return Expanded(
        child: SizedBox(
          height: barH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barH / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: goldLight.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barH / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.78),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double totalW  = constraints.maxWidth;
                      final double itemW   = totalW / 4;
                      const double pillW = 44.0;

                      final double pillLeft = (widget.index == 0 || widget.index == 3)
                          ? widget.index * itemW
                          : widget.index * itemW + (itemW - pillW) / 2;

                      final double pillWidth = (widget.index == 0 || widget.index == 3)
                          ? itemW
                          : pillW;

                      return Stack(
                        children: [
                          // ── Indicateur glissant ──────────────────
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
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [goldVif, gold],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gold.withValues(alpha: 0.40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Icônes ───────────────────────────────
                          Row(
                            children: List.generate(4, (i) {
                              final bool sel = widget.index == i;
                              return SizedBox(
                                width: itemW,
                                height: barH,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown:  (_) { if (!sel) _iconCtrl[i]!.forward(); },
                                  onTapUp:    (_) { _iconCtrl[i]!.reverse(); _tapItem(i); },
                                  onTapCancel: () => _iconCtrl[i]!.reverse(),
                                  child: Center(
                                    child: AnimatedBuilder(
                                      animation: _iconScale[i]!,
                                      builder: (_, child) => Transform.scale(
                                        scale: _iconScale[i]!.value,
                                        child: child,
                                      ),
                                      child: AnimatedScale(
                                        scale: sel ? 1.18 : 1.0,
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.elasticOut,
                                        child: Icon(
                                          icons[i],
                                          size: 21,
                                          color: sel ? Colors.white : inactive,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── FAB logo stylé ───────────────────────────────────────────────
    Widget fabLogo() {
      return AnimatedBuilder(
        animation: Listenable.merge([_fabScale, _haloScale, _haloOpacity]),
        builder: (_, __) => GestureDetector(
          onTapDown:  (_) => _fabCtrl.forward(),
          onTapUp:    (_) { _fabCtrl.reverse(); HapticFeedback.mediumImpact(); widget.onCenterTap(); },
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
                    // Halo pulsant
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

                    // Corps — verre dépoli
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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/images/navbar/Quran_Kareem.svg',
                                width: 42,
                                height: 42,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
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
            navBar(),
          ],
        ),
      ),
    );
  }
}