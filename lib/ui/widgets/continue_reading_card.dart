import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/last_reading_service.dart';
import '../reader_screen.dart';

class ContinueReadingCard extends StatefulWidget {
  final VoidCallback? onTap;
  const ContinueReadingCard({super.key, this.onTap});

  @override
  State<ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<ContinueReadingCard> {
  LastReadingPosition? _position;
  String _surahName = 'Al-Fatiha';
  int _pageNumber = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final position = await LastReadingService.getLastReading();

      if (position != null) {
        // Charger le nom de la sourate
        final jsonString = await rootBundle.loadString('assets/data/quran-metadata-juz.json');
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final surahs = data['surahs'] as List;

        final surahData = surahs.firstWhere(
          (s) => s['id'] == position.surahNumber,
          orElse: () => surahs.first,
        ) as Map<String, dynamic>;

        setState(() {
          _position = position;
          _surahName = surahData['nameFr'] as String;
          _pageNumber = position.pageNumber;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement position: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              initialPage: _pageNumber,
              reading: 'hafs',
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // image de fond
              Positioned.fill(
                child: Image.asset(
                  'assets/images/reprendre_lecture/reprendre_lecture.webp',
                  fit: BoxFit.cover,
                ),
              ),

              // voile léger pour lisibilité (supprime si tu veux l'image "pure")
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.45),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Contenu (sans logo / sans fond coloré)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // ✅ icône supprimée

                    // Texte
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _position == null ? 'Commencer la lecture' : 'Reprendre la lecture',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _surahName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Page $_pageNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_position != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  _position!.getRelativeTime(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Flèche
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
