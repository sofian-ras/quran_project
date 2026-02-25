import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Barre de navigation flottante capsule avec encoche centrale.
/// À utiliser dans [Scaffold.bottomNavigationBar] avec [extendBody: true].
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const double barH      = 64.0;
    const double hMargin   = 20.0;
    const double vMargin   = 14.0;
    const double fabSize   = 64.0;
    const double notchR    = fabSize / 2 + 10; // 42 — marge autour du FAB
    const double overflowH = fabSize / 2;      // 32 — hauteur qui dépasse au-dessus

    final Color bgColor = isDark
        ? const Color(0xAAFFFFFF)
        : const Color(0xBBFFFFFF);

    const Color active   = Color.fromARGB(255, 45, 197, 83);
    const Color inactive = Color.fromARGB(128, 13, 100, 20);

    void tapItem(int i) {
      if (i == index) return;
      HapticFeedback.selectionClick();
      onChanged(i);
    }

    Widget navItem(int i, IconData icon, String label) {
      final bool sel = index == i;
      final Color col = sel ? active : inactive;
      return Expanded(
        child: InkResponse(
          onTap: () => tapItem(i),
          radius: 28,
          highlightColor: active.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedScale(
              scale: sel ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: col),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: col,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    width: sel ? 18 : 0,
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final double totalH = barH + overflowH + vMargin + bottomInset;

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Barre avec encoche ─────────────────────────────────────────────
          Positioned(
            bottom: vMargin + bottomInset,
            left: hMargin,
            right: hMargin,
            height: barH,
            child: _ShadowedNotchedBar(
              notchRadius: notchR,
              isDark: isDark,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: bgColor,
                  child: Material(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        navItem(0, Icons.home_rounded,         'Accueil'),
                        navItem(1, Icons.mosque_rounded,       'Prières'),
                        const SizedBox(width: notchR * 2), // espace encoche
                        navItem(2, Icons.auto_awesome_rounded, "Du'a"),
                        navItem(3, Icons.more_horiz_rounded,   'Plus'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bouton Coran flottant ──────────────────────────────────────────
          Positioned(
            top: 0,
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
                    color: const Color(0xFF1B5E20), // vert foncé
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.50),
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

// ── Wrapper qui applique ombre + clip encoche ──────────────────────────────────

class _ShadowedNotchedBar extends StatelessWidget {
  final double notchRadius;
  final bool isDark;
  final Widget child;

  const _ShadowedNotchedBar({
    required this.notchRadius,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedShadowPainter(
        notchRadius: notchRadius,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
      ),
      child: ClipPath(
        clipper: _NotchedClipper(notchRadius: notchRadius),
        child: child,
      ),
    );
  }
}

// ── Ombre dessinée derrière l'encoche ─────────────────────────────────────────

class _NotchedShadowPainter extends CustomPainter {
  final double notchRadius;
  final Color shadowColor;

  const _NotchedShadowPainter({
    required this.notchRadius,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    canvas.drawShadow(
      _buildPath(size, notchRadius),
      shadowColor,
      8,
      false,
    );
    // Fond transparent pour que le shadow soit visible
    canvas.drawPath(_buildPath(size, notchRadius), paint);
  }

  @override
  bool shouldRepaint(_NotchedShadowPainter old) =>
      old.notchRadius != notchRadius || old.shadowColor != shadowColor;
}

// ── Clipper capsule avec encoche concave en haut au centre ────────────────────

class _NotchedClipper extends CustomClipper<Path> {
  final double notchRadius;
  const _NotchedClipper({required this.notchRadius});

  @override
  Path getClip(Size size) => _buildPath(size, notchRadius);

  @override
  bool shouldReclip(_NotchedClipper old) => old.notchRadius != notchRadius;
}

Path _buildPath(Size size, double notchR) {
  const double br = 32.0; // rayon des coins de la capsule
  final double cx = size.width / 2;

  return Path()
    ..moveTo(br, 0)
    ..lineTo(cx - notchR, 0)
    // encoche concave (arc vers le bas)
    ..arcToPoint(
      Offset(cx + notchR, 0),
      radius: Radius.circular(notchR),
      clockwise: false,
    )
    ..lineTo(size.width - br, 0)
    ..arcToPoint(Offset(size.width, br),         radius: const Radius.circular(br))
    ..lineTo(size.width, size.height - br)
    ..arcToPoint(Offset(size.width - br, size.height), radius: const Radius.circular(br))
    ..lineTo(br, size.height)
    ..arcToPoint(Offset(0, size.height - br),    radius: const Radius.circular(br))
    ..lineTo(0, br)
    ..arcToPoint(const Offset(32, 0),              radius: const Radius.circular(br))
    ..close();
}
