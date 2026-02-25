// lib/ui/widgets/floating_bottom_nav.dart
//
// Barre de navigation flottante capsule.
//
// Usage minimal :
//
//   int _navIndex = 0;
//
//   Scaffold(
//     body: Stack(
//       children: [
//         IndexedStack(index: _navIndex, children: [...]),
//         FloatingBottomNav(
//           currentIndex: _navIndex,
//           onTap: (i) => setState(() => _navIndex = i),
//         ),
//       ],
//     ),
//   )

import 'package:flutter/material.dart';

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(icon: Icons.home_rounded,       label: 'Accueil'),
    _NavItem(icon: Icons.menu_book_rounded,  label: 'Coran'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'Du\'a'),
    _NavItem(icon: Icons.settings_rounded,   label: 'Réglages'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Couleurs selon le thème
    const bgLight  = Color(0xFFF5EDD8); // beige chaud
    const bgDark   = Color(0xFF1A2420); // vert sombre
    const selLight = Color(0xFF2E7D32); // vert islamique
    const selDark  = Color(0xFF66BB6A); // vert clair sur fond sombre
    const unselLight = Color(0xFF7A7060);
    const unselDark  = Color(0xFF8EA89A);

    final bg     = isDark ? bgDark   : bgLight;
    final selCol = isDark ? selDark  : selLight;
    final unsel  = isDark ? unselDark : unselLight;

    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomPad + 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final item = _items[i];
              return Expanded(
                child: _NavButton(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  selectedColor: selCol,
                  unselectedColor: unsel,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Bouton individuel ─────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: selected ? 11 : 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
