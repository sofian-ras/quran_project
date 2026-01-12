import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  // Garantit que les services Flutter sont initialisés avant de charger les assets
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mushaf Al-Muqaran',
      theme: ThemeData(
        useMaterial3: true,
        // Couleur crème pour rappeler le papier du Mushaf
        scaffoldBackgroundColor: const Color(0xFFFDF7E7),
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
  // Les 8 lectures officielles fusionnées dans votre JSON
  final List<String> readings = [
    "hafs", 
    "warsh", 
    "qaloon", 
    "shouba", 
    "doori", 
    "sousi", 
    "bazzi", 
    "qumbul"
  ];
  
  String currentReading = "hafs"; 
  List<dynamic> quranData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Chargement du fichier JSON fusionné par le script Python
  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/quran_data.json');
      setState(() {
        quranData = json.decode(response);
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement des données : $e");
    }
  }

  // Fait le lien entre le choix de lecture et la famille de police déclarée dans pubspec.yaml
  String _getFont(String reading) {
    switch (reading) {
      case "hafs": return "UthmanicHafs";
      case "warsh": return "UthmanicWarsh";
      case "qaloon": return "UthmanicQaloon";
      case "shouba": return "UthmanicShouba";
      case "doori": return "UthmanicDoori";
      case "sousi": return "UthmanicSousi";
      case "bazzi": return "UthmanicBazzi";
      case "qumbul": return "UthmanicQumbul";
      default: return "UthmanicHafs";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mushaf Al-Muqaran", 
          style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFFFDF7E7),
        elevation: 0,
        centerTitle: true,
        actions: [
          // Menu de sélection des lectures
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: DropdownButton<String>(
              value: currentReading,
              underline: const SizedBox(),
              icon: const Icon(Icons.settings, color: Colors.brown),
              onChanged: (val) {
                if (val != null) setState(() => currentReading = val);
              },
              items: readings.map((r) => DropdownMenuItem(
                value: r, 
                child: Text(r.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
              )).toList(),
            ),
          )
        ],
      ),
      body: quranData.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : ListView.builder(
              itemCount: quranData.length,
              itemBuilder: (context, index) {
                final item = quranData[index];
                return _buildAyahTile(item);
              },
            ),
    );
  }

  // Widget personnalisé pour chaque verset (Design Arabe Prioritaire)
  Widget _buildAyahTile(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5DCC3), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Numéro de la sourate et du verset
          Text(
            "Sourate ${item['surah']} • Verset ${item['ayah']}",
            style: const TextStyle(color: Colors.brown, fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),
          
          // Texte Arabe (Très grand pour la calligraphie)
          Text(
            item[currentReading] ?? "",
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40, 
              fontFamily: _getFont(currentReading),
              height: 1.9,
              color: const Color(0xFF2D2D2D),
              fontFeatures: const [
                FontFeature.enable('liga'), // Activer les ligatures
                FontFeature.enable('clig'),
                FontFeature.enable('calt'),
              ],
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Traduction Française (Plus discrète)
          Text(
            item['fr'] ?? "",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.brown.withOpacity(0.8),
              fontSize: 16,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia', // Ou une police serif standard
            ),
          ),
        ],
      ),
    );
  }
}