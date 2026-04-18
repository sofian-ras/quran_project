import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget qui affiche un verset aléatoire du jour
class DailyVerseCard extends StatelessWidget {
  const DailyVerseCard({super.key});

  Future<_VerseData?> _getDailyVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final savedDate = prefs.getString('daily_verse_date');

    if (savedDate == todayKey) {
      final savedVerse = prefs.getString('daily_verse_text');
      final savedSurah = prefs.getString('daily_verse_surah');
      final savedNumber = prefs.getInt('daily_verse_number');
      if (savedVerse != null && savedSurah != null && savedNumber != null) {
        return _VerseData(text: savedVerse, surahName: savedSurah, verseNumber: savedNumber);
      }
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/quran_data.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final surahs = data['surahs'] as List;

      final seed = today.year * 10000 + today.month * 100 + today.day;
      final random = Random(seed);
      final surah = surahs[random.nextInt(surahs.length)] as Map<String, dynamic>;
      final verses = surah['verses'] as List;
      final verse = verses[random.nextInt(verses.length)] as Map<String, dynamic>;

      final verseData = _VerseData(
        text: verse['textFr'] as String? ?? '',
        surahName: surah['nameFr'] as String,
        verseNumber: verse['id'] as int,
      );

      await prefs.setString('daily_verse_date', todayKey);
      await prefs.setString('daily_verse_text', verseData.text);
      await prefs.setString('daily_verse_surah', verseData.surahName);
      await prefs.setInt('daily_verse_number', verseData.verseNumber);

      return verseData;
    } catch (e) {
      debugPrint('Erreur chargement verset du jour: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<_VerseData?>(
      future: _getDailyVerse(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(isDark);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildErrorCard(isDark);
        }
        return _buildCard(snapshot.data!, isDark);
      },
    );
  }

  Widget _buildCard(_VerseData verse, bool isDark) {
    if (isDark) {
      return _buildDarkCard(verse);
    }

    // Thèmes clairs : fond encadre_verset.webp
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Stack(
        children: [
          // Image de fond (s'adapte à la largeur, hauteur naturelle)
          Image.asset(
            'assets/images/encadre_verset.webp',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
          // Contenu superposé
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;
                return Column(
                  children: [
                    // Zone cadre supérieur (≈18 % de la hauteur image)
                    SizedBox(
                      height: h * 0.185,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.24),
                          child: Text(
                            verse.surahName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B4C1A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Zone centrale : verset
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'VERSET DU JOUR',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFFA07840),
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '« ${verse.text} »',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                height: 1.65,
                                color: Color(0xFF3D2B0E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Verset ${verse.verseNumber}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9B7840),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Réserve pour la bande ornementale du bas (≈13 %)
                    SizedBox(height: h * 0.13),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkCard(_VerseData verse) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            verse.surahName,
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'VERSET DU JOUR',
            style: TextStyle(
              fontSize: 9.5,
              color: Color(0xFFA07840),
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '« ${verse.text} »',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.65,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Verset ${verse.verseNumber}',
            style: TextStyle(
              color: Colors.amber.shade400.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C3E50) : const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C3E50) : const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? Colors.amber.shade200 : const Color(0xFFA07840),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verset du jour bientôt disponible',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF3D2B0E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseData {
  final String text;
  final String surahName;
  final int verseNumber;

  const _VerseData({
    required this.text,
    required this.surahName,
    required this.verseNumber,
  });
}
