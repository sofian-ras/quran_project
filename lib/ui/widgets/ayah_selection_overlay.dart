// lib/ui/widgets/ayah_selection_overlay.dart
import 'package:flutter/material.dart';
import '../../services/quran_pages_hitbox_db.dart';

class AyahSelectionOverlay extends StatefulWidget {
  final int page;
  final Size displaySize;
  final Size imageSize;
  final String? selectedVerseKey;
  final void Function(int surah, int ayah) onAyahTapped;

  const AyahSelectionOverlay({
    super.key,
    required this.page,
    required this.displaySize,
    required this.imageSize,
    required this.selectedVerseKey,
    required this.onAyahTapped,
  });

  @override
  State<AyahSelectionOverlay> createState() => _AyahSelectionOverlayState();
}

class _AyahSelectionOverlayState extends State<AyahSelectionOverlay> {
  List<Rect> _wordRects = [];

  Future<void> _selectFromLocalPos(Offset localPos) async {
    final dx = localPos.dx.clamp(0.0, widget.displaySize.width);
    final dy = localPos.dy.clamp(0.0, widget.displaySize.height);

    final xImg = (dx / widget.displaySize.width) * widget.imageSize.width;
    final yImg = (dy / widget.displaySize.height) * widget.imageSize.height;

    final hit = await QuranPagesHitboxDb.instance.getAyahAt(
      page: widget.page,
      x: xImg,
      y: yImg,
    );

    if (!mounted) return;

    if (hit == null) {
      setState(() => _wordRects = []);
      widget.onAyahTapped(-1, -1);
      return;
    }

    final surah = hit['surah']!;
    final ayah = hit['ayah']!;

    final rects = await QuranPagesHitboxDb.instance.getAyahRects(
      page: widget.page,
      surah: surah,
      ayah: ayah,
    );

    if (!mounted) return;

    setState(() => _wordRects = rects);
    widget.onAyahTapped(surah, ayah);
  }

  @override
  void didUpdateWidget(covariant AyahSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedVerseKey == null && _wordRects.isNotEmpty) {
      setState(() => _wordRects = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _selectFromLocalPos(d.localPosition),
      onLongPressStart: (d) => _selectFromLocalPos(d.localPosition),
      child: CustomPaint(
        size: Size.infinite,
        painter: _AyahHighlightPainter(
          displaySize: widget.displaySize,
          imageSize: widget.imageSize,
          wordRects: _wordRects,
        ),
      ),
    );
  }
}

class _AyahHighlightPainter extends CustomPainter {
  final Size displaySize;
  final Size imageSize;
  final List<Rect> wordRects;

  _AyahHighlightPainter({
    required this.displaySize,
    required this.imageSize,
    required this.wordRects,
  });

  /// Regroupe les rects par ligne (Y-center similaires) et retourne
  /// le rect union de chaque ligne.
  List<Rect> _groupByLine(List<Rect> rects) {
    if (rects.isEmpty) return [];

    final scaleX = displaySize.width / imageSize.width;
    final scaleY = displaySize.height / imageSize.height;

    // Convertir en coordonnées écran
    final screen = rects.map((r) => Rect.fromLTRB(
      r.left * scaleX, r.top * scaleY,
      r.right * scaleX, r.bottom * scaleY,
    )).toList();

    // Trier par Y croissant
    screen.sort((a, b) => a.top.compareTo(b.top));

    final lines = <List<Rect>>[];
    for (final r in screen) {
      final center = (r.top + r.bottom) / 2;
      // Cherche une ligne existante dont l'intervalle vertical se chevauche
      final idx = lines.indexWhere((line) {
        final lineTop = line.map((x) => x.top).reduce((a, b) => a < b ? a : b);
        final lineBot = line.map((x) => x.bottom).reduce((a, b) => a > b ? a : b);
        return center >= lineTop && center <= lineBot;
      });
      if (idx >= 0) {
        lines[idx].add(r);
      } else {
        lines.add([r]);
      }
    }

    // Union de chaque ligne
    return lines.map((line) {
      final l = line.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final t = line.map((r) => r.top).reduce((a, b) => a < b ? a : b);
      final ri = line.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      final bo = line.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      return Rect.fromLTRB(l, t, ri, bo);
    }).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (wordRects.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0x66FFC107)
      ..style = PaintingStyle.fill;

    for (final r in _groupByLine(wordRects)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AyahHighlightPainter old) =>
      old.wordRects != wordRects ||
      old.displaySize != displaySize ||
      old.imageSize != imageSize;
}
