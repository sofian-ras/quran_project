import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/last_reading_service.dart';
import '../../services/quran_image_service.dart';
import '../screens/reader_screen.dart';

class ContinueReadingCard extends StatefulWidget {
  const ContinueReadingCard({super.key});

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
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erreur chargement position: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openPage(int page) async {
    try {
      await QuranImageService.instance.getPageFile('hafs', page);
      if (!mounted) return;
      final File? file = QuranImageService.instance.getSyncCached(page);
      if (file != null) await precacheImage(FileImage(file), context);
      if (!mounted) return;
    } catch (_) {}
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialPage: page, reading: 'hafs'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de fond full-width
              Image.asset(
                'assets/images/reprendre_lecture/reprendre_lecture.webp',
                fit: BoxFit.cover,
              ),

              // Overlay gauche — vert
              ClipPath(
                clipper: const _LeftSplitClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0B3D1F).withValues(alpha:0.84),
                        const Color(0xFF0F5A2A).withValues(alpha:0.84),
                      ],
                    ),
                  ),
                ),
              ),

              // Overlay droite — navy
              ClipPath(
                clipper: const _RightSplitClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0A1F4E).withValues(alpha:0.84),
                        const Color(0xFF1A3678).withValues(alpha:0.84),
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu : deux zones tappables
              Row(
                children: [
                  // — Gauche : Commencer la lecture
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openPage(1),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Commencer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'la lecture',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // — Droite : Reprendre la lecture
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openPage(_pageNumber),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Reprendre',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha:0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _surahName,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha:0.2),
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
                                      color: Colors.white.withValues(alpha:0.8),
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Clippe la moitié gauche avec un bord droit diagonal légèrement courbe
class _LeftSplitClipper extends CustomClipper<Path> {
  const _LeftSplitClipper();

  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(0, 0);
    p.lineTo(size.width * 0.58, 0);
    p.quadraticBezierTo(
      size.width * 0.52, size.height * 0.5,
      size.width * 0.44, size.height,
    );
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Clippe la moitié droite — inverse exact du gauche
class _RightSplitClipper extends CustomClipper<Path> {
  const _RightSplitClipper();

  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(size.width * 0.58, 0);
    p.lineTo(size.width, 0);
    p.lineTo(size.width, size.height);
    p.lineTo(size.width * 0.44, size.height);
    p.quadraticBezierTo(
      size.width * 0.52, size.height * 0.5,
      size.width * 0.58, 0,
    );
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
