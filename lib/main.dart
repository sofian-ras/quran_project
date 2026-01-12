import 'dart:convert';
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
  List<dynamic> quranData = []; // Textes
  List<Map<String, dynamic>> coordsData = []; // Coordonnées
  final PageController _pageController = PageController();
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Charge les textes ET les coordonnées selon la lecture choisie
  Future<void> _loadAllData() async {
    try {
      // 1. Charger le JSON des textes (commun)
      final String jsonResponse = await rootBundle.loadString('assets/data/quran_data.json');
      quranData = json.decode(jsonResponse);

      // 2. Charger le CSV spécifique à la lecture (hafs ou warsh)
      // Assure-toi que les noms de fichiers correspondent exactement : data_hafs.csv, etc.
      final String csvPath = 'assets/data/data_$currentReading.csv';
      final String csvResponse = await rootBundle.loadString(csvPath);
      _parseCsv(csvResponse);

      setState(() {});
    } catch (e) {
      debugPrint("Erreur chargement ($currentReading) : $e");
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
          'ayah_id': row[0].trim(), // Ex: "1"
          'page': row[1].trim(),    // Ex: "1"
          'x': double.tryParse(row[2].trim()) ?? 0.0,
          'y': double.tryParse(row[3].trim()) ?? 0.0,
        });
      }
    }
  }

  // --- MOTEUR DE DÉTECTION ---
  void _detectAyahTap(TapDownDetails details, BoxConstraints constraints) {
    if (coordsData.isEmpty) return;

    // On transforme le clic en coordonnées 1000x1000 (standard pour ces CSV)
    double clickX = (details.localPosition.dx / constraints.maxWidth) * 1000;
    double clickY = (details.localPosition.dy / constraints.maxHeight) * 1000;

    // Filtrer pour la page actuelle
    var pageCoords = coordsData.where((c) => c['page'] == currentPage.toString()).toList();

    Map<String, dynamic>? closestAyah;
    double minDistance = 15000; // Seuil de détection (ajustable)

    for (var coord in pageCoords) {
      // Calcul de la distance au carré (plus rapide que racine carrée)
      double dx = coord['x'] - clickX;
      double dy = coord['y'] - clickY;
      double distance = (dx * dx) + (dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestAyah = coord;
      }
    }

    if (closestAyah != null) {
      // On cherche le texte correspondant dans le JSON
      var verse = quranData.firstWhere(
        (v) => v['ayah'].toString() == closestAyah!['ayah_id'] && v['page'].toString() == currentPage.toString(),
        orElse: () => null
      );
      if (verse != null) _showModernVerseBubble(verse);
    }
  }

  void _showModernVerseBubble(dynamic verse) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.95),
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("VERSET ${verse['ayah']}", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(verse[currentReading] ?? verse['hafs'],
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.6),
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  Text(verse['fr'] ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
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
            onChanged: (val) {
              setState(() => currentReading = val!);
              _loadAllData(); // RECHARGE le bon CSV quand on change de lecture
            },
            items: ["hafs", "warsh", "qaloon", "shouba"].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) => _detectAyahTap(details, constraints),
            onLongPress: () => setState(() => _isFullScreen = !_isFullScreen),
            child: PageView.builder(
              controller: _pageController,
              itemCount: 604,
              reverse: true,
              onPageChanged: (index) => setState(() => currentPage = index + 1),
              itemBuilder: (context, index) {
                return Center(
                  child: Image.asset(
                    'assets/mushaf/$currentReading/${index + 1}.jpg',
                    fit: BoxFit.contain,
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