import 'package:flutter/material.dart';

class SurahCard extends StatelessWidget {
  final int id;
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
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color dividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : gold.withOpacity(0.3);

    final Color numberBgColor = isPlaying
        ? gold.withOpacity(isDark ? 0.18 : 0.1)
        : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100);

    final Color numberTextColor = isPlaying
        ? gold
        : (isDark ? Colors.white70 : Colors.grey.shade700);

    final Color nameFrColor = isPlaying
        ? gold
        : (isDark ? Colors.white : const Color(0xFF1a0033));

    final Color nameArColor = isDark ? Colors.white70 : Colors.grey.shade600;

    final Color dotColor = gold.withOpacity(isDark ? 0.35 : 0.5);

    final Color playIconColor = isPlaying
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);

    final Color favIconColor = isFavorite
        ? gold
        : (isDark ? Colors.white38 : Colors.grey.shade400);
    
    final Color tileBg = isDark ? const Color(0xFF1A0033) : Colors.transparent;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: tileBg,
        border: Border(
          bottom: BorderSide(
            color: dividerColor,
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Numéro simple
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: numberBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$id',
                  style: TextStyle(
                    color: numberTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameFr,
                    style: TextStyle(
                      fontSize: 16,
                      color: nameFrColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nameAr,
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

            // Décoration dorée
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),

            // Icônes minimalistes
            if (onPlay != null)
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: playIconColor,
                  size: 26,
                ),
                onPressed: onPlay,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (onPlay != null) const SizedBox(width: 8),
            if (onToggleFavorite != null)
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: favIconColor,
                  size: 22,
                ),
                onPressed: onToggleFavorite,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
