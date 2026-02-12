import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';

class ModernBottomNavBar extends StatelessWidget {
  final int index; // 0..3
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
    final screenW = MediaQuery.of(context).size.width;

    const double barHeight = 72;
    const double centerSize = 68;
    const double outerPadding = 0;
    const double bottomMargin = 0;

    const Color beige = Color(0xFFF3EBDD);
    final Color active = AppColors.primaryAccent;
    final Color inactive = Colors.black.withOpacity(0.55);

    final double centerGap = screenW < 360 ? centerSize * 0.86 : centerSize;

    void _tapItem(int i) {
      if (i == index) return;
      HapticFeedback.selectionClick();
      onChanged(i);
    }

    Widget navItem(int i, IconData icon, String label) {
      final bool isActive = index == i;
      final Color color = isActive ? active : inactive;

      return Expanded(
        child: Semantics(
          button: true,
          selected: isActive,
          label: label,
          child: InkResponse(
            onTap: () => _tapItem(i),
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, isActive ? -2 : 0, 0),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  scale: isActive ? 1.06 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 24, color: color),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        height: 2,
                        width: isActive ? 20 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? active : active.withOpacity(0.0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ✅ Logo Coran amélioré : icône plus jolie + doré en dégradé + léger glow
    Widget quranIconGold(double size) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF2B0), // highlight
              Color(0xFFD4AF37), // gold
              Color(0xFFB8860B), // deep gold
            ],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcIn,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ombre fine (relief)
            Transform.translate(
              offset: const Offset(0, 1.2),
              child: Icon(
                Icons.import_contacts_rounded,
                size: size,
                color: Colors.black.withOpacity(0.18),
              ),
            ),
            // main (doré via ShaderMask)
            Icon(
              Icons.import_contacts_rounded,
              size: size,
              color: Colors.white,
            ),
          ],
        ),

      );
    }

    return SizedBox(
      height: barHeight + bottomInset + bottomMargin,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: outerPadding,
            right: outerPadding,
            bottom: bottomMargin,
            child: Container(
              decoration: BoxDecoration(
                color: beige,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: beige,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: barHeight + bottomInset,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Row(
                      children: [
                        navItem(0, Icons.home_rounded, 'Accueil'),
                        navItem(1, Icons.mosque_rounded, 'Prières'),
                        SizedBox(width: centerGap),
                        navItem(2, Icons.favorite_rounded, 'Favoris'),
                        navItem(3, Icons.more_horiz_rounded, 'Plus'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomMargin,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: const Offset(0, -20), // monte le logo proprement
                child: Semantics(
                  button: true,
                  label: 'Ouvrir le lecteur',
                  child: InkResponse(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onCenterTap();
                    },
                    radius: 34,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                        'assets/images/navbar/Quran_Kareem.svg',
                        width: 45,
                        height: 45,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFD4AF37), // doré (change si tu veux)
                          BlendMode.srcIn,
                        ),
                      ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFFFF2B0),
                                Color(0xFFD4AF37),
                                Color(0xFFB8860B),
                              ],
                            ),
                          ),
                        ),
                      ],
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
