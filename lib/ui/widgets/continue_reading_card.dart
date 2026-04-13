import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/reading_history_service.dart';
import '../../services/quran_image_service.dart';
import '../screens/reader_screen.dart';

class ContinueReadingCard extends StatefulWidget {
  const ContinueReadingCard({super.key});

  @override
  State<ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<ContinueReadingCard> {
  Map<String, dynamic>? _lastReading;

  @override
  void initState() {
    super.initState();
    _loadData();
    ReadingHistoryService.changeNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    ReadingHistoryService.changeNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await ReadingHistoryService.instance.getLastReading();
    if (!mounted) return;
    setState(() {
      _lastReading = data;
    });
  }

  int get _pageNumber => (_lastReading?['page'] as int?) ?? 1;
  String get _surahName => (_lastReading?['surahName'] as String?) ?? 'Al-Fatiha';
  String get _reading => (_lastReading?['reading'] as String?) ?? 'hafs';

  Future<void> _openRandomPage() => _openPage(math.Random().nextInt(604) + 1, 'hafs');

  Future<void> _openPage(int page, String reading) async {
    try {
      await QuranImageService.instance.getPageFile(reading, page);
      if (!mounted) return;
      final File? file = QuranImageService.instance.getSyncCached(page);
      if (file != null) await precacheImage(FileImage(file), context);
      if (!mounted) return;
    } catch (_) {}
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialPage: page, reading: reading),
      ),
    );
    if (mounted) _loadData();
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
              color: Colors.black.withValues(alpha: 0.18),
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
                        const Color(0xFF0B3D1F).withValues(alpha: 0.55),
                        const Color(0xFF0F5A2A).withValues(alpha: 0.55),
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
                        const Color(0xFF0A1F4E).withValues(alpha: 0.55),
                        const Color(0xFF1A3678).withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu : deux zones tappables
              Row(
                children: [
                  // — Gauche : Lecture aléatoire
                  Expanded(
                    child: GestureDetector(
                      onTap: _openRandomPage,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lecture',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'aléatoire',
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
                      onTap: () => _openPage(_pageNumber, _reading),
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
                                color: Colors.white.withValues(alpha: 0.85),
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                if (_lastReading != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    _getRelativeTime(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
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

  String _getRelativeTime() {
    final ts = _lastReading?['timestamp'] as String?;
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return 'il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes}min';
    return 'à l\'instant';
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
