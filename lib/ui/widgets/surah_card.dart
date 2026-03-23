import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/quran_image_service.dart';

class SurahCard extends StatefulWidget {
  final int id;
  final int page;
  final String nameAr;
  final String nameFr;
  final int ayahCount;
  final bool isFavorite;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleFavorite;

  const SurahCard({
    super.key,
    required this.id,
    required this.page,
    required this.nameAr,
    required this.nameFr,
    this.ayahCount = 0,
    this.isFavorite = false,
    this.isPlaying = false,
    this.onTap,
    this.onPlay,
    this.onToggleFavorite,
  });

  @override
  State<SurahCard> createState() => _SurahCardState();
}

class _SurahCardState extends State<SurahCard> {
  double _fillProgress = 0.0;
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    if (!mounted) return;

    final bool isCached = QuranImageService.getSyncCached(widget.page) != null ||
        await QuranImageService.isPageCached(widget.page);

    if (isCached) {
      // Page en cache : flash visuel + précache PNG avant d'ouvrir le reader.
      setState(() => _fillProgress = 1.0);
      if (QuranImageService.getSyncCached(widget.page) == null) {
        await QuranImageService.getPageFile('hafs', widget.page);
      }
      final file = QuranImageService.getSyncCached(widget.page);
      if (file != null && mounted) {
        await precacheImage(FileImage(file), context);
      }
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 80));
      widget.onTap?.call();
      if (mounted) setState(() => _fillProgress = 0.0);
      return;
    }

    // Page absente : animation de remplissage pendant le téléchargement.
    setState(() {
      _loading = true;
      _fillProgress = 0.0;
    });

    try {
      await QuranImageService.getPageFile(
        'hafs',
        widget.page,
        onProgress: (p) {
          if (mounted) setState(() => _fillProgress = p);
        },
      );
    } catch (_) {}

    if (!mounted) return;

    final file = QuranImageService.getSyncCached(widget.page);
    if (file == null) {
      // Téléchargement échoué : reset sans naviguer.
      setState(() { _fillProgress = 0.0; _loading = false; });
      return;
    }

    setState(() { _fillProgress = 1.0; _loading = false; });
    // Précache pendant que l'animation est complète.
    await precacheImage(FileImage(file), context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    widget.onTap?.call();
    if (mounted) setState(() => _fillProgress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : gold.withValues(alpha: 0.3);

    final Color numberBgColor = widget.isPlaying
        ? gold.withValues(alpha: isDark ? 0.18 : 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100);

    final Color numberTextColor = widget.isPlaying
        ? gold
        : (isDark ? Colors.white70 : Colors.grey.shade700);

    final Color nameFrColor = widget.isPlaying
        ? gold
        : (isDark ? Colors.white : const Color(0xFF1a0033));

    final Color nameArColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final Color dotColor = gold.withValues(alpha: isDark ? 0.35 : 0.5);

    final Color playIconColor = widget.isPlaying
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);

    final Color favIconColor = widget.isFavorite
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);

    final Color tileBg = isDark ? const Color(0xFF1A0033) : Colors.transparent;

    return ClipRect(
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: tileBg,
              border: Border(
                bottom: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: InkWell(
              onTap: _handleTap,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: numberBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.id}',
                        style: TextStyle(
                          color: numberTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nameFr,
                          style: TextStyle(
                            fontSize: 16,
                            color: nameFrColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.nameAr,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 15,
                            color: nameArColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.onPlay != null)
                    IconButton(
                      icon: Icon(
                        widget.isPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: playIconColor,
                        size: 26,
                      ),
                      onPressed: widget.onPlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (widget.onPlay != null) const SizedBox(width: 8),
                  if (widget.onToggleFavorite != null)
                    IconButton(
                      icon: Icon(
                        widget.isFavorite ? Icons.star : Icons.star_border,
                        color: favIconColor,
                        size: 22,
                      ),
                      onPressed: widget.onToggleFavorite,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),

          // Overlay fill du centre vers les bords
          if (_fillProgress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CenterFillPainter(
                    progress: _fillProgress,
                    color: gold.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenterFillPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CenterFillPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        sqrt(size.width * size.width + size.height * size.height) / 2;
    canvas.drawCircle(center, maxRadius * progress, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CenterFillPainter old) => old.progress != progress;
}
