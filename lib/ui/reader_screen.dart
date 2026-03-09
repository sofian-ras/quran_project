import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/quran_loader.dart';
import '../services/quran_image_service.dart';
import '../services/quran_pages_hitbox_db.dart';
import '../services/mini_player_service.dart';
import 'widgets/ayah_selection_overlay.dart';
import 'widgets/ayah_bubble.dart';
import 'widgets/mini_player_widget.dart';
import '../services/quran_page_preloader.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';
import '../services/reading_history_service.dart';
import '../services/bookmark_service.dart';
import '../services/last_reading_service.dart';

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
  int _readerTheme = 1; // 0=blanc, 1=papier, 2=sombre
  late PageController _pageController;

  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;
  String? _selectedVerseKey;
  Timer? _saveTimer;
  Timer? _preloadDebounce;
  bool _isBookmarked = false;

  // ── Mini lecteur ──────────────────────────────────────────────────────────
  String? _selectionStartKey;
  String? _selectionEndKey;
  DateTime? _lastTapTime; // détection double tap

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

  Color get _themeBg => _readerTheme == 2
      ? const Color(0xFF0B1025)
      : (_readerTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));

  ColorFilter? get _themeFilter => _readerTheme == 2
      ? const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
           0,-1, 0, 0, 255,
           0, 0,-1, 0, 255,
           0, 0, 0, 1,   0,
        ])
      : (_readerTheme == 1
          ? const ColorFilter.matrix([
              // multiply(pixel, 0xFFF3E8C0) sans saveLayer :
              // R × 243/255, G × 232/255, B × 192/255
              0.9529, 0, 0, 0, 0,
              0, 0.9098, 0, 0, 0,
              0, 0, 0.7529, 0, 0,
              0, 0, 0,     1, 0,
            ])
          : null);

  Color get _themeIconColor => _readerTheme == 2 ? Colors.white60 : Colors.black45;

  Future<void> _loadReaderTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _readerTheme = prefs.getInt('reader_theme') ?? 1);
  }

  Future<void> _cycleReaderTheme() async {
    final next = (_readerTheme + 1) % 3;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_theme', next);
    if (!mounted) return;
    setState(() => _readerTheme = next);
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
    _loadReaderTheme();
    _refreshBookmarkStatus(currentPage);
    MiniPlayerService.instance.currentAyahKey.addListener(_onPlayingAyahChanged);
    () async {
      try {
        await QuranPagesHitboxDb.instance.ensureFromAsset(
          assetPath: 'assets/data/quranpages1024.sqlite',
        );
      } catch (e) {
        debugPrint('Erreur chargement hitbox: $e');
      }
    }();
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

  Future<void> _onPlayingAyahChanged() async {
    if (!mounted) return;
    final key = MiniPlayerService.instance.currentAyahKey.value;

    // Stop ou fin de lecture : efface le highlight
    if (key == null) {
      setState(() {});
      return;
    }

    final parts = key.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final ayah  = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return;

    final page = await QuranPagesHitboxDb.instance.getPageForAyah(surah, ayah);
    if (!mounted || page == null) return;

    if (page != currentPage) {
      _pageController.animateToPage(
        page - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    AyahBubble.dismiss();
    MiniPlayerService.instance.currentAyahKey.removeListener(_onPlayingAyahChanged);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A0033) : Colors.white,
      builder: (_) => ListView.builder(
        itemCount: fullSurahList.length,
        itemBuilder: (context, index) {
          final s = fullSurahList[index];
          return ListTile(
            leading: Text(
              '${s['id']}',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            title: Text(
              s['nameFr'],
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              s['nameAr'],
              style: TextStyle(
                fontFamily: 'Amiri',
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
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

    // Sauvegarder aussi la dernière position de lecture
    LastReadingService.saveLastReading(
      surahNumber: surah['id'] as int,
      pageNumber: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final viewPadding = MediaQuery.of(context).viewPadding;

    final currentSurah = fullSurahList.isEmpty
        ? 1
        : (fullSurahList.lastWhere(
              (s) => (s['page'] as int) <= currentPage,
              orElse: () => fullSurahList.first,
            )['id'] as int? ?? 1);

    final surahNameFr = fullSurahList.isEmpty
        ? ''
        : (fullSurahList.lastWhere(
              (s) => (s['page'] as int) <= currentPage,
              orElse: () => fullSurahList.first,
            )['nameFr'] as String? ??
            '');

    return Scaffold(
      backgroundColor: _themeBg,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
          children: [
           Positioned.fill(
            child: ColoredBox(
              color: _themeBg,
              child: PageView.builder(
                controller: _pageController,
                reverse: true,
                itemCount: 604,
                onPageChanged: (p) {
                  AyahBubble.dismiss();
                  setState(() {
                    currentPage = p + 1;
                    _selectedVerseKey = null;
                  });
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
                    return _buildPageContent(cached, isLandscape, pageNum);
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
                      return _buildPageContent(file, isLandscape, pageNum);
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
                          icon: Icon(Icons.arrow_back_ios, size: 20, color: _themeIconColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        '${_juzzText(currentPage)} ${_hizbText(currentPage)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _themeIconColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Opacity(
                        opacity: 0.6,
                        child: IconButton(
                          icon: Icon(
                            _readerTheme == 0
                                ? Icons.light_mode_outlined
                                : _readerTheme == 1
                                    ? Icons.brightness_medium_outlined
                                    : Icons.dark_mode_outlined,
                            size: 20,
                            color: _themeIconColor,
                          ),
                          onPressed: _cycleReaderTheme,
                        ),
                      ),
                      Opacity(
                        opacity: 0.5,
                        child: IconButton(
                          icon: Icon(
                            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            size: 24,
                            color: _isBookmarked ? Colors.amber : _themeIconColor,
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

            // BOTTOM overlay (mini lecteur + barre de navigation)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              bottom: _showUI ? (viewPadding.bottom + 8) : (viewPadding.bottom - 200),
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiniPlayerWidget(currentSurah: currentSurah),
                      const SizedBox(height: 6),
                      isLandscape
                          ? _bottomBarLandscape()
                          : _bottomBarPortrait(surahNameFr),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  // ── Tap simple ────────────────────────────────────────────────────────────

  void _onAyahTap(int surah, int ayah, Rect? globalRect) {
    // Double tap → tout effacer
    final now = DateTime.now();
    final isDouble = _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300);
    _lastTapTime = isDouble ? null : now;

    if (isDouble) {
      AyahBubble.dismiss();
      setState(() {
        _selectedVerseKey  = null;
        _selectionStartKey = null;
        _selectionEndKey   = null;
        MiniPlayerService.instance.clearSelection();
      });
      return;
    }

    AyahBubble.dismiss();

    // Plage complète → tout tap efface tout
    if (_selectionEndKey != null) {
      setState(() {
        _selectedVerseKey  = null;
        _selectionStartKey = null;
        _selectionEndKey   = null;
        MiniPlayerService.instance.clearSelection();
      });
      return;
    }

    if (surah == -1) {
      // Tap sur zone vide (pas de plage)
      final hadSelection = _selectionStartKey != null;
      setState(() {
        if (!hadSelection) _showUI = !_showUI;
        _selectedVerseKey  = null;
        _selectionStartKey = null;
        _selectionEndKey   = null;
        MiniPlayerService.instance.clearSelection();
      });
      return;
    }

    // Tap sur un verset : déplace la sélection si une est active
    if (_selectionStartKey != null) {
      final svc = MiniPlayerService.instance;
      svc.setSelectionStart(surah, ayah);
      setState(() {
        _selectedVerseKey  = '$surah:$ayah';
        _selectionStartKey = '$surah:$ayah';
        _selectionEndKey   = null;
      });
      if (globalRect != null) {
        AyahBubble.show(
          context,
          surah: surah,
          ayah: ayah,
          anchorGlobalRect: globalRect,
          onDismiss: () {
            if (mounted) setState(() => _selectedVerseKey = null);
          },
        );
      }
    }
  }

  // ── Long press ────────────────────────────────────────────────────────────

  void _onAyahLongPress(int surah, int ayah, Rect? globalRect) {
    if (surah == -1) return; // long press sur zone vide → ignoré

    final svc = MiniPlayerService.instance;
    AyahBubble.dismiss();

    if (_selectionStartKey == null || _selectionEndKey != null) {
      // ── 1er long press : marque le début + affiche la bulle ─────────────────
      svc.setSelectionStart(surah, ayah);
      setState(() {
        _selectedVerseKey  = '$surah:$ayah';
        _selectionStartKey = '$surah:$ayah';
        _selectionEndKey   = null;
      });
      if (globalRect != null) {
        AyahBubble.show(
          context,
          surah: surah,
          ayah: ayah,
          anchorGlobalRect: globalRect,
          onDismiss: () {
            if (mounted) setState(() => _selectedVerseKey = null);
          },
        );
      }
    } else {
      // ── 2ème long press : marque la fin, surbrille la plage, bulle pour jouer ──
      svc.setSelectionEnd(surah, ayah);
      setState(() {
        _selectedVerseKey  = '$surah:$ayah';
        _selectionStartKey = svc.selectionStartKey;
        _selectionEndKey   = svc.selectionEndKey;
        if (svc.playMode.value != MiniPlayMode.selection) {
          svc.playMode.value = MiniPlayMode.selection;
        }
      });
      if (globalRect != null) {
        AyahBubble.show(
          context,
          surah: surah,
          ayah: ayah,
          anchorGlobalRect: globalRect,
          onDismiss: () {
            if (mounted) setState(() => _selectedVerseKey = null);
          },
        );
      }
    }
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
            color: Colors.black54.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _showSurahSelection,
                icon: Icon(Icons.menu_book, color: _themeIconColor, size: 18),
                label: Text(
                  fullSurahList.isEmpty
                      ? ''
                      : fullSurahList.lastWhere(
                          (s) => s['page'] <= currentPage,
                          orElse: () => fullSurahList.first,
                        )['nameFr'],
                  style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: _jumpToPageDialog,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _themeIconColor.withValues(alpha: 0.15),
                  child: Text(
                    '$currentPage',
                    style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
                  ),
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
              icon: Icon(Icons.menu_book, color: _themeIconColor, size: 20),
              label: Text(
                surahNameFr,
                style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(File imageFile, bool isLandscape, int pageNum) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
        const imagePxSize = Size(1024, 1657); // taille réelle PNG Hafs 1024px

        Widget wrapFilter(Widget child) => _themeFilter != null
            ? ColorFiltered(colorFilter: _themeFilter!, child: child)
            : child;

        if (isLandscape) {
          return SingleChildScrollView(
            child: wrapFilter(Image.file(
              imageFile,
              width: constraints.maxWidth,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            )),
          );
        }

        // Calcul de la zone réelle de l'image (BoxFit.contain)
        final imgAspect = imagePxSize.width / imagePxSize.height;
        final dispAspect = displaySize.width / displaySize.height;
        double imgW, imgH, offsetX, offsetY;
        if (imgAspect > dispAspect) {
          imgW = displaySize.width;
          imgH = imgW / imgAspect;
          offsetX = 0;
          offsetY = (displaySize.height - imgH) / 2;
        } else {
          imgH = displaySize.height;
          imgW = imgH * imgAspect;
          offsetX = (displaySize.width - imgW) / 2;
          offsetY = 0;
        }

        return Stack(
          children: [
            Center(
              child: wrapFilter(Image.file(
                imageFile,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              )),
            ),
            Positioned(
              left: offsetX,
              top: offsetY,
              width: imgW,
              height: imgH,
              child: AyahSelectionOverlay(
                page: pageNum,
                displaySize: Size(imgW, imgH),
                imageSize: imagePxSize,
                selectedVerseKey: _selectedVerseKey,
                onAyahTap: _onAyahTap,
                onAyahLongPress: _onAyahLongPress,
                playingAyahKey:    MiniPlayerService.instance.currentAyahKey.value,
                selectionStartKey: _selectionStartKey,
                selectionEndKey:   _selectionEndKey,
              ),
            ),
          ],
        );
      },
    );
  }
}
