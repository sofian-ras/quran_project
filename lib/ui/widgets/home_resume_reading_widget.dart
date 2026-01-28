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

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a0033), Color(0xFF2d1b4e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
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
                      color: const Color(0xFFFFFFFF),
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reprendre',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFFFFFFF).withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      surahName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
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
