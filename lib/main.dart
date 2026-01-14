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
  AppGeometry({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const QuranApp());
}

const List<int> surahAyahCounts = [
  7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,
  98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,
  75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,13,
  14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,29,19,
  36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,9,5,4,7,
  3,6,3,5,4,5,6
];

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

  /// 🔹 glyphs chargés UNE FOIS par page
  List<Map<String, dynamic>> _pageGlyphs = [];

  final AudioPlayer _audioPlayer = AudioPlayer();
  int? currentS, currentA;
  bool _isAudioPlaying = false;
  bool autoNext = true;

  bool _showUI = true;
  Set<String> selectedVerses = {};

  String selectedReciter = "Alafasy";

  final Map<String, String> reciterFolders = {
    'Alafasy': 'Alafasy',
    'Minshawy': 'Minshawy',
    'Maher_Almuaiqly': 'Maher_AlMuaiqly',
    'Abdul_Basit_Murattal': 'Abdul_Basit_Murattal',
    'Husary_Murattal': 'Husary_Murattal',
    'Alhudhayfi': 'AlHudhayfi',
    'Shuraim': 'Shuraim',
    'Soudais': 'Soudais',
    'Alajmi': 'AlAjmi',
    'Hudhaify': 'Hudhaify',
  };

  @override
  void initState() {
    super.initState();
    _initApp();
    _initAudioListener();
  }

  Future<void> _initApp() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    quranData = json.decode(jsonStr);

    final added = <int>{};
    for (final v in quranData) {
      if (!added.contains(v['surah'])) {
        fullSurahList.add({
          'id': v['surah'],
          'name': v['sura_name'],
          'page': v['page'],
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
    await _loadPageGlyphs(currentPage);

    if (mounted) setState(() {});
  }

  Future<void> _loadPageGlyphs(int page) async {
    if (_db == null) return;
    _pageGlyphs = await _db!.rawQuery(
      "SELECT * FROM glyphs WHERE page_number = ?",
      [page],
    );
  }

  AppGeometry _calculateGeometry(BoxConstraints c) {
    const imgW = 1300.0, imgH = 2103.0;
    final scale = (c.maxWidth / c.maxHeight > imgW / imgH)
        ? c.maxHeight / imgH
        : c.maxWidth / imgW;

    return AppGeometry(
      scale: scale,
      offsetX: (c.maxWidth - imgW * scale) / 2,
      offsetY: (c.maxHeight - imgH * scale) / 2,
    );
  }

  void _handleTap(TapDownDetails d, AppGeometry g) {
    setState(() {
      selectedVerses.clear();
      _showUI = !_showUI;
    });
  }

  void _handleLongPress(LongPressStartDetails d, AppGeometry g) async {
    if (_db == null) return;

    final x = (d.localPosition.dx - g.offsetX) / g.scale;
    final y = (d.localPosition.dy - g.offsetY) / g.scale;

    final res = await _db!.rawQuery('''
      SELECT sura_number, ayah_number FROM glyphs
      WHERE page_number = ?
      AND ? BETWEEN min_x AND max_x
      AND ? BETWEEN min_y AND max_y
      LIMIT 1
    ''', [currentPage, x.toInt(), y.toInt()]);

    if (res.isNotEmpty) {
      final s = res.first['sura_number']as int;
      final a = res.first['ayah_number'] as int;
      setState(() => selectedVerses = {"${s}_$a"});
      _showVerseOptions(s, a);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: _buildDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final geo = _calculateGeometry(constraints);

          return Stack(
            children: [
              /// 📖 MUSHAF (NE BOUGE JAMAIS)
              PageView.builder(
                controller: _pageController,
                reverse: true,
                itemCount: 604,
                onPageChanged: (p) async {
                  currentPage = p + 1;
                  selectedVerses.clear();
                  await _loadPageGlyphs(currentPage);
                  if (mounted) setState(() {});
                },
                itemBuilder: (_, i) {
                  final page = i + 1;
                  final file =
                      currentReading == "hafs" ? "$page.png" : "$page.jpg";

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (d) => _handleTap(d, geo),
                    onLongPressStart: (d) => _handleLongPress(d, geo),
                    child: Center(
                      child: Image.asset(
                        'assets/mushaf/$currentReading/$file',
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),

              /// 🟨 SURBRILLANCE (ALIGNEMENT PARFAIT)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _VersePainter(
                    glyphs: _pageGlyphs,
                    selected: selectedVerses,
                    geo: geo,
                  ),
                ),
              ),

              /// 🔼 BARRE HAUTE ANIMÉE
              _buildTopBar(),

              /// 🔊 BARRE AUDIO
              if (currentS != null && _showUI) _buildAudioBar(),
            ],
          );
        },
      ),
    );
  }
  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: _showUI ? 0 : -90,
      left: 0,
      right: 0,
      height: 90,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(235, 253, 247, 231),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Page $currentPage",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        currentReading =
                            currentReading == "hafs" ? "warsh" : "hafs";
                      });
                    },
                    child: Text(currentReading.toUpperCase()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() => Drawer(
        child: ListView(
          children: fullSurahList
              .map((s) => ListTile(
                    title: Text(s['name']),
                    onTap: () {
                      _pageController.jumpToPage(s['page'] - 1);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      );

  Widget _buildAudioBar() => Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                    _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white),
                onPressed: () {
                  _isAudioPlaying
                      ? _audioPlayer.pause()
                      : _audioPlayer.play();
                  setState(() => _isAudioPlaying = !_isAudioPlaying);
                },
              ),
              Text("$currentS:$currentA",
                  style: const TextStyle(color: Colors.white)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: _stopAudio),
            ],
          ),
        ),
      );

  void _initAudioListener() {
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && autoNext) {
        _handleNextVerse();
      }
    });
  }

  void _handleNextVerse() async {
    if (currentS == null || currentA == null) return;
    int s = currentS!, a = currentA! + 1;
    if (a > surahAyahCounts[s - 1]) {
      if (s == 114) return _stopAudio();
      s++;
      a = 1;
    }
    _playAudio(s, a);
  }

  void _playAudio(int s, int a) async {
    final folder = reciterFolders[selectedReciter]!;
    final url =
        "https://everyayah.com/data/$folder/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3";

    await _audioPlayer.setUrl(url);
    _audioPlayer.play();

    setState(() {
      currentS = s;
      currentA = a;
      _isAudioPlaying = true;
    });
  }

  void _stopAudio() {
    _audioPlayer.stop();
    setState(() {
      currentS = null;
      currentA = null;
      _isAudioPlaying = false;
    });
  }

  void _showVerseOptions(int s, int a) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Center(
        child: ElevatedButton(
          onPressed: () => _playAudio(s, a),
          child: const Text("Lecture audio"),
        ),
      ),
    );
  }
}

class _VersePainter extends CustomPainter {
  final List<Map<String, dynamic>> glyphs;
  final Set<String> selected;
  final AppGeometry geo;

  _VersePainter({
    required this.glyphs,
    required this.selected,
    required this.geo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.amber.withOpacity(0.35);

    for (final g in glyphs) {
      final id = "${g['sura_number']}_${g['ayah_number']}";
      if (!selected.contains(id)) continue;

      final r = Rect.fromLTWH(
        geo.offsetX + g['min_x'] * geo.scale,
        geo.offsetY + g['min_y'] * geo.scale,
        (g['max_x'] - g['min_x']) * geo.scale,
        (g['max_y'] - g['min_y']) * geo.scale,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VersePainter old) =>
      old.selected != selected || old.geo.scale != geo.scale;
}
