import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'asset_manager.dart'; 
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
  int currentPage = 1;
  String currentReading = "hafs";
  Database? _db;
  final PageController _pageController = PageController();
  List<dynamic> quranData = [];
  List<Map<String, dynamic>> fullSurahList = [];

  bool showBottomBar = true;
  bool _isReady = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Vérifier/Télécharger les images
    bool alreadyDownloaded = await AssetManager.areAssetsDownloaded();
    if (!alreadyDownloaded) {
      try {
        await AssetManager.downloadAndExtract(onProgress: (p) {
          setState(() => _progress = p);
        });
      } catch (e) {
        debugPrint("Erreur init: $e");
      }
    } else {
      setState(() => _progress = 1.0);
    }

    // 2. Charger JSON des sourates
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    quranData = json.decode(jsonStr);
    final added = <int>{};
    for (final v in quranData) {
      final id = v['surah'];
      if (!added.contains(id)) {
        fullSurahList.add({
          'id': id,
          'nameAr': v['sura_name'] ?? 'Sourate $id',
          'nameFr': surahFr[id] ?? 'Sourate $id',
          'page': v['page'] ?? 1,
        });
        added.add(id);
      }
    }

    // 3. Base de données locale (Ayah info)
    final dbPath = p.join(await getDatabasesPath(), "ayahinfo_1120.db");
    if (!await databaseExists(dbPath)) {
      ByteData data = await rootBundle.load("assets/data/ayahinfo_1120.db");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes);
    }
    _db = await openDatabase(dbPath, readOnly: true);

    if (mounted) setState(() => _isReady = true);
  }

  void toggleBottomBar() => setState(() => showBottomBar = !showBottomBar);

  String _hizbText(int page) {
    final h = hizbMap.lastWhere((e) => e['start_page']! <= page, orElse: () => hizbMap.first);
    return 'Hizb n°${h['hizb']}';
  }

  String _juzzText(int page) {
    final j = juzzMap.lastWhere((e) => e['start_page']! <= page, orElse: () => juzzMap.first);
    return 'Juzz n°${j['juz']}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Préparation du Coran...", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(value: _progress, color: Colors.green),
              ),
              const SizedBox(height: 10),
              Text('${(_progress * 100).toStringAsFixed(0)} %'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
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
              itemBuilder: (context, i) {
                return FutureBuilder<File>(
                  future: AssetManager.getPageFile(currentReading, i + 1),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final imageFile = snapshot.data!;

                    // Utilisation de LayoutBuilder pour connaître la largeur disponible
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

                        if (isLandscape) {
                          // MODE PAYSAGE : Toute la largeur + Scroll vertical
                          return SingleChildScrollView(
                            child: Image.file(
                              imageFile,
                              width: constraints.maxWidth,
                              fit: BoxFit.fitWidth,
                              filterQuality: FilterQuality.high,
                            ),
                          );
                        } else {
                          // MODE PORTRAIT : Toute la page visible (Center)
                          return Center(
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
            
            // Infos Hizb / Juzz (Haut)
            if (showBottomBar)
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_juzzText(currentPage), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(_hizbText(currentPage), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

            // Barre de navigation (Bas)
            if (showBottomBar)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: _buildBottomUI(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomUI() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => _showSurahSelection(),
            child: Text(
              fullSurahList.lastWhere((s) => s['page'] <= currentPage)['nameFr'],
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => _jumpToPageDialog(),
            child: CircleAvatar(
              backgroundColor: Colors.green[50],
              child: Text('$currentPage', style: const TextStyle(color: Colors.green, fontSize: 12)),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => currentReading = (currentReading == "hafs") ? "warsh" : "hafs");
            },
            child: Text(currentReading.toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSurahSelection() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: fullSurahList.length,
        itemBuilder: (context, index) {
          final s = fullSurahList[index];
          return ListTile(
            leading: Text('${s['id']}'),
            title: Text(s['nameFr']),
            trailing: Text(s['nameAr'], style: const TextStyle(fontFamily: 'Amiri')),
            onTap: () {
              _pageController.jumpToPage(s['page'] - 1);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _jumpToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Aller à la page"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              int? p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= 604) {
                _pageController.jumpToPage(p - 1);
              }
              Navigator.pop(context);
            },
            child: const Text("Aller"),
          )
        ],
      ),
    );
  }
}