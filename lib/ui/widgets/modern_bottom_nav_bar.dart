import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Barre de navigation en deux demi-capsules avec FAB central flottant.
class ModernBottomNavBar extends StatelessWidget {
  final int index; // 0=Accueil 1=Prières 2=Du'a 3=Plus
  final ValueChanged<int> onChanged;
  final VoidCallback onCenterTap;

  const ModernBottomNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double barH    = 64.0;
    const double hMargin = 20.0;
    const double vMargin = 14.0;
    const double fabSize = 64.0;
    const double fabGap  = 20.0; // espace de chaque côté du FAB

    const Color bgColor  = Color(0x8CFFFFFF);
    const Color gold     = Color(0xFFB8860B);
    const Color inactive = Color(0x59000000); // 35 %

    void tapItem(int i) {
      if (i == index) return;
      HapticFeedback.selectionClick();
      onChanged(i);
    }

    Widget navItem(int i, IconData icon) {
      final bool sel = index == i;
      return Expanded(
        child: InkResponse(
          onTap: () => tapItem(i),
          radius: 28,
          highlightColor: gold.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AnimatedScale(
              scale: sel ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? gold.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 22, color: sel ? gold : inactive),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget halfBar(List<Widget> items) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColoredBox(
              color: bgColor,
              child: Material(
                color: Colors.transparent,
                child: Row(children: items),
              ),
            ),
          ),
        ),
      );
    }

    final double totalH = barH + vMargin + bottomInset + 12;

    return SizedBox(
      height: totalH,
      child: Stack(
        children: [
          // ── Deux demi-barres ──────────────────────────────────────────────
          Positioned(
            bottom: vMargin + bottomInset,
            left: 0,
            right: 0,
            height: barH,
            child: Row(
              children: [
                const SizedBox(width: hMargin),
                Expanded(
                  child: halfBar([
                    navItem(0, Icons.home_rounded),
                    navItem(1, Icons.mosque_rounded),
                  ]),
                ),
                const SizedBox(width: fabSize + fabGap * 2),
                Expanded(
                  child: halfBar([
                    navItem(2, Icons.auto_awesome_rounded),
                    navItem(3, Icons.more_horiz_rounded),
                  ]),
                ),
                const SizedBox(width: hMargin),
              ],
            ),
          ),

          // ── FAB centré entre les deux barres ─────────────────────────────
          Positioned(
            bottom: vMargin + bottomInset,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Ouvrir le Coran',
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B5E20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onCenterTap();
                      },
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/navbar/Quran_Kareem.svg',
                          width: 44,
                          height: 44,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFD4AF37),
                            BlendMode.srcIn,
                          ),
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
    );
  }
}