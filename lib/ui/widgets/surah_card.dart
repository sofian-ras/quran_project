import 'package:flutter/material.dart';
import '../../services/quran_image_service.dart';

/// Loads a Quran page into Flutter's image cache then calls [onOpen].
/// Downloads the page first if not cached, toggling [setLoading] meanwhile.
Future<void> openPageWithPrecache(
  BuildContext context,
  int pageNum,
  VoidCallback onOpen,
  void Function(bool loading) setLoading,
) async {
  final bool isCached = QuranImageService.instance.getSyncCached(pageNum) != null ||
      await QuranImageService.instance.isPageCached(pageNum);

  if (isCached) {
    if (QuranImageService.instance.getSyncCached(pageNum) == null) {
      await QuranImageService.instance.getPageFile('hafs', pageNum);
    }
    final file = QuranImageService.instance.getSyncCached(pageNum);
    if (file != null && context.mounted) await precacheImage(FileImage(file), context);
    if (!context.mounted) return;
    onOpen();
    return;
  }

  setLoading(true);
  try {
    await QuranImageService.instance.getPageFile('hafs', pageNum);
  } catch (_) {}
  if (!context.mounted) return;
  setLoading(false);

  final file = QuranImageService.instance.getSyncCached(pageNum);
  if (file == null) return;

  await precacheImage(FileImage(file), context);
  if (!context.mounted) return;
  onOpen();
}

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
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    await openPageWithPrecache(
      context, widget.page, () => widget.onTap?.call(),
      (v) { if (mounted) setState(() => _loading = v); },
    );
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
    final Color playIconColor = widget.isPlaying
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);

    final Color favIconColor = widget.isFavorite
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);

    final Color tileBg = isDark ? const Color(0xFF1A0033) : Colors.transparent;

    return InkWell(
      onTap: _loading ? null : _handleTap,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: tileBg,
          border: Border(
            bottom: BorderSide(color: dividerColor, width: 1),
          ),
        ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.page}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isPlaying ? gold : (isDark ? Colors.white54 : Colors.grey.shade500),
                  ),
                ),
                Text(
                  'page',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ),
              ],
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
    );
  }
}
