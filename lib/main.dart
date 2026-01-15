import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'hizb_juzz.dart';
import 'surah_name.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: const Color(0xFFFEFCF9),
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
  /* ---------- début fonctions hizb / juzz ---------- */
  String _hizbText(int page) {
    final h = hizbMap.lastWhere((e) => e['start_page']! <= page);
    final hizb = h['hizb']!;
    final start = h['start_page']!;
    final nextStart = hizb == 60 ? 605 : hizbMap.firstWhere((e) => e['hizb'] == hizb + 1)['start_page']!;
    final total = nextStart - start;
    final done = page - start + 1;
    final quart = ((done * 4) ~/ total).clamp(0, 3);
    final frac = quart == 0 ? '' : ' ${['1/4', '1/2', '3/4'][quart - 1]}';
    return '$frac hizb n°$hizb';
  }

  String _juzzText(int page) {
    final j = juzzMap.lastWhere((e) => e['start_page']! <= page);
    final juzz = j['juz']!;
    final start = j['start_page']!;
    final nextStart = juzz == 30 ? 605 : juzzMap.firstWhere((e) => e['juz'] == juzz + 1)['start_page']!;
    final total = nextStart - start;
    final done = page - start + 1;
    final quart = ((done * 4) ~/ total).clamp(0, 3);
    final frac = quart == 0 ? '' : ' ${['1/4', '1/2', '3/4'][quart - 1]}';
    return '$frac juzz n°$juzz';
  }

  String _toFraction(int num, int den) {
    switch ((num * 4) ~/ den) {
      case 0: return '1/4';
      case 1: return '1/2';
      case 2: return '3/4';
      default: return '';
    }
  }
  /* ---------- fin fonctions hizb / juzz ---------- */

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

  /* 1. importer les noms français (à placer tout en haut de main.dart) */

  Future<void> _initApp() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    quranData = json.decode(jsonStr);
    final added = <int>{};
    for (final v in quranData) {
      final id = v['surah'];
      if (!added.contains(id)) {
        fullSurahList.add({
          'id': id,
          'nameAr': v['sura_name'] ?? 'Sourate $id',
          'nameFr': surahFr[id] ?? 'Sourate $id',   // nom français
          'page': v['page'] ?? 1,
        });
        added.add(id);
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
    setState(() => showBottomBar = !showBottomBar);
  }

  void selectSurah(int page) => _pageController.jumpToPage(page - 1);

  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /* ---------- Dialogue saisie page ---------- */
  void _jumpToPageDialog(BuildContext context) {
    final ctrl = TextEditingController(text: currentPage.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '1 - 604'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= 604) {
                _pageController.jumpToPage(p - 1);
                Navigator.pop(context);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFFEFCF9),
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: toggleBottomBar,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            reverse: true,
            itemCount: 604,
            onPageChanged: (p) => setState(() => currentPage = p + 1),
            itemBuilder: (_, i) {
              final page = i + 1;
              final file = currentReading == "hafs" ? "$page.png" : "$page.jpg";
              return LayoutBuilder(
                builder: (context, constraints) {
                  const double hMargin = 4;
                  const double vMargin = 16;
                  final isPortrait = constraints.maxHeight > constraints.maxWidth;

                  final imageWidget = Image.asset(
                    'assets/mushaf/$currentReading/$file',
                    fit: BoxFit.contain,
                    cacheWidth: isPortrait
                      ? constraints.maxWidth.toInt()
                      : constraints.maxWidth.toInt() - 2 * hMargin.toInt(),
                  );
                  return Padding(
                    padding: isPortrait
                        ? const EdgeInsets.all(vMargin)
                        : const EdgeInsets.symmetric(horizontal: hMargin),
                    child: isPortrait
                        ? Center(
                            child: Image.asset(
                                'assets/mushaf/$currentReading/$file',
                                fit: BoxFit.contain)) 
                        : SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Image.asset(
                              'assets/mushaf/$currentReading/$file',
                              width: constraints.maxWidth - 2 * hMargin,
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                              cacheWidth: (constraints.maxWidth - 2 * hMargin).toInt(),
                            ),
                          ),
                  );
                },
              );
            },
          ),

          /* ---------- Info hizb / juzz ---------- */
          Positioned(
            top: 8,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_hizbText(currentPage),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w300)),
                Text(_juzzText(currentPage),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),

          /* ---------- Barre du bas ---------- */
          if (showBottomBar && !isLandscape)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /* ---------- Sourate (français) cliquable ---------- */
                  GestureDetector(
                    onTap: () => _showSurahSelection(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        fullSurahList
                            .lastWhere((s) => s['page']! <= currentPage,
                                orElse: () => {'nameFr': ''})['nameFr'],
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black),
                      ),
                    ),
                  ),

                  /* ---------- Numéro de page cliquable ---------- */
                  GestureDetector(
                    onTap: () => _jumpToPageDialog(context),
                    child: SizedBox(
                      width: 50,                       // largeur fixe → reste centré
                      child: Text(
                        '$currentPage',
                        textAlign: TextAlign.center,   // centré même si 1 ou 3 chiffres
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ),
                  ),

                  /* ---------- Hafs / Warsh ---------- */
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () => setState(() =>
                          currentReading = currentReading == "hafs" ? "warsh" : "hafs"),
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

  /* ---------- Liste des sourates ---------- */
  void _showSurahSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: fullSurahList.length,
        itemBuilder: (context, index) {
          final s = fullSurahList[index];
          return ListTile(
            title: Text('${s['id']}. ${s['nameFr']}'), // français
            subtitle: Text(s['nameAr']),               // arabe
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