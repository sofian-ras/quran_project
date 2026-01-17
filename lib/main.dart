import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'hizb_juzz.dart';
import 'surah_name.dart';
import 'package:archive/archive_io.dart';
import 'package:archive/archive.dart';

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

  /// Télécharge le ZIP depuis Google Drive et décompresse
  Future<void> downloadAndExtractFromDrive({required Function(double) onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    final zipFile = File(p.join(dir.path, "quran_pages.zip"));

    if (!await zipFile.exists()) {
      const url = 'https://drive.google.com/uc?export=download&id=1FDBfeza5AXF3yPZKk0Uyri8YcZn-LBuT';
      final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final contentLength = request.contentLength ?? 0;
      List<int> bytes = [];
      int received = 0;

      await request.stream.listen((chunk) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      }).asFuture();

      await zipFile.writeAsBytes(bytes);
      print('ZIP téléchargé !');
    } else {
      print('ZIP déjà présent.');
      onProgress(1.0);
    }

    // Décompression
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filePath = p.join(dir.path, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
    print('ZIP décompressé !');
  }

  Future<void> _initApp() async {
    try {
      await downloadAndExtractFromDrive(onProgress: (p) {
        setState(() => _progress = p);
      });
      print('Pages prêtes en local !');
    } catch (e) {
      print('Erreur téléchargement/décompression: $e');
    }

    // Charger JSON
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

    // Base de données locale
    final path = p.join(await getDatabasesPath(), "ayahinfo_1120.db");
    if (!await databaseExists(path)) {
      final data = await rootBundle.load("assets/data/ayahinfo_1120.db");
      await File(path).writeAsBytes(data.buffer.asUint8List());
    }
    _db = await openDatabase(path, readOnly: true);

    if (mounted) setState(() => _isReady = true);
  }

  Future<File> getPageFile(String reading, String fileName) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/quran_pages');
    final file = File('${dir.path}/$reading/$fileName');
    return file;
  }

  void toggleBottomBar() => setState(() => showBottomBar = !showBottomBar);

  void selectSurah(int page) => _pageController.jumpToPage(page - 1);

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

  String _hizbText(int page) {
    final h = hizbMap.lastWhere((e) => e['start_page']! <= page);
    final hizb = h['hizb']!;
    final start = h['start_page']!;
    final nextStart =
        hizb == 60 ? 605 : hizbMap.firstWhere((e) => e['hizb'] == hizb + 1)['start_page']!;
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
    final nextStart =
        juzz == 30 ? 605 : juzzMap.firstWhere((e) => e['juz'] == juzz + 1)['start_page']!;
    final total = nextStart - start;
    final done = page - start + 1;
    final quart = ((done * 4) ~/ total).clamp(0, 3);
    final frac = quart == 0 ? '' : ' ${['1/4', '1/2', '3/4'][quart - 1]}';
    return '$frac juzz n°$juzz';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        backgroundColor: const Color(0xFFFEFCF9),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text('${(_progress * 100).toStringAsFixed(0)} %'),
            ],
          ),
        ),
      );
    }

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
                final fileName = currentReading == "hafs" ? "$page.png" : "$page.jpg";
                return FutureBuilder<File>(
                  future: getPageFile(currentReading, fileName),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final imageFile = snapshot.data!;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isLandscape =
                            MediaQuery.of(context).orientation == Orientation.landscape;
                        if (isLandscape) {
                          return SingleChildScrollView(
                            child: Image.file(
                              imageFile,
                              width: constraints.maxWidth,
                              fit: BoxFit.fitWidth,
                            ),
                          );
                        } else {
                          return Center(
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.contain,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
            Positioned(
              top: 8,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_hizbText(currentPage),
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w300)),
                  Text(_juzzText(currentPage),
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            if (showBottomBar && MediaQuery.of(context).orientation != Orientation.landscape)
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
                          fullSurahList
                              .lastWhere((s) => s['page']! <= currentPage, orElse: () => {'nameFr': ''})['nameFr'],
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _jumpToPageDialog(context),
                      child: SizedBox(
                        width: 50,
                        child: Text(
                          '$currentPage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed: () => setState(() =>
                            currentReading = currentReading == "hafs" ? "warsh" : "hafs"),
                        child: Text(
                          currentReading.toUpperCase(),
                          style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
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
            title: Text('${s['id']}. ${s['nameFr']}'),
            subtitle: Text(s['nameAr']),
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
