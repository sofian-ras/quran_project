import 'package:flutter/material.dart';

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

    const double barHeight = 72;
    const double centerSize = 68;
    const double outerPadding = 0; // avant: 16 (retiré pour éviter le fond visible derrière)
    const double bottomMargin = 0; // avant: 12 (retiré pour éviter le fond visible derrière)
    const double overlapIntoBar = 24;

    final Color active = AppColors.primaryAccent;
    final Color inactive = Colors.black.withOpacity(0.55);

    Widget navItem(int i, IconData icon, String label) {
      final bool isActive = index == i;
      final Color color = isActive ? active : inactive;

      return Expanded(
        child: InkResponse(
          onTap: () => onChanged(i),
          radius: 28,
          child: Padding(
            // avant: top 14 / bottom 10 (trop haut -> overflow)
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // avant: 26
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 2), // avant: 4
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // avant: 11
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4), // avant: 6
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  // avant: 3
                  height: 2,
                  width: isActive ? 20 : 0, // avant: 22
                  decoration: BoxDecoration(
                    color: active,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
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
                color: Colors.white,
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
                color: Colors.white,
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
                        navItem(1, Icons.play_arrow_rounded, 'Lectures'),
                        const SizedBox(width: centerSize),
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
            bottom: bottomMargin + 12, // remonte encore de 12px
            child: Center(
              child: GestureDetector(
                onTap: onCenterTap,
                child: Container(
                  width: centerSize,
                  height: centerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFE5F6EF),
                        Color(0xFF3A6B54),
                        Color(0xFF1E3A2F),
                      ],
                      center: Alignment(-0.2, -0.3),
                      radius: 0.95,
                    ),
                    border: Border.all(color: AppColors.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.45),
                        blurRadius: 32,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                      BoxShadow(
                        color: AppColors.shadowStrong,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 30,
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
