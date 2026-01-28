import 'package:flutter/material.dart';

import '../../services/reading_history_service.dart';

// Widget Reprendre la lecture (compact)
class ResumeReadingWidget extends StatelessWidget {
  final void Function(int page, String reading) onTap;

  const ResumeReadingWidget({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ReadingHistoryService.instance.getLastReading(),
      builder: (context, snapshot) {
        final lastReading = snapshot.data;

        // Fallbacks robustes
        final int page = (lastReading?['page'] is int) ? lastReading!['page'] as int : 1;
        final String reading = (lastReading?['reading'] as String?) ?? 'hafs';

        String surahName = (lastReading?['surahName'] as String?) ?? '';
        surahName = surahName.trim();
        if (surahName.isEmpty) {
          surahName = 'Page $page';
        }

        // Si rien du tout nâ€™existe, on affiche quand mÃªme un bouton â€œReprendreâ€
        // (au lieu de shrink), qui ouvre page 1 (ou ce que tu veux)
        final bool hasAnyData = lastReading != null;
        final Color textColor = const Color(0xFF3B2A0B);
        final Color secondaryColor = const Color(0xFF5A3E0E);
        final List<Shadow> reliefShadows = const [
          Shadow(color: Color(0xFFFFF3D6), offset: Offset(-0.6, -0.6), blurRadius: 1),
          Shadow(color: Color(0xFF8C6A1A), offset: Offset(0.9, 0.9), blurRadius: 1.6),
        ];

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD37A), Color(0xFFDAA520)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFF2C9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8860B).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onTap(page, reading),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: textColor,
                      size: 32,
                      shadows: reliefShadows,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reprendre',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        shadows: reliefShadows,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      surahName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        shadows: reliefShadows,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (hasAnyData) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Page $page',
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryColor,
                          fontWeight: FontWeight.w500,
                          shadows: reliefShadows,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
