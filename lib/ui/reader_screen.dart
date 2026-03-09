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
import '../services/last_reading_service.dart';
import '../services/verse_notes_service.dart';

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

  // ── Notes ─────────────────────────────────────────────────────────────────
  Set<String> _noteKeys = {};

  Future<void> _loadNoteKeys() async {
    final all = await VerseNotesService.instance.getAll();
    if (!mounted) return;
    setState(() => _noteKeys = all.keys.toSet());
  }

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

  void _applySystemUiStyle(int theme) {
    SystemChrome.setSystemUIOverlayStyle(
      theme == 2
          ? SystemUiOverlayStyle.light  // thème sombre → icônes blanches
          : SystemUiOverlayStyle.dark,  // blanc/papier → icônes noires
    );
  }

  Future<void> _loadReaderTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final theme = prefs.getInt('reader_theme') ?? 1;
    setState(() => _readerTheme = theme);
    _applySystemUiStyle(theme);
  }

  Future<void> _cycleReaderTheme() async {
    final next = (_readerTheme + 1) % 3;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_theme', next);
    if (!mounted) return;
    setState(() => _readerTheme = next);
    _applySystemUiStyle(next);
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
    _loadNoteKeys();
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

    // Restaure les icônes système par défaut à la sortie du reader
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

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

  // ── Éditeur de note ───────────────────────────────────────────────────────

  void _showNoteEditor(int surah, int ayah) {
    final key = '$surah:$ayah';
    final isDark = _readerTheme == 2;
    final existing = VerseNotesService.instance.getNote(key);
    final ctrl = TextEditingController(text: existing ?? '');
    final name = surahFr[surah] ?? 'Sourate $surah';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name  ·  verset $ayah',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Écrire une note…',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A2E40)
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (existing != null)
                  TextButton.icon(
                    onPressed: () async {
                      await VerseNotesService.instance.deleteNote(key);
                      if (!mounted) return;
                      _loadNoteKeys();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.redAccent),
                    label: const Text('Supprimer',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC8A165),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await VerseNotesService.instance.setNote(key, ctrl.text);
                    if (!mounted) return;
                    _loadNoteKeys();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste des notes ───────────────────────────────────────────────────────

  void _showNotesListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotesListSheet(
        isDark: _readerTheme == 2,
        onNoteDeleted: _loadNoteKeys,
        onNoteEdited: (surah, ayah) => _showNoteEditor(surah, ayah),
        onNavigate: (surah, ayah) async {
          // Ferme le sheet depuis le contexte du reader (garantit le bon Navigator)
          if (mounted) Navigator.pop(context);
          final page = await QuranPagesHitboxDb.instance
              .getPageForAyah(surah, ayah);
          if (page != null && mounted) {
            _pageController.jumpToPage(page - 1);
          }
        },
      ),
    );
  }

  void _showNavigationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NavigationPicker(
        surahList: fullSurahList,
        currentPage: currentPage,
        isDark: _readerTheme == 2,
        onConfirm: (surahId, ayah) async {
          Navigator.pop(context);
          final page = await QuranPagesHitboxDb.instance.getPageForAyah(surahId, ayah);
          if (page != null && mounted) _pageController.jumpToPage(page - 1);
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
                        opacity: 0.7,
                        child: IconButton(
                          icon: Icon(
                            _noteKeys.isNotEmpty
                                ? Icons.sticky_note_2_rounded
                                : Icons.sticky_note_2_outlined,
                            size: 24,
                            color: _noteKeys.isNotEmpty
                                ? const Color(0xFFFF8F00)
                                : _themeIconColor,
                          ),
                          onPressed: _showNotesListModal,
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

    if (surah == -1 || _selectionStartKey == null) {
      // Tap sur zone vide OU sur un verset sans sélection active → toggle UI
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

    // Tap sur un verset avec une sélection active → déplace la sélection
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
          onNote: () => _showNoteEditor(surah, ayah),
          hasNote: _noteKeys.contains('$surah:$ayah'),
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
          onNote: () => _showNoteEditor(surah, ayah),
          hasNote: _noteKeys.contains('$surah:$ayah'),
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
          onNote: () => _showNoteEditor(surah, ayah),
          hasNote: _noteKeys.contains('$surah:$ayah'),
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
                onPressed: _showNavigationPicker,
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
              CircleAvatar(
                radius: 18,
                backgroundColor: _themeIconColor.withValues(alpha: 0.15),
                child: Text(
                  '$currentPage',
                  style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
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
              onPressed: _showNavigationPicker,
              icon: Icon(Icons.menu_book, color: _themeIconColor, size: 20),
              label: Text(
                surahNameFr,
                style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              '$currentPage',
              style: TextStyle(color: _themeIconColor, fontWeight: FontWeight.bold),
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
                noteAyahKeys:      _noteKeys,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Nombre de versets par sourate (index 1-based, index 0 inutilisé) ─────────
const _kSurahVerseCount = [
  0,
   7, 286, 200, 176, 120, 165, 206,  75, 129, 109, // 1-10
 123, 111,  43,  52,  99, 128, 111, 110,  98, 135, // 11-20
 112,  78, 118,  64,  77, 227,  93,  88,  69,  60, // 21-30
  34,  30,  73,  54,  45,  83, 182,  88,  75,  85, // 31-40
  54,  53,  89,  59,  37,  35,  38,  29,  18,  45, // 41-50
  60,  49,  62,  55,  78,  96,  29,  22,  24,  13, // 51-60
  14,  11,  11,  18,  12,  12,  30,  52,  52,  44, // 61-70
  28,  28,  20,  56,  40,  31,  50,  40,  46,  42, // 71-80
  29,  19,  36,  25,  22,  17,  19,  26,  30,  20, // 81-90
  15,  21,  11,   8,   8,  19,   5,   8,   8,  11, // 91-100
  11,   8,   3,   9,   5,   4,   7,   3,   6,   3, // 101-110
   5,   4,   5,   6,                               // 111-114
];

/// Début exact de chaque juzz (index 0 = juzz 1).
/// Format : [surahId, ayah]  — référence Hafs.
const _kJuzzStart = [
  [1,   1], [2, 142], [2, 253], [3,  92], [4,  24],  // 1-5
  [4, 148], [5,  82], [6, 111], [7,  87], [8,  41],  // 6-10
  [9,  93], [11,  6], [12, 53], [15,   1], [17,  1], // 11-15
  [18, 75], [21,   1], [23,   1], [25,  21], [27, 56], // 16-20
  [29, 46], [33,  31], [36,  28], [39,  32], [41, 47], // 21-25
  [46,  1], [51,  31], [58,   1], [67,   1], [78,   1], // 26-30
];

// ── Liste des notes ───────────────────────────────────────────────────────────

class _NotesListSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onNoteDeleted;
  final void Function(int surah, int ayah) onNoteEdited;
  final Future<void> Function(int surah, int ayah) onNavigate;

  const _NotesListSheet({
    required this.isDark,
    required this.onNoteDeleted,
    required this.onNoteEdited,
    required this.onNavigate,
  });

  @override
  State<_NotesListSheet> createState() => _NotesListSheetState();
}

class _NotesListSheetState extends State<_NotesListSheet> {
  Map<String, String> _notes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await VerseNotesService.instance.getAll();
    if (!mounted) return;
    setState(() { _notes = Map.from(all); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg     = isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final fg     = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white38 : Colors.black38;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: subtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_rounded,
                      color: const Color(0xFFFF8F00), size: 22),
                  const SizedBox(width: 8),
                  Text('Mes notes',
                      style: TextStyle(
                          color: fg,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sticky_note_2_outlined,
                                  size: 48, color: subtle),
                              const SizedBox(height: 12),
                              Text('Aucune note',
                                  style: TextStyle(
                                      color: subtle,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      : ListView(
                          controller: ctrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: (_notes.entries.toList()
                            ..sort((a, b) {
                              int s(String k) =>
                                  int.tryParse(k.split(':').first) ?? 0;
                              int v(String k) =>
                                  int.tryParse(k.split(':').last) ?? 0;
                              final c = s(a.key).compareTo(s(b.key));
                              return c != 0 ? c : v(a.key).compareTo(v(b.key));
                            }))
                            .map<Widget>((e) {
                              final parts = e.key.split(':');
                              final surah =
                                  int.tryParse(parts[0]) ?? 0;
                              final ayah  =
                                  int.tryParse(parts[1]) ?? 0;
                              final name  =
                                  surahFr[surah] ?? 'Sourate $surah';
                              return Dismissible(
                                key: ValueKey(e.key),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: isDark
                                          ? const Color(0xFF1C2D3E)
                                          : Colors.white,
                                      title: Text('Supprimer la note',
                                          style: TextStyle(color: fg)),
                                      content: Text(
                                          'Supprimer la note de $name · verset $ayah ?',
                                          style: TextStyle(color: fg)),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Supprimer',
                                              style: TextStyle(
                                                  color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;
                                },
                                onDismissed: (_) async {
                                  await VerseNotesService.instance
                                      .deleteNote(e.key);
                                  if (mounted) {
                                    setState(() => _notes.remove(e.key));
                                    widget.onNoteDeleted();
                                  }
                                },
                                background: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.white, size: 24),
                                ),
                                child: Card(
                                color: isDark
                                    ? const Color(0xFF1C2D3E)
                                    : const Color(0xFFF9F5EE),
                                margin:
                                    const EdgeInsets.symmetric(vertical: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1C2D3E)
                                            : const Color(0xFFFAF6EE),
                                        title: Text(
                                          '$name  ·  verset $ayah',
                                          style: TextStyle(
                                              color: fg,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Text(e.value,
                                              style: TextStyle(
                                                  color: fg,
                                                  fontSize: 15,
                                                  height: 1.6)),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Fermer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFFFF8F00).withValues(alpha: 0.15),
                                    child: const Icon(Icons.sticky_note_2_rounded,
                                        color: Color(0xFFFF8F00), size: 20),
                                  ),
                                  title: Text('$name  ·  verset $ayah',
                                      style: TextStyle(
                                          color: fg,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(e.value,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: subtle, fontSize: 12)),
                                  trailing: IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        size: 18, color: subtle),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onNoteEdited(surah, ayah);
                                    },
                                  ),
                                ),
                              ),  // ferme Card
                              );  // ferme Dismissible
                            })
                            .toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Roulette de navigation : Juzz | Sourate | Verset ─────────────────────────
class _NavigationPicker extends StatefulWidget {
  final List<Map<String, dynamic>> surahList;
  final int currentPage;
  final bool isDark;
  final Future<void> Function(int surahId, int ayah) onConfirm;

  const _NavigationPicker({
    required this.surahList,
    required this.currentPage,
    required this.isDark,
    required this.onConfirm,
  });

  @override
  State<_NavigationPicker> createState() => _NavigationPickerState();
}

class _NavigationPickerState extends State<_NavigationPicker> {
  late int _selJuzz;
  late int _selSurahIdx;
  late int _selAyah;
  bool _syncing = false;

  late final FixedExtentScrollController _juzzCtrl;
  late final FixedExtentScrollController _surahCtrl;
  late final FixedExtentScrollController _ayahCtrl;

  // ── Helpers ──────────────────────────────────────────────────────────────

  int get _currentSurahId => widget.surahList[_selSurahIdx]['id'] as int;
  int get _verseCount => _kSurahVerseCount[_currentSurahId.clamp(1, 114)];

  int _juzzOfPage(int page) {
    for (int j = juzzMap.length - 1; j >= 0; j--) {
      if (juzzMap[j]['start_page']! <= page) return juzzMap[j]['juz']!;
    }
    return 1;
  }

  int _juzzOfSurah(int idx) {
    final page = widget.surahList[idx]['page'] as int;
    return _juzzOfPage(page);
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Initialise à la position actuelle
    _selSurahIdx = widget.surahList.lastIndexWhere(
      (s) => (s['page'] as int) <= widget.currentPage,
    ).clamp(0, widget.surahList.length - 1);
    _selJuzz  = _juzzOfSurah(_selSurahIdx);
    _selAyah  = 1;

    _juzzCtrl  = FixedExtentScrollController(initialItem: _selJuzz - 1);
    _surahCtrl = FixedExtentScrollController(initialItem: _selSurahIdx);
    _ayahCtrl  = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _juzzCtrl.dispose();
    _surahCtrl.dispose();
    _ayahCtrl.dispose();
    super.dispose();
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  void _onJuzzChanged(int idx) {
    if (_syncing) return;
    _syncing = true;
    final juzz = idx + 1;
    final start     = _kJuzzStart[idx];
    final surahId   = start[0];
    final startAyah = start[1];
    final surahIdx  = widget.surahList
        .indexWhere((s) => s['id'] == surahId)
        .clamp(0, widget.surahList.length - 1);
    setState(() {
      _selJuzz     = juzz;
      _selSurahIdx = surahIdx;
      _selAyah     = startAyah;
    });
    _surahCtrl.jumpToItem(surahIdx);
    _ayahCtrl.jumpToItem(startAyah - 1);
    _syncing = false;
  }

  void _onSurahChanged(int idx) {
    if (_syncing) return;
    _syncing = true;
    final juzz = _juzzOfSurah(idx);
    setState(() {
      _selSurahIdx = idx;
      _selJuzz     = juzz;
      _selAyah     = 1;
    });
    _juzzCtrl.jumpToItem(juzz - 1);
    _ayahCtrl.jumpToItem(0);
    _syncing = false;
  }

  void _onAyahChanged(int idx) {
    if (_syncing) return;
    setState(() => _selAyah = idx + 1);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final fg     = widget.isDark ? Colors.white : Colors.black87;
    final fgDim  = widget.isDark ? Colors.white38 : Colors.black26;
    final accent = widget.isDark ? const Color(0xFF7B61FF) : const Color(0xFF5B4FCF);

    const itemH   = 44.0;
    const wheelH  = 220.0;

    Widget wheel({
      required FixedExtentScrollController ctrl,
      required int itemCount,
      required Widget Function(int) builder,
      required void Function(int) onChanged,
      double flex = 1,
    }) {
      return Flexible(
        flex: (flex * 10).round(),
        child: ListWheelScrollView.useDelegate(
          controller: ctrl,
          itemExtent: itemH,
          diameterRatio: 1.4,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (_, i) => Center(child: builder(i)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: fgDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Labels colonnes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(flex: 7, child: Center(child: Text('Juzz',    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
                Flexible(flex: 13, child: Center(child: Text('Sourate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
                Flexible(flex: 7, child: Center(child: Text('Verset',  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Roues
          SizedBox(
            height: wheelH,
            child: Stack(
              children: [
                // Ligne de sélection centrale
                Positioned(
                  top: (wheelH - itemH) / 2,
                  left: 16, right: 16,
                  child: Container(
                    height: itemH,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Juzz
                      wheel(
                        ctrl: _juzzCtrl,
                        itemCount: 30,
                        flex: 0.7,
                        onChanged: _onJuzzChanged,
                        builder: (i) => Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: i == _selJuzz - 1 ? 17 : 14,
                            fontWeight: i == _selJuzz - 1 ? FontWeight.w700 : FontWeight.w400,
                            color: i == _selJuzz - 1 ? fg : fgDim,
                          ),
                        ),
                      ),
                      // Séparateur
                      Container(width: 1, height: wheelH * 0.6, color: fgDim.withValues(alpha: 0.4)),
                      // Sourate
                      wheel(
                        ctrl: _surahCtrl,
                        itemCount: widget.surahList.length,
                        flex: 1.3,
                        onChanged: _onSurahChanged,
                        builder: (i) {
                          final s = widget.surahList[i];
                          final sel = i == _selSurahIdx;
                          return Text(
                            '${s['id']}. ${s['nameFr']}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: sel ? 15 : 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? fg : fgDim,
                            ),
                          );
                        },
                      ),
                      // Séparateur
                      Container(width: 1, height: wheelH * 0.6, color: fgDim.withValues(alpha: 0.4)),
                      // Verset
                      wheel(
                        ctrl: _ayahCtrl,
                        itemCount: _verseCount,
                        flex: 0.7,
                        onChanged: _onAyahChanged,
                        builder: (i) => Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: i == _selAyah - 1 ? 17 : 14,
                            fontWeight: i == _selAyah - 1 ? FontWeight.w700 : FontWeight.w400,
                            color: i == _selAyah - 1 ? fg : fgDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bouton Aller
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onConfirm(_currentSurahId, _selAyah),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Aller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
