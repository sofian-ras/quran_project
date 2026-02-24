// lib/ui/widgets/ayah_selection_overlay.dart
//
// Widget overlay transparent posé AU-DESSUS de l'image PNG.
// Il dessine les rectangles de surbrillance et détecte les taps.
//
// Usage :
//   Stack(children: [
//     Image.file(pageFile, fit: BoxFit.contain),
//     AyahSelectionOverlay(
//       page: currentPage,
//       imageSize: Size(imageWidth, imageHeight),   // taille réelle du PNG
//       displaySize: Size(containerW, containerH),  // taille affichée à l'écran
//       onAyahTapped: (surah, ayah) { ... },
//     ),
//   ])

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/quran_pages_hitbox_db.dart';

class AyahSelectionOverlay extends StatefulWidget {
  final int page;

  /// Taille RÉELLE du fichier PNG (ex: 1280×1810).
  /// Récupérée avec decodeImageFromList ou stockée en dur selon ta DB.
  /// Si null, l'overlay utilise les coordonnées normalisées [0..1].
  final Size? imageSize;

  /// Taille affichée dans le widget à l'écran (LayoutBuilder ou MediaQuery).
  final Size displaySize;

  /// Callback quand l'utilisateur tape sur un verset.
  final void Function(int surah, int ayah)? onAyahTapped;

  /// Verset actuellement sélectionné (pour le surligner différemment).
  final String? selectedVerseKey; // format "surah:ayah"

  /// Chemin optionnel vers la DB (si différent du chemin par défaut).
  final String? dbPathOverride;

  const AyahSelectionOverlay({
    super.key,
    required this.page,
    required this.displaySize,
    this.imageSize,
    this.onAyahTapped,
    this.selectedVerseKey,
    this.dbPathOverride,
  });

  @override
  State<AyahSelectionOverlay> createState() => _AyahSelectionOverlayState();
}

class _AyahSelectionOverlayState extends State<AyahSelectionOverlay> {
  List<AyahBox> _boxes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  @override
  void didUpdateWidget(AyahSelectionOverlay old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _boxes = [];
      _loading = true;
      _loadBoxes();
    }
  }

  Future<void> _loadBoxes() async {
    try {
      final boxes = await QuranPagesHitboxDb.instance.getPageBoxes(
        widget.page,
        dbPathOverride: widget.dbPathOverride,
      );
      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AyahSelectionOverlay: erreur chargement page ${widget.page}: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // Convertit les coordonnées DB → coordonnées écran.
  //
  // Deux cas :
  //   - imageSize fournie : les coords DB sont en pixels absolus PNG → on scale.
  //   - imageSize null    : les coords DB sont déjà normalisées [0..1] → on multiplie.
  Rect _toScreenRect(AyahBox box) {
    final dw = widget.displaySize.width;
    final dh = widget.displaySize.height;

    if (widget.imageSize != null) {
      final sx = dw / widget.imageSize!.width;
      final sy = dh / widget.imageSize!.height;
      return Rect.fromLTWH(
        box.x * sx,
        box.y * sy,
        box.w * sx,
        box.h * sy,
      );
    } else {
      // Coordonnées normalisées
      return Rect.fromLTWH(
        box.x * dw,
        box.y * dh,
        box.w * dw,
        box.h * dh,
      );
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    final pos = e.localPosition;
    for (final box in _boxes) {
      final rect = _toScreenRect(box);
      if (rect.inflate(4).contains(pos)) {
        widget.onAyahTapped?.call(box.surah, box.ayah);
        return;
      }
    }
    widget.onAyahTapped?.call(-1, -1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _boxes.isEmpty) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        child: SizedBox(
          width: widget.displaySize.width,
          height: widget.displaySize.height,
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: CustomPaint(
        size: widget.displaySize,
        painter: _AyahHighlightPainter(
          boxes: _boxes,
          selectedVerseKey: widget.selectedVerseKey,
          toScreenRect: _toScreenRect,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _AyahHighlightPainter extends CustomPainter {
  final List<AyahBox> boxes;
  final String? selectedVerseKey;
  final Rect Function(AyahBox) toScreenRect;
  final bool isDark;

  _AyahHighlightPainter({
    required this.boxes,
    required this.selectedVerseKey,
    required this.toScreenRect,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedVerseKey == null) return;

    final parts = selectedVerseKey!.split(':');
    if (parts.length != 2) return;
    final selSurah = int.tryParse(parts[0]);
    final selAyah = int.tryParse(parts[1]);
    if (selSurah == null || selAyah == null) return;

    // Couleur de surlignage : dorée semi-transparente (adapte selon ton thème)
    final highlightPaint = Paint()
      ..color = isDark
          ? const Color(0x55F5D278) // doré clair mode sombre
          : const Color(0x44E8B84B) // doré mode clair
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDark
          ? const Color(0xCCF5D278)
          : const Color(0xCCB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final box in boxes) {
      if (box.surah == selSurah && box.ayah == selAyah) {
        final rect = toScreenRect(box);
        final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rRect, highlightPaint);
        canvas.drawRRect(rRect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AyahHighlightPainter old) =>
      old.selectedVerseKey != selectedVerseKey || old.isDark != isDark;
}
