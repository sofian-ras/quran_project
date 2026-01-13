import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

class AppGeometry {
  final double scale;
  final double offsetX;
  final double offsetY;
  AppGeometry({required this.scale, required this.offsetX, required this.offsetY});
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const QuranApp());
}

const List<int> surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110,
  98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88,
  75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19,
  36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7,
  3, 6, 3, 5, 4, 5, 6
];

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFDF7E7)),
        home: const QuranHomePage(),
      );
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

  final AudioPlayer _audioPlayer = AudioPlayer();
  int? currentS, currentA;
  bool _isAudioPlaying = false;
  bool autoNext = true;
  String selectedReciter = "abdurrashid_sufi";

  bool _showUI = true;
  Set<String> selectedVerses = {};

  @override
  void initState() {
    super.initState();
    _initApp();
    _initAudioListener();
  }

  Future<void> _initApp() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
      quranData = json.decode(jsonStr);
      Set<int> added = {};
      for (var item in quranData) {
        if (!added.contains(item['surah'])) {
          fullSurahList.add({
            "id": item['surah'],
            "name": "Sourate ${item['surah']}",
            "page": item['page'] ?? 1
          });
          added.add(item['surah']);
        }
      }

      var path = p.join(await getDatabasesPath(), "ayahinfo_1120.db");
      if (!await databaseExists(path)) {
        ByteData data = await rootBundle.load("assets/data/ayahinfo_1120.db");
        await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _db = await openDatabase(path, readOnly: true);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  AppGeometry _calculateGeometry(BoxConstraints constraints) {
    const double imgW = 1120.0, imgH = 1826.0;
    double scale = (constraints.maxWidth / constraints.maxHeight > imgW / imgH)
        ? constraints.maxHeight / imgH
        : constraints.maxWidth / imgW;
    return AppGeometry(
        scale: scale,
        offsetX: (constraints.maxWidth - (imgW * scale)) / 2,
        offsetY: (constraints.maxHeight - (imgH * scale)) / 2);
  }

  void _handleTap(TapDownDetails details, AppGeometry geo) async {
    if (_db == null) return;
    try {
      double dbX = (details.localPosition.dx - geo.offsetX) / geo.scale;
      double dbY = (details.localPosition.dy - geo.offsetY) / geo.scale;
      debugPrint("Tap détecté -> Page: $currentPage, X: $dbX, Y: $dbY");

      List<Map<String, dynamic>> res = await _db!.rawQuery('''
        SELECT sura_number, ayah_number FROM glyphs
        WHERE page_number = ?
        AND ? BETWEEN min_x AND max_x
        AND ? BETWEEN min_y AND max_y
        LIMIT 1
      ''', [currentPage, dbX.toInt(), dbY.toInt()]);

      if (res.isNotEmpty) {
        final s = res.first['sura_number'];
        final a = res.first['ayah_number'];
        if (s != null && a != null) {
          setState(() {
            selectedVerses = {"${s}_$a"};
          });
          _showVerseOptions(s as int, a as int);
        }
      } else {
        setState(() {
          selectedVerses.clear();
          _showUI = !_showUI;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du clic : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(),
      appBar: _showUI ? _buildAppBar() : null,
      body: LayoutBuilder(builder: (context, constraints) {
        final geo = _calculateGeometry(constraints);
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: 604,
              reverse: true,
              onPageChanged: (p) => setState(() {
                currentPage = p + 1;
                selectedVerses.clear();
              }),
              itemBuilder: (context, index) {
                int pageNum = index + 1;
                String fileName = (currentReading == "hafs")
                    ? "page${pageNum.toString().padLeft(3, '0')}.png"
                    : "$pageNum.jpg";

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) => _handleTap(details, geo),
                  child: Center(
                    child: Image.asset(
                      'assets/mushaf/$currentReading/$fileName',
                      fit: BoxFit.contain,
                      errorBuilder: (context, e, s) =>
                          Center(child: Text("Fichier manquant: $fileName")),
                    ),
                  ),
                );
              },
            ),
            _buildOverlay(geo),
            if (currentS != null && _showUI) _buildAudioControlBar(),
          ],
        );
      }),
    );
  }

  Widget _buildOverlay(AppGeometry geo) {
    if (_db == null) return const SizedBox();
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _db!.rawQuery("SELECT * FROM glyphs WHERE page_number = ?", [currentPage]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          return Stack(
            children: snapshot.data!.map((g) {
              String vId = "${g['sura_number']}_${g['ayah_number']}";
              bool isSelected = selectedVerses.contains(vId);
              if (!isSelected) return const SizedBox();
              return Positioned(
                left: geo.offsetX + ((g['min_x'] ?? 0) * geo.scale),
                top: geo.offsetY + ((g['min_y'] ?? 0) * geo.scale),
                width: ((g['max_x'] ?? 0) - (g['min_x'] ?? 0)) * geo.scale,
                height: ((g['max_y'] ?? 0) - (g['min_y'] ?? 0)) * geo.scale,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(80),
                      borderRadius: BorderRadius.circular(2)),
                ),
              );
            }).toList(),
          );
        });
  }

  void _showVerseOptions(int s, int a) {
    final verse = quranData.firstWhere(
        (v) => v['surah'] == s && v['ayah'] == a,
        orElse: () => null);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                  color: Color(0xFF121212),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Sourate $s | Verset $a",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _playAudio(s, a);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Audio"),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Expanded(
                      child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text("TRADUCTION",
                          style: TextStyle(color: Colors.amber, fontSize: 10)),
                      const SizedBox(height: 10),
                      Text(verse?['fr'] ?? "",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 30),
                      const Text("TAFSIR",
                          style: TextStyle(color: Colors.amber, fontSize: 10)),
                      const SizedBox(height: 10),
                      _TafsirLoader(surah: s, ayah: a),
                    ],
                  ))
                ],
              ),
            ));
  }

  void _initAudioListener() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && autoNext)
        _handleNextVerse();
    });
  }

  void _handleNextVerse() async {
    if (currentS == null || currentA == null) return;
    int nextS = currentS!, nextA = currentA! + 1;
    if (nextA > surahAyahCounts[currentS! - 1]) {
      if (currentS! < 114) {
        nextS++;
        nextA = 1;
      } else {
        _stopAudio();
        return;
      }
    }
    if (_db != null) {
      List<Map<String, dynamic>> res = await _db!.rawQuery(
          "SELECT page_number FROM glyphs WHERE sura_number = ? AND ayah_number = ? LIMIT 1",
          [nextS, nextA]);
      if (res.isNotEmpty && res.first['page_number'] != currentPage) {
        _pageController.animateToPage(res.first['page_number'] - 1,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
    }
    _playAudio(nextS, nextA);
  }

  void _playAudio(int s, int a) async {
    String url =
        "https://tanzil.net/res/audio/$selectedReciter/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3";
    try {
      setState(() {
        currentS = s;
        currentA = a;
        _isAudioPlaying = true;
      });
      await _audioPlayer.setUrl(url);
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  void _stopAudio() {
    _audioPlayer.stop();
    setState(() {
      currentS = null;
      currentA = null;
      _isAudioPlaying = false;
    });
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: const Color.fromARGB(230, 253, 247, 231),
        title: Text("Page $currentPage", style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => currentReading = currentReading == "hafs" ? "warsh" : "hafs"),
            child: Text(currentReading.toUpperCase()),
          )
        ],
      );

  Widget _buildDrawer() => Drawer(
        child: ListView.builder(
          itemCount: fullSurahList.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(fullSurahList[i]['name']),
            onTap: () {
              _pageController.jumpToPage(fullSurahList[i]['page'] - 1);
              Navigator.pop(context);
            },
          ),
        ),
      );

  Widget _buildAudioControlBar() => Positioned(
        bottom: 30,
        left: 15,
        right: 15,
        child: Container(
          height: 60,
          decoration:
              BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                  icon: Icon(_isAudioPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white),
                  onPressed: () {
                    _isAudioPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                    setState(() => _isAudioPlaying = !_isAudioPlaying);
                  }),
              Text("Verset $currentS:$currentA",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white24), onPressed: _stopAudio),
            ],
          ),
        ),
      );
}

class _TafsirLoader extends StatelessWidget {
  final int surah, ayah;
  const _TafsirLoader({required this.surah, required this.ayah});
  Future<String> fetch() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.quran.com/api/v4/tafsirs/16/by_ayah/$surah:$ayah'));
      if (r.statusCode == 200) {
        return json.decode(r.body)['tafsir']['text'].replaceAll(RegExp(r'<[^>]*>'), '');
      }
    } catch (e) {
      return "Erreur de connexion";
    }
    return "Erreur Tafsir";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: fetch(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return Text(snap.data!,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Colors.white70, fontSize: 15));
        });
  }
}
