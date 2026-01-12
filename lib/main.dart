import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // On force le mode portrait pour éviter les bugs de coordonnées
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFDF7E7)),
      home: const QuranHomePage(),
    );
  }
}

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});
  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  String currentReading = "hafs";
  int currentPage = 1;
  List<dynamic> quranData = [];
  List<Map<String, dynamic>> coordsData = [];
  final PageController _pageController = PageController();
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String get _imageExtension => currentReading == "warsh" ? "png" : "jpg";

  Future<void> _loadAllData() async {
    try {
      final String jsonResponse = await rootBundle.loadString('assets/data/quran_data.json');
      quranData = json.decode(jsonResponse);
      final String csvPath = 'assets/data/data_$currentReading.csv';
      final String csvResponse = await rootBundle.loadString(csvPath);
      _parseCsv(csvResponse);
      setState(() {});
    } catch (e) {
      debugPrint("Erreur chargement : $e");
    }
  }

  void _parseCsv(String csvData) {
    coordsData.clear();
    List<String> lines = csvData.split('\n');
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      List<String> row = lines[i].split(',');
      if (row.length >= 4) {
        coordsData.add({
          'ayah_id': row[0].trim(),
          'page': row[1].trim(),
          'x': double.tryParse(row[2].trim()) ?? 0.0,
          'y': double.tryParse(row[3].trim()) ?? 0.0,
        });
      }
    }
  }

  // --- LE MOTEUR DE PRÉCISION SMARTPHONE ---
  void _handleTap(TapDownDetails details, BoxConstraints constraints) {
    if (coordsData.isEmpty) return;

    // 1. Déterminer la taille réelle de l'image affichée (ratio standard Mushaf 1 / 1.5)
    double imageRatio = 1 / 1.5; 
    double containerRatio = constraints.maxWidth / constraints.maxHeight;

    double actualImageWidth, actualImageHeight;
    double offsetX = 0, offsetY = 0;

    if (containerRatio > imageRatio) {
      // Écran trop large (bandes noires sur les côtés)
      actualImageHeight = constraints.maxHeight;
      actualImageWidth = actualImageHeight * imageRatio;
      offsetX = (constraints.maxWidth - actualImageWidth) / 2;
    } else {
      // Écran trop long (bandes noires en haut et bas - Cas typique Android)
      actualImageWidth = constraints.maxWidth;
      actualImageHeight = actualImageWidth / imageRatio;
      offsetY = (constraints.maxHeight - actualImageHeight) / 2;
    }

    // 2. Traduire le clic en coordonnées "Image Pure" (0 à 1000)
    double relativeX = (details.localPosition.dx - offsetX) / actualImageWidth * 1000;
    double relativeY = (details.localPosition.dy - offsetY) / actualImageHeight * 1000;

    // 3. Ignorer si on clique hors de l'image
    if (relativeX < 0 || relativeX > 1000 || relativeY < 0 || relativeY > 1000) return;

    print("CLIC IMAGE -> X: ${relativeX.toInt()} Y: ${relativeY.toInt()}");

    var pageCoords = coordsData.where((c) => c['page'] == currentPage.toString()).toList();
    Map<String, dynamic>? closest;
    double minDistance = 6000; // Rayon de détection

    for (var coord in pageCoords) {
      double dx = coord['x'] - relativeX;
      double dy = coord['y'] - relativeY;
      double dist = (dx * dx) + (dy * dy);
      if (dist < minDistance) {
        minDistance = dist;
        closest = coord;
      }
    }

    if (closest != null) {
      var verse = quranData.firstWhere(
        (v) => v['ayah'].toString() == closest!['ayah_id'] && v['page'].toString() == currentPage.toString(),
        orElse: () => null
      );
      if (verse != null) _showVerseBubble(verse);
    }
  }

  void _showVerseBubble(dynamic verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SOURATE ${verse['surah']} • VERSET ${verse['ayah']}", 
                 style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text(verse[currentReading] ?? verse['hafs'],
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.6)),
            const Divider(color: Colors.white10, height: 30),
            Text(verse['fr'] ?? "", 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        backgroundColor: const Color(0xFFFDF7E7),
        title: Text("Page $currentPage", style: const TextStyle(color: Colors.brown)),
        actions: [
          DropdownButton<String>(
            value: currentReading,
            underline: const SizedBox(),
            onChanged: (val) {
              setState(() => currentReading = val!);
              _loadAllData();
            },
            items: ["hafs", "warsh"].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        reverse: true,
        onPageChanged: (index) => setState(() => currentPage = index + 1),
        itemBuilder: (context, index) {
          return LayoutBuilder(builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTap(details, constraints),
              onLongPress: () => setState(() => _isFullScreen = !_isFullScreen),
              child: Container(
                color: const Color(0xFFFDF7E7),
                child: Center(
                  child: Image.asset(
                    'assets/mushaf/$currentReading/${index + 1}.$_imageExtension',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }
}