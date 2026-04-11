import 'package:flutter/material.dart';
import '../widgets/quran_search_overlay.dart';
import 'reader_screen.dart';

/// Ecran de recherche autonome — s'affiche EN OVERLAY sur le home screen.
/// Ne charge PAS le ReaderScreen tant qu'aucun résultat n'est sélectionné.
class QuranSearchScreen extends StatelessWidget {
  const QuranSearchScreen({super.key});

  /// Route transparente (le home screen reste visible derrière).
  static Route<void> route() => PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => const QuranSearchScreen(),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: QuranSearchOverlay(
        onClose: () => Navigator.of(context).pop(),
        onNavigateToPage: (page) async {
          // Ferme d'abord l'overlay de recherche…
          Navigator.of(context).pop();
          // …puis ouvre le lecteur directement à la bonne page.
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(initialPage: page),
            ),
          );
        },
      ),
    );
  }
}
