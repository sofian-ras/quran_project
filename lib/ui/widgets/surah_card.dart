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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: gold.withOpacity(0.3),
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
                color: isPlaying ? gold.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$id',
                  style: TextStyle(
                    color: isPlaying ? gold : Colors.grey.shade700,
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
                      color: isPlaying ? gold : const Color(0xFF1a0033),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nameAr,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 15,
                      color: Colors.grey.shade600,
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
                color: gold.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Icônes minimalistes
            if (onPlay != null)
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: isPlaying ? gold : Colors.grey.shade400,
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
                  color: isFavorite ? gold : Colors.grey.shade400,
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
