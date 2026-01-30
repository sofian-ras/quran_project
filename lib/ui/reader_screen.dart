import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'screens/quran_loader.dart';
import '../services/quran_image_service.dart';
import '../services/quran_page_preloader.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';
import '../services/reading_history_service.dart';
import '../services/bookmark_service.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    Key? key,
    this.style,
    required this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final int initialPage;
  final String reading;

  const ReaderScreen({
    super.key,
    this.initialPage = 1,
    this.reading = 'hafs',
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int currentPage;
  String currentReading = 'hafs';
  late PageController _pageController;

  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;
  Timer? _saveTimer;
  Timer? _preloadDebounce;
  bool _isBookmarked = false;

  final QuranPagePreloader _pagePreloader = QuranPagePreloader(range: 2);

  final Map<int, File?> _imageCache = {};
  final int _preloadRange = 3;

  Future<File?> _safeGetPageFile(String reading, int pageNum) async {
    try {
      return await QuranImageService.getPageFile(reading, pageNum);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshBookmarkStatus([int? page]) async {
    final p = page ?? currentPage;
    try {
      final requestedPage = p;
      final v = await BookmarkService.instance.isBookmarked(requestedPage);
      if (!mounted) return;
      if (currentPage != requestedPage) return;
      setState(() => _isBookmarked = v);
    } catch (e) {
      debugPrint('Erreur isBookmarked(page $p): $e');
    }
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );


    currentPage = widget.initialPage;
    currentReading = widget.reading;

    final startPage = (widget.initialPage < 1)
        ? 1
        : (widget.initialPage > 604 ? 604 : widget.initialPage);

    _pageController = PageController(initialPage: startPage - 1);
    _pageController.addListener(_onPageScroll);

    _initApp();
    _refreshBookmarkStatus(currentPage);
  }

  void _onPageScroll() {
    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 120), () {
      final currentIndex = _pageController.page?.round() ?? 0;
      _preloadPages(currentIndex + 1);
    });
  }

  Future<void> _preloadPages(int centerPage) async {
    for (int offset = -_preloadRange; offset <= _preloadRange; offset++) {
      final pageNum = centerPage + offset;
      if (pageNum >= 1 && pageNum <= 604 && !_imageCache.containsKey(pageNum)) {
        _loadPageIntoCache(pageNum);
      }
    }
    _cleanDistantPages(centerPage);
  }

  Future<void> _loadPageIntoCache(int pageNum) async {
    try {
      final file = await QuranImageService.getPageFile(currentReading, pageNum);
      _imageCache[pageNum] = file;
    } catch (e) {
      debugPrint('Erreur préchargement page $pageNum: $e');
    }
  }

  void _cleanDistantPages(int centerPage) {
    final pagesToRemove = <int>[];
    _imageCache.forEach((pageNum, _) {
      if ((pageNum - centerPage).abs() > _preloadRange * 2) {
        pagesToRemove.add(pageNum);
      }
    });

    for (final pageNum in pagesToRemove) {
      _imageCache.remove(pageNum);
    }
  }

  @override
  void dispose() {
    _preloadDebounce?.cancel();
    _saveTimer?.cancel();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _imageCache.clear();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );


    super.dispose();
  }

  Future<void> _initApp() async {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pagePreloader.preloadAround(context, currentPage, currentReading);
    });

    if (!mounted) return;
    setState(() => fullSurahList = list);
  }

  void _jumpToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
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
              _pageController.jumpToPage((s['page'] as int) - 1);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  String _hizbText(int page) {
    if (hizbMap.isEmpty) return '';
    final h = hizbMap.lastWhere(
      (e) => e['start_page']! <= page,
      orElse: () => hizbMap.first,
    );
    return 'Hizb ${h['hizb']}';
  }

  String _juzzText(int page) {
    if (juzzMap.isEmpty) return '';
    final j = juzzMap.lastWhere(
      (e) => e['start_page']! <= page,
      orElse: () => juzzMap.first,
    );
    return 'Juzz ${j['juz']}';
  }

  void _saveToHistory(int page) {
    if (fullSurahList.isEmpty) return;

    final surah = fullSurahList.firstWhere(
      (s) => s['page'] == page,
      orElse: () => fullSurahList.last,
    );

    ReadingHistoryService.instance.saveLastReading(
      page: page,
      surahId: surah['id'] as int,
      surahName: surah['nameFr'] as String,
      reading: currentReading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final viewPadding = MediaQuery.of(context).viewPadding;

    final surahNameFr = fullSurahList.isEmpty
        ? ''
        : (fullSurahList.lastWhere(
              (s) => (s['page'] as int) <= currentPage,
              orElse: () => fullSurahList.first,
            )['nameFr'] as String? ??
            '');

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _showUI = !_showUI),
        child: Stack(
          children: [
           Positioned.fill(
            child: ColoredBox(
              color: Colors.white, // fond fixe, ne suit pas le thème
              child: PageView.builder(
                controller: _pageController,
                reverse: true,
                itemCount: 604,
                onPageChanged: (p) {
                  setState(() => currentPage = p + 1);
                  _refreshBookmarkStatus(p + 1);
                  _preloadPages(p + 1);

                  SchedulerBinding.instance.scheduleTask<void>(
                    () {
                      _pagePreloader.preloadAround(context, p + 1, currentReading);
                      return;
                    },
                    Priority.idle,
                    debugLabel: 'quran_preload_pages',
                  );

                  _saveTimer?.cancel();
                  _saveTimer = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    _saveToHistory(p + 1);
                  });
                },
                itemBuilder: (context, i) {
                  final pageNum = i + 1;

                  final cached = _imageCache[pageNum];
                  if (cached != null) {
                    return _buildPageContent(cached, isLandscape);
                  }

                  return FutureBuilder<File?>(
                    future: _safeGetPageFile(currentReading, pageNum),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _loadingPage(context, pageNum);
                      }

                      final file = snapshot.data;
                      if (file == null) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => const QuranLoader()),
                              );
                              if (ok == true && mounted) setState(() {});
                            },
                            child: const Text('Télécharger les pages'),
                          ),
                        );
                      }

                      _imageCache[pageNum] = file;
                      return _buildPageContent(file, isLandscape);
                    },
                  );
                },
              ),
            ),
          ),


            // TOP overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: _showUI ? (viewPadding.top + 10) : (viewPadding.top - 80),
              left: 10,
              right: 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
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
                      Text(
                        '${_juzzText(currentPage)} ${_hizbText(currentPage)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Opacity(
                        opacity: 0.5,
                        child: IconButton(
                          icon: Icon(
                            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            size: 24,
                            color: _isBookmarked ? Colors.amber : Colors.black54,
                          ),
                          onPressed: () async {
                            try {
                              if (_isBookmarked) {
                                await BookmarkService.instance.removeBookmark(currentPage);
                                if (!mounted) return;
                                setState(() => _isBookmarked = false);
                              } else {
                                if (fullSurahList.isEmpty) return;

                                final surah = fullSurahList.lastWhere(
                                  (s) => s['page'] <= currentPage,
                                  orElse: () => fullSurahList.first,
                                );

                                await BookmarkService.instance.addBookmark(
                                  Bookmark(
                                    page: currentPage,
                                    surahId: surah['id'] as int,
                                    surahName: surah['nameFr'] as String,
                                    createdAt: DateTime.now(),
                                  ),
                                );

                                if (!mounted) return;
                                setState(() => _isBookmarked = true);
                              }
                            } catch (e) {
                              debugPrint('Erreur toggle bookmark: $e');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              bottom: _showUI ? (viewPadding.bottom + 12) : (viewPadding.bottom - 140),
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: isLandscape
                      ? _bottomBarLandscape()
                      : _bottomBarPortrait(surahNameFr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingPage(BuildContext context, int pageNum) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Page $pageNum',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chargement en cours...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBarLandscape() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _showSurahSelection,
                icon: const Icon(Icons.menu_book, color: Colors.white, size: 18),
                label: Text(
                  fullSurahList.isEmpty
                      ? ''
                      : fullSurahList.lastWhere(
                          (s) => s['page'] <= currentPage,
                          orElse: () => fullSurahList.first,
                        )['nameFr'],
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: _jumpToPageDialog,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Text(
                    '$currentPage',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    currentReading = (currentReading == 'hafs') ? 'warsh' : 'hafs';
                    _imageCache.clear();
                    _preloadPages(currentPage);
                  });
                },
                icon: Icon(Icons.auto_stories, color: Colors.brown.shade100, size: 18),
                label: Text(
                  currentReading.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBarPortrait(String surahNameFr) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showSurahSelection,
              icon: const Icon(Icons.menu_book, color: Colors.black54, size: 20),
              label: Text(
                surahNameFr,
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  currentReading = (currentReading == 'hafs') ? 'warsh' : 'hafs';
                  _imageCache.clear();
                  _preloadPages(currentPage);
                });
              },
              icon: Icon(Icons.auto_stories, color: Colors.brown.shade300),
              label: Text(
                currentReading.toUpperCase(),
                style: TextStyle(color: Colors.brown.shade400, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: _jumpToPageDialog,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.transparent,
                child: Text(
                  '$currentPage',
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(File imageFile, bool isLandscape) {
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
        }
        return Center(
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }
}
