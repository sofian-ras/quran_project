// lib/ui/widgets/ayah_selection_overlay.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../services/quran_pages_hitbox_db.dart';

class AyahSelectionOverlay extends StatefulWidget {
  final int page;
  final Size displaySize;
  final Size imageSize;

  /// Verset sélectionné (bulle) — surbrillance jaune existante.
  final String? selectedVerseKey;

  /// Verset en cours de lecture — surbrillance verte vive.
  final String? playingAyahKey;

  /// Plage de sélection mini lecteur — surbrillance verte légère.
  final String? selectionStartKey;
  final String? selectionEndKey;

  /// Versets ayant une note — surbrillance gris léger.
  final Set<String> noteAyahKeys;

  /// Appelé avec (surah, ayah, globalRect) sur tap simple (verset ou -1 si vide).
  final void Function(int surah, int ayah, Rect? globalRect) onAyahTap;

  /// Appelé avec (surah, ayah, globalRect) sur long-press (verset ou -1 si vide).
  final void Function(int surah, int ayah, Rect? globalRect) onAyahLongPress;

  const AyahSelectionOverlay({
    super.key,
    required this.page,
    required this.displaySize,
    required this.imageSize,
    required this.selectedVerseKey,
    required this.onAyahTap,
    required this.onAyahLongPress,
    this.playingAyahKey,
    this.selectionStartKey,
    this.selectionEndKey,
    this.noteAyahKeys = const {},
  });

  @override
  State<AyahSelectionOverlay> createState() => _AyahSelectionOverlayState();
}

class _AyahSelectionOverlayState extends State<AyahSelectionOverlay> {
  /// Rects du verset sélectionné (bulle) — jaune.
  List<Rect> _wordRects = [];

  /// Rects du verset en cours de lecture — vert vif.
  List<Rect> _playingRects = [];

  /// Rects de la plage sélectionnée — vert léger.
  List<Rect> _selectionRects = [];

  /// Rects des versets avec note — gris léger.
  List<Rect> _noteRects = [];

  /// Position du dernier onTapDown pour l'identifier dans onTap.
  Offset? _lastTapDownPos;

  // ── Résolution position → verset ─────────────────────────────────────────

  Future<void> _selectFromLocalPos(
    Offset localPos,
    void Function(int surah, int ayah, Rect? globalRect) callback,
  ) async {
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
      callback(-1, -1, null);
      return;
    }

    final surah = hit['surah']!;
    final ayah  = hit['ayah']!;

    final rects = await QuranPagesHitboxDb.instance.getAyahRects(
      page: widget.page,
      surah: surah,
      ayah: ayah,
    );

    if (!mounted) return;

    Rect? globalRect;
    if (rects.isNotEmpty) {
      final ro = context.findRenderObject() as RenderBox?;
      if (ro != null && ro.hasSize) {
        final sx = widget.displaySize.width / widget.imageSize.width;
        final sy = widget.displaySize.height / widget.imageSize.height;
        double minX = double.infinity, minY = double.infinity;
        double maxX = -double.infinity, maxY = -double.infinity;
        for (final r in rects) {
          if (r.left * sx < minX) minX = r.left * sx;
          if (r.top * sy < minY) minY = r.top * sy;
          if (r.right * sx > maxX) maxX = r.right * sx;
          if (r.bottom * sy > maxY) maxY = r.bottom * sy;
        }
        final gTL = ro.localToGlobal(Offset(minX, minY));
        final gBR = ro.localToGlobal(Offset(maxX, maxY));
        globalRect = Rect.fromPoints(gTL, gBR);
      }
    }

