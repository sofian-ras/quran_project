import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /* --------------- IMMERSIVE MODE --------------- */
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
  int currentPage = 1;
  String currentReading = "hafs";

  Database? _db;
  final PageController _pageController = PageController();
  List<dynamic> quranData = [];
  List<Map<String, dynamic>> fullSurahList = [];

  bool showBottomBar = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    quranData = json.decode(jsonStr);

    final added = <int>{};
    for (final v in quranData) {
      if (!added.contains(v['surah'])) {
        fullSurahList.add({
          'id': v['surah'],
          'name': v['sura_name'] ?? 'Sourate ${v['surah']}',
          'page': v['page'] ?? 1,
        });
        added.add(v['surah']);
      }
    }

    final path = p.join(await getDatabasesPath(), "ayahinfo_1120.db");
    if (!await databaseExists(path)) {
      final data = await rootBundle.load("assets/data/ayahinfo_1120.db");
      await File(path).writeAsBytes(data.buffer.asUint8List());
    }
    _db = await openDatabase(path, readOnly: true);

    if (mounted) setState(() {});
  }

  String getCurrentSurahName() {
    final surah = fullSurahList.lastWhere(
        (s) => s['page']! <= currentPage,
        orElse: () => {'name': ''});
    return surah['name'] ?? '';
  }

  void toggleBottomBar() {
    setState(() {
      showBottomBar = !showBottomBar;
    });
  }

  void selectSurah(int page) {
    _pageController.jumpToPage(page - 1);
  }

  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7E7),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: toggleBottomBar,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              reverse: true,
              itemCount: 604,
              onPageChanged: (p) {
                setState(() {
                  currentPage = p + 1;
                });
              },
              itemBuilder: (_, i) {
                final page = i + 1;
                final file = currentReading == "hafs" ? "$page.png" : "$page.jpg";

                return LayoutBuilder(
                  builder: (context, constraints) {
                    const double margin = 16;          // marge extérieure
                    return Padding(
                      padding: const EdgeInsets.all(margin),
                      child: SingleChildScrollView(    // scroll vertical uniquement
                        physics: const ClampingScrollPhysics(),
                        child: Center(
                          child: Image.asset(
                            'assets/mushaf/$currentReading/$file',
                            // on force la largeur utile
                            width: constraints.maxWidth - 2 * margin,
                            fit: BoxFit.fitWidth,      // largeur max, pas de bandes
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Barre du bas (cachée en paysage)
            if (showBottomBar && !isLandscape)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _showSurahSelection(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          getCurrentSurahName(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "$currentPage",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            currentReading =
                                currentReading == "hafs" ? "warsh" : "hafs";
                          });
                        },
                        child: Text(
                          currentReading.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSurahSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: fullSurahList.length,
        itemBuilder: (context, index) {
          final s = fullSurahList[index];
          return ListTile(
            title: Text("${s['id']}. ${s['name']}"),
            onTap: () {
              selectSurah(s['page']);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}