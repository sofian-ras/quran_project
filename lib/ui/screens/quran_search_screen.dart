import 'package:flutter/material.dart';
import '../widgets/quran_search_overlay.dart';
import 'reader_screen.dart';

/// Full-screen search launched from the home screen.
/// The overlay fills the screen; selecting a result pops this route and
/// pushes [ReaderScreen] directly to the page with the verse highlighted.
class QuranSearchScreen extends StatelessWidget {
  const QuranSearchScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const QuranSearchScreen(),
        fullscreenDialog: true,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: QuranSearchOverlay(
        onClose: () => Navigator.of(context).maybePop(),
        onNavigateToPage: (int page, int? surah, int? ayah) async {
          // Pop this search screen first (context is still valid here)
          Navigator.of(context).pop();
          // Then push the reader at the chosen page with optional highlight
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                initialPage: page,
                initialHighlightKey: surah != null && ayah != null
                    ? '$surah:$ayah'
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
