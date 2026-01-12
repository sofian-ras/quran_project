import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        scaffoldBackgroundColor: const Color(0xFFFDF7E7)
      ),
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

  // Charge les textes et les coordonnées CSV
  Future<void> _loadAllData() async {
    try {
      // 1. Charger le JSON des textes
      final String jsonResponse = await rootBundle.loadString('assets/data/quran_data.json');
      setState(() {
        quranData = json.decode(jsonResponse);
      });

      // 2. Charger le CSV selon la lecture
      final String csvPath = 'assets/data/data_$currentReading.csv';
      final String csvResponse = await rootBundle.loadString(csvPath);
      _parseCsv(csvResponse);

      print("DEBUG: Chargement réussi pour $currentReading (${coordsData.length} points)");
    } catch (e) {
      print("DEBUG ERROR: Erreur de chargement : $e");
    }
  }

  void _parseCsv(String csvData) {
    setState(() {
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
    });
  }

  // --- MOTEUR DE DÉTECTION ---
  void _detectAyahTap(TapDownDetails details, BoxConstraints constraints) {
    if (coordsData.isEmpty) return;

    // Calcul des coordonnées relatives (Base 1000)
    double clickX = (details.localPosition.dx / constraints.maxWidth) * 1000;
    double clickY = (details.localPosition.dy / constraints.maxHeight) * 1000;

    print("DEBUG: Clic à X: ${clickX.round()}, Y: ${clickY.round()}");

    var pageCoords = coordsData.where((c) => c['page'] == currentPage.toString()).toList();

    Map<String, dynamic>? closestAyah;
    double minDistance = 8000; // Seuil de tolérance

    for (var coord in pageCoords) {
      double dx = coord['x'] - clickX;
      double dy = coord['y'] - clickY;
      double distance = (dx * dx) + (dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestAyah = coord;
      }
    }

    if (closestAyah != null) {
      print("DEBUG: Ayah trouvé ID ${closestAyah['ayah_id']}");
      
      var verse = quranData.firstWhere(
        (v) => v['ayah'].toString() == closestAyah!['ayah_id'] && v['page'].toString() == currentPage.toString(),
        orElse: () => null
      );
      
      if (verse != null) {
        _showModernVerseBubble(verse);
      }
    }
  }

  void _showModernVerseBubble(dynamic verse) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.98),
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("VERSET ${verse['ayah']}", 
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(verse[currentReading] ?? verse['hafs'],
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.6, fontFamily: 'UthmanicHafs'),
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  Text(verse['fr'] ?? "", 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
              .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutQuart)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        backgroundColor: const Color(0xFFFDF7E7),
        elevation: 0,
        title: Text("Page $currentPage", style: const TextStyle(color: Colors.brown)),
        actions: [
          DropdownButton<String>(
            value: currentReading,
            underline: const SizedBox(),
            onChanged: (val) {
              setState(() => currentReading = val!);
              _loadAllData();
            },
            items: ["hafs", "warsh", "qaloon", "shouba"].map((r) => DropdownMenuItem(
              value: r, 
              child: Text(r.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
            )).toList(),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _detectAyahTap(details, constraints),
            onLongPress: () => setState(() => _isFullScreen = !_isFullScreen),
            child: PageView.builder(
              controller: _pageController,
              itemCount: 604,
              reverse: true,
              onPageChanged: (index) => setState(() => currentPage = index + 1),
              itemBuilder: (context, index) {
                return Center(
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/mushaf/$currentReading/${index + 1}.jpg',
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}