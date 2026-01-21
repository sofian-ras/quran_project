// ============================
// READER SCREEN FINAL V3
// ============================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../asset_manager.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText(this.text, {Key? key, this.style, required this.gradient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final int initialPage;
  final String reading;

  const ReaderScreen({super.key, this.initialPage = 1, this.reading = 'hafs'}) : super();

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int currentPage;
  String currentReading = 'hafs';
  late PageController _pageController;
  bool _isReady = false;
  double _progress = 0.0;
  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    currentReading = widget.reading;
    final startPage = (widget.initialPage < 1) ? 1 : (widget.initialPage > 604 ? 604 : widget.initialPage);
    _pageController = PageController(initialPage: startPage - 1);
    _initApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    bool alreadyDownloaded = await AssetManager.areAssetsDownloaded();
    if (!alreadyDownloaded) {
      try {
        await AssetManager.downloadAndExtract(onProgress: (p) {
          setState(() => _progress = p);
        });
      } catch (e) {
        debugPrint('Erreur init: $e');
      }
    } else {
      setState(() => _progress = 1.0);
    }

    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;
    final added = <int>{};
    final List<Map<String, dynamic>> list = [];
    for (final v in quranData) {
      final id = v['surah'] as int;
      if (!added.contains(id)) {
        list.add({
          'id': id,
          'nameAr': v['sura_name'] ?? 'Sourate $id',
          'nameFr': surahFr[id] ?? 'Sourate $id',
          'page': v['page'] ?? 1,
        });
        added.add(id);
      }
    }
    setState(() {
      fullSurahList = list;
      _isReady = true;
    });
  }

  void _jumpToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              int? p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= 604) {
                _pageController.jumpToPage(p - 1);
              }
              Navigator.pop(context);
            },
            child: const Text('Aller'),
          )
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

  String _hizbText(int page) {
    final h = hizbMap.lastWhere((e) => e['start_page']! <= page, orElse: () => hizbMap.first);
    return 'Hizb ${h['hizb']}';
  }

  String _juzzText(int page) {
    final j = juzzMap.lastWhere((e) => e['start_page']! <= page, orElse: () => juzzMap.first);
    return 'Juzz ${j['juz']}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lecture')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Préparation de votre Coran...', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(width: 200, child: LinearProgressIndicator(value: _progress, color: Colors.green)),
            const SizedBox(height: 10),
            Text('${(_progress * 100).toStringAsFixed(0)} %'),
          ]),
        ),
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _showUI = !_showUI),
        child: Stack(
          children: [
            // PageView
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
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (isLandscape) {
                          return SingleChildScrollView(
                            child: Image.file(
                              imageFile,
                              width: constraints.maxWidth,
                              fit: BoxFit.fitWidth,
                              filterQuality: FilterQuality.high,
                            ),
                          );
                        } else {
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

            // Barre supérieure : flèche retour + Juzz/Hizb
            if (_showUI)
              Positioned(
                top: 20,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Opacity(
                      opacity: 0.5,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_juzzText(currentPage)} ${_hizbText(currentPage)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

            // Barre inférieure avec numéro de page toujours centré
            if (_showUI)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      // Bouton Sourate à gauche
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showSurahSelection(),
                          icon: const Icon(Icons.menu_book, color: Colors.black54, size: 20),
                          label: Text(
                            fullSurahList.lastWhere((s) => s['page'] <= currentPage)['nameFr'],
                            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Bouton Hafs/Warsh à droite
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => currentReading = (currentReading == 'hafs') ? 'warsh' : 'hafs'),
                          icon: Icon(Icons.auto_stories, color: Colors.brown.shade300),
                          label: Text(
                            currentReading.toUpperCase(),
                            style: TextStyle(color: Colors.brown.shade400, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Numéro de page au centre
                      Align(
                        alignment: Alignment.center,
                        child: InkWell(
                          onTap: () => _jumpToPageDialog(),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.transparent,
                            child: Text(
                              '$currentPage',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
