// lib/ui/widgets/ayah_bubble.dart
//
// Bulle d'actions flottante qui s'affiche au-dessus du verset sélectionné.
// Actions : Écouter · Copier · Partager · Tafsir
//
// Usage :
//   AyahBubble.show(context, surah: 2, ayah: 255, anchorGlobalRect: rect,
//                   onDismiss: () { ... });
//   AyahBubble.dismiss();

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/mini_player_service.dart';
import '../../services/quran_text_db.dart';
import '../../surah_name.dart';
import 'ayah_action_sheet.dart';

class AyahBubble {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required int surah,
    required int ayah,
    required Rect anchorGlobalRect,
    required VoidCallback onDismiss,
    VoidCallback? onSetRangePoint,
    bool hasRangeStart = false,
  }) {
    dismiss();
    _entry = OverlayEntry(
      builder: (_) => _BubbleLayout(
        surah: surah,
        ayah: ayah,
        anchorGlobalRect: anchorGlobalRect,
        onDismiss: () {
          dismiss();
          onDismiss();
        },
        onSetRangePoint: onSetRangePoint,
        hasRangeStart: hasRangeStart,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

// ── Layout principal ─────────────────────────────────────────────────────────

class _BubbleLayout extends StatelessWidget {
  final int surah;
  final int ayah;
  final Rect anchorGlobalRect;
  final VoidCallback onDismiss;
  final VoidCallback? onSetRangePoint;
  final bool hasRangeStart;

  const _BubbleLayout({
    required this.surah,
    required this.ayah,
    required this.anchorGlobalRect,
    required this.onDismiss,
    this.onSetRangePoint,
    this.hasRangeStart = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleW = onSetRangePoint != null ? 290.0 : 244.0;
    const bubbleH = 72.0; // hauteur approximative de la bulle
    const caretH = 8.0;
    const margin = 8.0;
    final screenW = MediaQuery.of(context).size.width;

    // Centré sur le verset, collé aux bords si nécessaire
    double left = anchorGlobalRect.center.dx - bubbleW / 2;
    left = left.clamp(margin, screenW - bubbleW - margin);

    // Au-dessus si assez de place, sinon en-dessous
    final showAbove = anchorGlobalRect.top > bubbleH + caretH + 16;
    final top = showAbove
        ? anchorGlobalRect.top - bubbleH - caretH
        : anchorGlobalRect.bottom + caretH;

    // Position X de la pointe du caret
    final caretX =
        (anchorGlobalRect.center.dx - left).clamp(16.0, bubbleW - 16.0);

    return Stack(
      children: [
        // Fond transparent qui capture les taps extérieurs
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // La bulle elle-même
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: _Bubble(
              surah: surah,
              ayah: ayah,
              onDismiss: onDismiss,
              caretOnBottom: showAbove,
              caretX: caretX,
              onSetRangePoint: onSetRangePoint,
              hasRangeStart: hasRangeStart,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bulle ────────────────────────────────────────────────────────────────────

class _Bubble extends StatefulWidget {
  final int surah;
  final int ayah;
  final VoidCallback onDismiss;
  final bool caretOnBottom;
  final double caretX;
  final VoidCallback? onSetRangePoint;
  final bool hasRangeStart;

  const _Bubble({
    required this.surah,
    required this.ayah,
    required this.onDismiss,
    required this.caretOnBottom,
    required this.caretX,
    this.onSetRangePoint,
    this.hasRangeStart = false,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _isPlaying = false;

  String get _verseKey => '${widget.surah}:${widget.ayah}';

  void _updateIsPlaying() {
    if (!mounted) return;
    final svc = MiniPlayerService.instance;
    setState(() {
      _isPlaying = svc.isPlaying.value && svc.currentAyahKey.value == _verseKey;
    });
  }

  @override
  void initState() {
    super.initState();
    MiniPlayerService.instance.isPlaying.addListener(_updateIsPlaying);
    MiniPlayerService.instance.currentAyahKey.addListener(_updateIsPlaying);
    _updateIsPlaying();
  }

  @override
  void dispose() {
    MiniPlayerService.instance.isPlaying.removeListener(_updateIsPlaying);
    MiniPlayerService.instance.currentAyahKey.removeListener(_updateIsPlaying);
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    final svc = MiniPlayerService.instance;
    if (svc.currentAyahKey.value == _verseKey && svc.isPlaying.value) {
      await svc.playPause();
    } else {
      await svc.playFrom(surah: widget.surah, ayah: widget.ayah);
    }
  }

  Future<void> _copy() async {
    final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
    if (verse == null || !mounted) return;
    final name = surahFr[widget.surah] ?? 'Sourate ${widget.surah}';
    await Clipboard.setData(
      ClipboardData(text: '${verse.ar}\n\n${verse.fr}\n\n— $name ${widget.ayah}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Verset copié'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    widget.onDismiss();
  }

  Future<void> _share() async {
    final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
    if (verse == null) return;
    final name = surahFr[widget.surah] ?? 'Sourate ${widget.surah}';
    await Share.share(
      '﴾${verse.ar}﴿\n\n${verse.fr}\n\n— $name, verset ${widget.ayah}',
      subject: '$name — verset ${widget.ayah}',
    );
    widget.onDismiss();
  }

  void _tafsir() {
    widget.onDismiss();
    AyahActionSheet.show(context, surah: widget.surah, ayah: widget.ayah);
  }

  double get _btnWidth => widget.onSetRangePoint != null ? 50.0 : 56.0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    final card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
        ),
),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(
            icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: _isPlaying ? 'Pause' : 'Écouter',
            color: const Color(0xFF4CAF50),
            onTap: _togglePlay,
            width: _btnWidth,
          ),
          _divider(),
          _Btn(
            icon: Icons.copy_rounded,
            label: 'Copier',
            color: const Color(0xFF2196F3),
            onTap: _copy,
            width: _btnWidth,
          ),
          _divider(),
          _Btn(
            icon: Icons.share_rounded,
            label: 'Partager',
            color: const Color(0xFF9C27B0),
            onTap: _share,
            width: _btnWidth,
          ),
          _divider(),
          _Btn(
            icon: Icons.menu_book_rounded,
            label: 'Tafsir',
            color: const Color(0xFFB8860B),
            onTap: _tafsir,
            width: _btnWidth,
          ),
          if (widget.onSetRangePoint != null) ...[
            _divider(),
            _Btn(
              icon: Icons.push_pin_rounded,
              label: widget.hasRangeStart ? 'Fin ◀' : 'Début ▶',
              color: const Color(0xFF43A047),
              onTap: () {
                widget.onSetRangePoint!();
                widget.onDismiss();
              },
              width: _btnWidth,
            ),
          ],
        ],
      ),
    );

    // Caret (petite pointe triangulaire)
    final caret = CustomPaint(
      size: const Size(16, 8),
      painter: _CaretPainter(
        color: bg,
        borderColor: Colors.black.withValues(alpha: 0.06),
        pointDown: widget.caretOnBottom,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.caretOnBottom
          ? [
              card,
              Padding(
                padding: EdgeInsets.only(left: widget.caretX - 8),
                child: Align(alignment: Alignment.centerLeft, child: caret),
              ),
            ]
          : [
              Padding(
                padding: EdgeInsets.only(left: widget.caretX - 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RotatedBox(quarterTurns: 2, child: caret),
                ),
              ),
              card,
            ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.black.withValues(alpha: 0.07),
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
}

// ── Bouton ───────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _Btn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.width = 56,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Caret painter ────────────────────────────────────────────────────────────

class _CaretPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool pointDown;

  const _CaretPainter({
    required this.color,
    required this.borderColor,
    required this.pointDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = borderColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeWidth = 0,
    );
  }

  @override
  bool shouldRepaint(covariant _CaretPainter old) =>
      old.color != color || old.pointDown != pointDown;
}