    callback(surah, ayah, globalRect);
  }

  // ── Chargement des rects de lecture ──────────────────────────────────────

  Future<void> _loadPlayingRects() async {
    final key = widget.playingAyahKey;
    if (key == null) {
      if (mounted) setState(() => _playingRects = []);
      return;
    }
    final parts = key.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final ayah  = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return;

    final rects = await QuranPagesHitboxDb.instance.getAyahRects(
      page: widget.page,
      surah: surah,
      ayah: ayah,
    );
    if (mounted) setState(() => _playingRects = rects);
  }

  // ── Chargement des rects de sélection de plage ───────────────────────────

  Future<void> _loadSelectionRects() async {
    final startKey = widget.selectionStartKey;
    final endKey   = widget.selectionEndKey;

    if (startKey == null) {
      if (mounted) setState(() => _selectionRects = []);
      return;
    }

    final startParts = startKey.split(':');
    if (startParts.length != 2) return;
    final surah      = int.tryParse(startParts[0]);
    final startAyah  = int.tryParse(startParts[1]);
    if (surah == null || startAyah == null) return;

    int endAyah = startAyah;
    if (endKey != null) {
      final endParts = endKey.split(':');
      if (endParts.length == 2) {
        final es = int.tryParse(endParts[0]);
        final ea = int.tryParse(endParts[1]);
        if (es == surah && ea != null) endAyah = ea;
      }
    }

    final rects = await QuranPagesHitboxDb.instance.getAyahRectsInRange(
      page: widget.page,
      surah: surah,
      startAyah: startAyah,
      endAyah: endAyah,
    );
    if (mounted) setState(() => _selectionRects = rects);
  }

  // ── Chargement des rects de versets notés ────────────────────────────────

  Future<void> _loadNoteRects() async {
    if (widget.noteAyahKeys.isEmpty) {
      if (mounted) setState(() => _noteRects = []);
      return;
    }
    final all = <Rect>[];
    for (final key in widget.noteAyahKeys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah  = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;
      final rects = await QuranPagesHitboxDb.instance.getAyahRects(
        page: widget.page, surah: surah, ayah: ayah,
      );
      all.addAll(rects);
    }
    if (mounted) setState(() => _noteRects = all);
  }

  // ── Cycle de vie ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadPlayingRects();
    _loadSelectionRects();
    _loadNoteRects();
  }

  @override
  void didUpdateWidget(covariant AyahSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedVerseKey == null && _wordRects.isNotEmpty) {
      setState(() => _wordRects = []);
    }

    if (widget.playingAyahKey != oldWidget.playingAyahKey) {
        _loadPlayingRects();
    }

    if (widget.selectionStartKey != oldWidget.selectionStartKey ||
        widget.selectionEndKey   != oldWidget.selectionEndKey) {
      _loadSelectionRects();
    }

    if (widget.noteAyahKeys != oldWidget.noteAyahKeys) {
      _loadNoteRects();
    }

  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer instance) {
            instance.onTapDown = (d) => _lastTapDownPos = d.localPosition;
            instance.onTap = () {
              final pos = _lastTapDownPos;
              if (pos != null) {
                _selectFromLocalPos(pos, widget.onAyahTap);
              }
            };
          },
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 200)),
          (LongPressGestureRecognizer instance) {
            instance.onLongPressStart =
                (d) => _selectFromLocalPos(d.localPosition, widget.onAyahLongPress);
          },
        ),
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _AyahHighlightPainter(
          displaySize:    widget.displaySize,
          imageSize:      widget.imageSize,
          wordRects:      _wordRects,
          playingRects:   _playingRects,
          selectionRects: _selectionRects,
          noteRects:      _noteRects,
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AyahHighlightPainter extends CustomPainter {
  final Size displaySize;
  final Size imageSize;
  final List<Rect> wordRects;      // bulle sélection — jaune
  final List<Rect> playingRects;   // verset en lecture — vert vif
  final List<Rect> selectionRects; // plage mini lecteur — vert léger
  final List<Rect> noteRects;      // versets notés — gris léger

  _AyahHighlightPainter({
    required this.displaySize,
    required this.imageSize,
    required this.wordRects,
    required this.playingRects,
    required this.selectionRects,
    this.noteRects = const [],
  });

  List<Rect> _groupByLine(List<Rect> rects) {
    if (rects.isEmpty) return [];

    final sx = displaySize.width  / imageSize.width;
    final sy = displaySize.height / imageSize.height;

    final screen = rects
        .map((r) => Rect.fromLTRB(
              r.left * sx, r.top * sy, r.right * sx, r.bottom * sy))
        .toList();
    screen.sort((a, b) => a.top.compareTo(b.top));

    final lines = <List<Rect>>[];
    for (final r in screen) {
      final center = (r.top + r.bottom) / 2;
      final idx = lines.indexWhere((line) {
        final lt = line.map((x) => x.top).reduce((a, b) => a < b ? a : b);
        final lb = line.map((x) => x.bottom).reduce((a, b) => a > b ? a : b);
        return center >= lt && center <= lb;
      });
      if (idx >= 0) {
        lines[idx].add(r);
      } else {
        lines.add([r]);
      }
    }

    return lines.map((line) {
      final l  = line.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final t  = line.map((r) => r.top).reduce((a, b) => a < b ? a : b);
      final ri = line.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      final bo = line.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      return Rect.fromLTRB(l, t, ri, bo);
    }).toList();
  }

  void _drawRects(Canvas canvas, List<Rect> rects, Color color) {
    if (rects.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final r in _groupByLine(rects)) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Versets notés (couche la plus basse) — gris très léger
    _drawRects(canvas, noteRects,      const Color(0x25909090));
    // 2. Plage de sélection — vert très léger
    _drawRects(canvas, selectionRects, const Color(0x3581C784));
    // 3. Verset en lecture — vert vif
    _drawRects(canvas, playingRects,   const Color(0xAA4CAF50));
    // 4. Verset sélectionné (bulle) — jaune
    _drawRects(canvas, wordRects,      const Color(0x55FFD54F));
  }

  @override
  bool shouldRepaint(covariant _AyahHighlightPainter old) =>
      old.wordRects      != wordRects      ||
      old.playingRects   != playingRects   ||
      old.selectionRects != selectionRects ||
      old.noteRects      != noteRects      ||
      old.displaySize    != displaySize    ||
      old.imageSize      != imageSize;
}
