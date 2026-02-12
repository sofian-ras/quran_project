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

    // Si on a déjà un verset pour aujourd'hui, on le retourne
    if (savedDate == todayKey) {
      final savedVerse = prefs.getString('daily_verse_text');
      final savedSurah = prefs.getString('daily_verse_surah');
      final savedNumber = prefs.getInt('daily_verse_number');
      
      if (savedVerse != null && savedSurah != null && savedNumber != null) {
        return _VerseData(
          text: savedVerse,
          surahName: savedSurah,
          verseNumber: savedNumber,
        );
      }
    }

    // Sinon, on charge un nouveau verset aléatoire
    try {
      final jsonString = await rootBundle.loadString('assets/data/quran_data.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final surahs = data['surahs'] as List;

      // Utiliser la date comme seed pour avoir le même verset toute la journée
      final seed = today.year * 10000 + today.month * 100 + today.day;
      final random = Random(seed);

      // Choisir une sourate aléatoire
      final surah = surahs[random.nextInt(surahs.length)] as Map<String, dynamic>;
      final verses = surah['verses'] as List;
      
      // Choisir un verset aléatoire dans cette sourate
      final verse = verses[random.nextInt(verses.length)] as Map<String, dynamic>;
      
      final verseData = _VerseData(
        text: verse['textFr'] as String? ?? '',
        surahName: surah['nameFr'] as String,
        verseNumber: verse['id'] as int,
      );

      // Sauvegarder pour aujourd'hui
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
        // Afficher un message de chargement ou d'erreur au lieu de rien
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(isDark);
        }
        
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildErrorCard(isDark);
        }

        final verse = snapshot.data!;

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2C3E50),
                      const Color(0xFF1A252F),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFEF5E7),
                      const Color(0xFFFAE5D3),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.orange.shade200).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: isDark ? Colors.amber.shade200 : Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verset du jour',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Texte du verset
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.orange.shade200.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '"${verse.text}"',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.95) : Colors.black87,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Référence
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.shade900.withOpacity(0.3)
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${verse.surahName} • ${verse.verseNumber}',
                      style: TextStyle(
                        color: isDark ? Colors.amber.shade200 : Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C3E50) : const Color(0xFFFEF5E7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C3E50), const Color(0xFF1A252F)]
              : [const Color(0xFFFEF5E7), const Color(0xFFFAE5D3)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? Colors.amber.shade200 : Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verset du jour bientôt disponible',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
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
