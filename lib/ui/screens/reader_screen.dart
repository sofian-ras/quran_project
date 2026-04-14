import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_loader.dart';
import '../../services/quran_image_service.dart';
import '../../services/quran_pages_hitbox_db.dart';
import '../../services/mini_player_service.dart';
import '../widgets/ayah_selection_overlay.dart';
import '../widgets/ayah_bubble.dart';
import '../widgets/mini_player_widget.dart';
import '../../data/hizb_juzz.dart';
import '../../data/surah_name.dart';
import '../../data/sura_ayah_to_page.dart';
import '../../services/reading_history_service.dart';
import '../../services/last_reading_service.dart';
import '../../services/verse_notes_service.dart';
import '../widgets/quran_search_overlay.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'surah_list_screen.dart';

class ReaderScreen extends StatefulWidget {
  final int initialPage;
  final String reading;
  final bool openSearch;
  final String? initialHighlightKey;

  const ReaderScreen({
    super.key,
    this.initialPage = 1,
    this.reading = 'hafs',
    this.openSearch = false,
    this.initialHighlightKey,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int currentPage;
  String currentReading = 'hafs';
  int _readerTheme = 1; // 0=blanc, 1=papier, 2=sombre, 3=sépia, 4=minuit
  late PageController _pageController;

  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;
  late bool _isSearchOpen;
  String? _searchHighlightKey;
  bool _isThemePicker = false;
  bool _optionsExpanded = false;
  bool _showArabicSurahName = false;
  String? _selectedVerseKey;
  Timer? _saveTimer;
  Timer? _preloadDebounce;
  Timer? _uiTimer;

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

  final Map<int, File?> _imageCache = {};
  final Map<int, Future<File?>> _pageFutures = {};
  final int _preloadRange = 2;

  Future<File?> _safeGetPageFile(String reading, int pageNum) async {
    try {
      return await QuranImageService.instance.getPageFile(reading, pageNum);
    } catch (_) {
      return null;
    }
  }

  Future<File?> _getOrCreatePageFuture(int pageNum) =>
      _pageFutures.putIfAbsent(pageNum, () => _safeGetPageFile(currentReading, pageNum));

  Color get _themeBg {
    switch (_readerTheme) {
      case 0: return Colors.white;
      case 1: return const Color(0xFFF3E8C0);
      case 2: return const Color(0xFF0B1025);
      case 3: return const Color(0xFFEDD9A3);
      case 4: return const Color(0xFF0A1628);
      case 5: return const Color(0xFFE8F5E9); // vert clair
      case 6: return const Color(0xFFE8F0FB); // bleu clair
      default: return Colors.white;
    }
  }

  ColorFilter? get _themeFilter {
    switch (_readerTheme) {
      case 1: return const ColorFilter.matrix([
          0.9529, 0, 0, 0, 0,
          0, 0.9098, 0, 0, 0,
          0, 0, 0.7529, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 2: return const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
           0,-1, 0, 0, 255,
           0, 0,-1, 0, 255,
           0, 0, 0, 1,   0,
        ]);
      case 3: return const ColorFilter.matrix([
          0.85, 0, 0, 0, 0,
          0, 0.72, 0, 0, 0,
          0, 0, 0.50, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 4: return const ColorFilter.matrix([
          -1, 0, 0, 0, 200,
           0,-1, 0, 0, 220,
           0, 0,-1, 0, 255,
           0, 0, 0, 1,   0,
        ]);
      case 5: return const ColorFilter.matrix([  // vert clair
          0.91, 0, 0, 0, 0,
          0, 0.96, 0, 0, 0,
          0, 0, 0.91, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 6: return const ColorFilter.matrix([  // bleu clair
          0.91, 0, 0, 0, 0,
          0, 0.94, 0, 0, 0,
          0, 0, 0.97, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default: return null;
    }
  }

  Color get _themeIconColor =>
      (_readerTheme == 2 || _readerTheme == 4) ? Colors.white60 : Colors.black45;

  IconData get _themeIcon {
    switch (_readerTheme) {
      case 0: return Icons.light_mode_outlined;
      case 1: return Icons.brightness_medium_outlined;
      case 2: return Icons.dark_mode_outlined;
      case 3: return Icons.filter_vintage_outlined;
      case 4: return Icons.nights_stay_outlined;
      case 5: return Icons.eco_outlined;
      case 6: return Icons.water_drop_outlined;
      default: return Icons.brightness_medium_outlined;
    }
  }

  void _applySystemUiStyle(int theme) {
    SystemChrome.setSystemUIOverlayStyle(
      (theme == 2 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  Future<void> _loadReaderTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final theme = prefs.getInt('reader_theme') ?? 1;
    setState(() => _readerTheme = theme);
    _applySystemUiStyle(theme);
  }

  void _showThemePicker() {
    setState(() => _isThemePicker = !_isThemePicker);
  }

  void _resetOptionsTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _optionsExpanded = false);
    });
  }


  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    currentPage = widget.initialPage;
    currentReading = widget.reading;

    final startPage = (widget.initialPage < 1)
        ? 1
        : (widget.initialPage > 604 ? 604 : widget.initialPage);

    _pageController = PageController(initialPage: startPage - 1);
    _pageController.addListener(_onPageScroll);

    _isSearchOpen = widget.openSearch;
    _searchHighlightKey = widget.initialHighlightKey;

    _initApp();
    _loadReaderTheme();
    _loadNoteKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preloadPages(widget.initialPage);
    });
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
      final file = await QuranImageService.instance.getPageFile(currentReading, pageNum);
      _imageCache[pageNum] = file;
      if (mounted) await precacheImage(FileImage(file), context);
    } catch (e) {
      debugPrint('Erreur préchargement page $pageNum: $e');
    }
  }

  /// Downloads (if needed) and precaches [page] before jumping to it.
  Future<void> _navigateToPage(int page, [int? surah, int? ayah]) async {
    if (!mounted) return;
    File? file = QuranImageService.instance.getSyncCached(page);
    if (file == null) {
      try {
        file = await QuranImageService.instance.getPageFile(currentReading, page);
      } catch (_) {}
      file = QuranImageService.instance.getSyncCached(page);
    }
    if (file != null && mounted) {
      await precacheImage(FileImage(file), context);
    }
    if (!mounted) return;
    if (surah != null && ayah != null) {
      setState(() => _searchHighlightKey = '$surah:$ayah');
    }
    _pageController.jumpToPage(page - 1);
  }

  void _cleanDistantPages(int centerPage) {
    final pagesToRemove = <int>[];
    _imageCache.forEach((pageNum, _) {
      if ((pageNum - centerPage).abs() > _preloadRange + 1) {
        pagesToRemove.add(pageNum);
      }
    });

    for (final pageNum in pagesToRemove) {
      final file = _imageCache.remove(pageNum);
      if (file != null) {
        PaintingBinding.instance.imageCache.evict(FileImage(file));
      }
      _pageFutures.remove(pageNum);
    }
  }

  Future<void> _onPlayingAyahChanged() async {
    if (!mounted) return;
    final key = MiniPlayerService.instance.currentAyahKey.value;

    // Stop ou fin de lecture : efface le highlight et la sélection
    if (key == null) {
      final svc = MiniPlayerService.instance;
      if (!svc.isRangeAutoAdvancing.value) {
        setState(() {
          _selectedVerseKey  = null;
          _selectionStartKey = null;
          _selectionEndKey   = null;
        });
        svc.clearSelection();
      } else {
        setState(() {});
      }
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
    _saveToHistory(currentPage);
    _uiTimer?.cancel();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _imageCache.clear();

    // Restaure les icônes système par défaut à la sortie du reader
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      systemNavigationBarColor: Colors.transparent,
    ));

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);


    super.dispose();
  }

  Future<void> _initApp() async {
    final list = await loadSurahList();
    if (!mounted) return;
    setState(() => fullSurahList = list);
  }

  // ── Éditeur de note ───────────────────────────────────────────────────────

  void _showNoteEditor(int surah, int ayah) {
    final key = '$surah:$ayah';
    final isDark = _readerTheme == 2 || _readerTheme == 4;
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
          if (mounted) Navigator.pop(context);
          final page = await QuranPagesHitboxDb.instance
              .getPageForAyah(surah, ayah);
          if (page != null) await _navigateToPage(page);
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

    final surah = fullSurahList.lastWhere(
      (s) => (s['page'] as int) <= page,
      orElse: () => fullSurahList.first,
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

    final surahEntry = fullSurahList.isEmpty
        ? null
        : fullSurahList.lastWhere(
            (s) => (s['page'] as int) <= currentPage,
            orElse: () => fullSurahList.first,
          );
    final currentSurah = surahEntry?['id'] as int? ?? 1;
    final surahNameFr  = surahEntry?['nameFr'] as String? ?? '';

    return Scaffold(
      backgroundColor: _themeBg,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
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
                    _searchHighlightKey = null;
                  });
                  _preloadPages(p + 1);

                  _saveTimer?.cancel();
                  _saveTimer = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    _saveToHistory(p + 1);
                  });
                },
                itemBuilder: (context, i) {
                  final pageNum = i + 1;

                  final cached = _imageCache[pageNum]
                      ?? QuranImageService.instance.getSyncCached(pageNum);
                  if (cached != null) {
                    _imageCache[pageNum] = cached;
                    return _buildPageContent(cached, isLandscape, pageNum, viewPadding.bottom, viewPadding.top);
                  }

                  return FutureBuilder<File?>(
                    future: _getOrCreatePageFuture(pageNum),
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
                      return _buildPageContent(file, isLandscape, pageNum, viewPadding.bottom, viewPadding.top);
                    },
                  );
                },
              ),
            ),
          ),

            // ── TOP overlay — portrait ──────────────────────────────────────
            if (!isLandscape)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                top: _showUI ? (viewPadding.top + 26) : (viewPadding.top - 60),
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showUI ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Retour + Nom sourate — gauche
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Icon(Icons.arrow_back_ios_new, size: 20, color: _themeIconColor),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                surahNameFr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _themeIconColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Recherche — centré
                        GestureDetector(
                          onTap: () => setState(() => _isSearchOpen = true),
                          child: Opacity(
                            opacity: 0.65,
                            child: Icon(Icons.search_rounded, size: 26, color: _themeIconColor),
                          ),
                        ),
                        // Juzz / Hizb + Settings — droite
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_juzzText(currentPage)} ${_hizbText(currentPage)}',
                                style: TextStyle(fontSize: 14, color: _themeIconColor, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _optionsExpanded = !_optionsExpanded);
                                  if (_optionsExpanded) _resetOptionsTimer();
                                },
                                child: AnimatedRotation(
                                  turns: _optionsExpanded ? 0.25 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  child: Icon(Icons.settings_outlined, size: 22, color: _themeIconColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Dropdown settings — portrait ────────────────────────────────
            if (!isLandscape)
              Positioned(
                top: viewPadding.top + 52,
                right: 16,
                child: IgnorePointer(
                  ignoring: !(_showUI && _optionsExpanded),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: (_showUI && _optionsExpanded) ? 1.0 : 0.0,
                    child: AnimatedScale(
                      scale: _optionsExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _themeBg.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _themeIconColor.withValues(alpha: 0.15)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: _isThemePicker
                                ? _themeCirclesDropdown()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: _showThemePicker,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(_themeIcon, size: 20, color: _themeIconColor),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          _showNotesListModal();
                                          setState(() => _optionsExpanded = false);
                                          _uiTimer?.cancel();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            _noteKeys.isNotEmpty ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                                            size: 20,
                                            color: _noteKeys.isNotEmpty ? const Color(0xFFFF8F00) : _themeIconColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Nom sourate arabe SVG — UI cachée ──────────────────────────
            if (!isLandscape)
              Positioned(
                top: viewPadding.top + 26,
                left: 24,
                right: 24,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showArabicSurahName ? 1.0 : 0.0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/images/Translated_Quran/surah_svg/$currentSurah.svg',
                            height: 30,
                            colorFilter: ColorFilter.mode(_themeIconColor, BlendMode.srcIn),
                          ),
                          SvgPicture.asset(
                            'assets/images/Translated_Quran/surah_svg/0. surah.svg',
                            height: 30,
                            colorFilter: ColorFilter.mode(_themeIconColor, BlendMode.srcIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── TOP-LEFT back — landscape ───────────────────────────────────
            if (isLandscape)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                top: _showUI ? (viewPadding.top + 4) : (viewPadding.top - 60),
                left: 4,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showUI ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Opacity(
                      opacity: 0.6,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: _themeIconColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),


            // ── BOTTOM overlay — portrait ───────────────────────────────────
            if (!isLandscape)
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
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.85,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: MiniPlayerWidget(currentSurah: currentSurah),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── BOTTOM bar — landscape : [info pill] + [MiniPlayer] ─────────
            if (isLandscape)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                bottom: _showUI ? (viewPadding.bottom + 6) : (viewPadding.bottom - 80),
                left: viewPadding.left + 56, // laisse la place au bouton back
                right: viewPadding.right + 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showUI ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _bottomBarLandscapeInfo(surahNameFr),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: MiniPlayerWidget(currentSurah: currentSurah),
                        ),
                        const SizedBox(width: 8),
                        _landscapeThemeNotesPill(),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Search overlay ───────────────────────────────────────────────
            if (_isSearchOpen)
              Positioned.fill(
                child: QuranSearchOverlay(
                  pageController: _pageController,
                  onClose: () => setState(() {
                    _isSearchOpen = false;
                    _searchHighlightKey = null;
                  }),
                  onNavigateToPage: _navigateToPage,
                ),
              ),
          ],
        ),
    );
  }

  // ── Tap simple ────────────────────────────────────────────────────────────

  void _onAyahTap(int surah, int ayah, Rect? globalRect) {
    if (_searchHighlightKey != null) {
      setState(() => _searchHighlightKey = null);
    }
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
        if (!hadSelection) {
          _showUI = !_showUI;
          _showArabicSurahName = !_showUI;
        }
        _isThemePicker = false;
        _selectedVerseKey  = null;
        _selectionStartKey = null;
        _selectionEndKey   = null;
        MiniPlayerService.instance.clearSelection();
      });
      if (!hadSelection) {
        if (!_showUI) setState(() => _optionsExpanded = false);
      }
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
    return ColoredBox(
      color: _themeBg,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _themeIconColor,
          ),
        ),
      ),
    );
  }

  /// Pill theme + notes — affiché à droite du MiniPlayer en paysage.
  Widget _themeCirclesDropdown() {
    const circles = [
      (id: 0, left: Color(0xFFFFFFFF), right: Color(0xFFB8A898)),
      (id: 1, left: Color(0xFFF3E8C0), right: Color(0xFF9C7E4A)),
      (id: 3, left: Color(0xFFEDD9A3), right: Color(0xFF8B6340)),
      (id: 2, left: Color(0xFF0B1025), right: Color(0xFF7C9EBC)),
      (id: 4, left: Color(0xFF0A1628), right: Color(0xFF6B9EBC)),
      (id: 5, left: Color(0xFFE8F5E9), right: Color(0xFF4A7C59)),
      (id: 6, left: Color(0xFFE8F0FB), right: Color(0xFF3A6B9C)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in circles)
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('reader_theme', c.id);
              if (!mounted) return;
              setState(() { _readerTheme = c.id; _isThemePicker = false; });
              _applySystemUiStyle(c.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width:  _readerTheme == c.id ? 36 : 28,
                height: _readerTheme == c.id ? 36 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: _readerTheme == c.id
                      ? Border.all(color: _themeIconColor, width: 2)
                      : null,
                  boxShadow: _readerTheme == c.id
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)]
                      : null,
                ),
                child: CustomPaint(painter: _SplitCirclePainter(left: c.left, right: c.right)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _landscapeThemeNotesPill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _themeBg.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _themeIconColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: Icon(_themeIcon, size: 18, color: _themeIconColor),
                onPressed: _showThemePicker,
              ),
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: Icon(
                  _noteKeys.isNotEmpty ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                  size: 18,
                  color: _noteKeys.isNotEmpty ? const Color(0xFFFF8F00) : _themeIconColor,
                ),
                onPressed: _showNotesListModal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill info paysage : [sourate] | [page] — affiché à gauche du MiniPlayer.
  Widget _bottomBarLandscapeInfo(String surahNameFr) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _themeBg.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _themeIconColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                surahNameFr,
                style: TextStyle(color: _themeIconColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(width: 1, height: 14, color: _themeIconColor.withValues(alpha: 0.25),
                  margin: const EdgeInsets.symmetric(horizontal: 6)),
              Text(
                '$currentPage',
                style: TextStyle(color: _themeIconColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPageContent(File imageFile, bool isLandscape, int pageNum, double navBarHeight, double topBarHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Avec SystemUiMode.edgeToEdge, la fenêtre Flutter couvre toujours
        // la totalité de l'écran physique — les contraintes sont stables.
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
        const imagePxSize = Size(1024, 1657); // taille réelle PNG Hafs 1024px

        Widget wrapFilter(Widget child) => _themeFilter != null
            ? ColorFiltered(colorFilter: _themeFilter!, child: child)
            : child;

        if (isLandscape) {
          final screenW = displaySize.width;
          final imgH = screenW * (imagePxSize.height / imagePxSize.width);
          return SingleChildScrollView(
            child: Stack(
              children: [
                wrapFilter(Image.file(
                  imageFile,
                  width: screenW,
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.high,
                )),
                Positioned(
                  left: 0, top: 0,
                  width: screenW,
                  height: imgH,
                  child: AyahSelectionOverlay(
                    page: pageNum,
                    displaySize: Size(screenW, imgH),
                    imageSize: imagePxSize,
                    selectedVerseKey: _selectedVerseKey,
                    onAyahTap: _onAyahTap,
                    onAyahLongPress: _onAyahLongPress,
                    playingAyahKey:      MiniPlayerService.instance.currentAyahKey.value,
                    selectionStartKey:   _selectionStartKey,
                    selectionEndKey:     _selectionEndKey,
                    noteAyahKeys:        _noteKeys,
                    searchHighlightKey:  _searchHighlightKey,
                  ),
                ),
                // Numéro de page — bas droit (impaire) / bas gauche (paire)
                Positioned(
                  left:  pageNum.isEven ? 10 : null,
                  right: pageNum.isOdd  ? 10 : null,
                  top:   imgH - navBarHeight - 28,
                  child: IgnorePointer(
                    child: Text(
                      '$pageNum',
                      style: TextStyle(
                        color: _themeIconColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Reliure — gauche si page impaire (droite du livre), droite si paire (gauche du livre)
                Positioned(
                  left:   pageNum.isOdd  ? 0 : null,
                  right:  pageNum.isEven ? 0 : null,
                  top: 0, bottom: 0,
                  width: 6,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: pageNum.isOdd ? Alignment.centerRight : Alignment.centerLeft,
                          end:   pageNum.isOdd ? Alignment.centerLeft  : Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Portrait : calcul de la zone réelle de l'image basé sur les dims physiques
        // On réserve de l'espace pour l'entête et le mini-player (fix tablettes).
        const double kHeaderReserve = 72.0; // hauteur entête sous la barre d'état
        const double kPlayerReserve = 96.0; // hauteur mini-player au-dessus de la safe area
        final topInset = topBarHeight + kHeaderReserve;
        final botInset = navBarHeight + kPlayerReserve;
        final effectiveH = displaySize.height - topInset - botInset;

        final imgAspect = imagePxSize.width / imagePxSize.height;
        final dispAspect = displaySize.width / effectiveH;
        double imgW, imgH, offsetX, offsetY;
        const double kVerticalNudge = 20.0; // décale l'image vers le bas
        if (imgAspect > dispAspect) {
          imgW = displaySize.width;
          imgH = imgW / imgAspect;
          offsetX = 0;
          offsetY = topInset + (effectiveH - imgH) / 2 + kVerticalNudge;
        } else {
          imgH = effectiveH;
          imgW = imgH * imgAspect;
          offsetX = (displaySize.width - imgW) / 2;
          offsetY = topInset + kVerticalNudge;
        }

        // Pas de SizedBox fixe — le Stack remplit les contraintes disponibles.
        // L'image est positionnée avec les offsets calculés depuis displaySize
        // (taille max vue), donc sa position ne change jamais.
        return Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: imgW,
                height: imgH,
                child: wrapFilter(Image.file(
                  imageFile,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.fill,
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
                  playingAyahKey:      MiniPlayerService.instance.currentAyahKey.value,
                  selectionStartKey:   _selectionStartKey,
                  selectionEndKey:     _selectionEndKey,
                  noteAyahKeys:        _noteKeys,
                  searchHighlightKey:  _searchHighlightKey,
                ),
              ),
              // Numéro de page — coin bas droit (impaire) / bas gauche (paire)
              Positioned(
                left:  pageNum.isEven ? 10 : null,
                right: pageNum.isOdd  ? 10 : null,
                top:   displaySize.height - navBarHeight - 28,
                child: IgnorePointer(
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      color: _themeIconColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Reliure — gauche si page impaire (droite du livre), droite si paire (gauche du livre)
              Positioned(
                left:  pageNum.isOdd  ? 0 : null,
                right: pageNum.isEven ? 0 : null,
                top: offsetY,
                width: 6,
                height: imgH,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: pageNum.isOdd ? Alignment.centerRight : Alignment.centerLeft,
                        end:   pageNum.isOdd ? Alignment.centerLeft  : Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
        );
      },
    );
  }
}

// ── Sûrats madaniyya (révélées à Médine) ─────────────────────────────────────
const _kMadaniSurahs = {
  2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48, 49, 55,
  57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 76, 98, 110,
};

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

// ── Item types pour la liste mixte ───────────────────────────────────────────
sealed class _SheetItem {}

class _JuzItem extends _SheetItem {
  final int juzNum;
  final int startPage;
  _JuzItem(this.juzNum, this.startPage);
}

class _SurahItem extends _SheetItem {
  final Map<String, dynamic> data;
  _SurahItem(this.data);
}

// ── Feuille de sélection (Juzz + Sourates dans une seule liste) ───────────────
class _SurahSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> surahList;
  final int currentSurah;
  final int currentPage;
  final bool isDark;
  final String reading;
  final Future<void> Function(int surahId, BuildContext sheetContext) onSurahTap;
  final void Function(int page) onJuzTap;

  const _SurahSelectionSheet({
    required this.surahList,
    required this.currentSurah,
    required this.currentPage,
    required this.isDark,
    required this.reading,
    required this.onSurahTap,
    required this.onJuzTap,
  });

  @override
  State<_SurahSelectionSheet> createState() => _SurahSelectionSheetState();
}

class _SurahSelectionSheetState extends State<_SurahSelectionSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Liste complète avec en-têtes de Juz intercalés
  late final List<_SheetItem> _allItems;

  @override
  void initState() {
    super.initState();
    _allItems = _buildMixedList();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_SheetItem> _buildMixedList() {
    final items = <_SheetItem>[];
    int nextJuzIdx = 0;
    for (final surah in widget.surahList) {
      final surahPage = surah['page'] as int;
      // Insérer les en-têtes de Juz dont la page de début <= page de cette sourate
      while (nextJuzIdx < juzzMap.length &&
          juzzMap[nextJuzIdx]['start_page']! <= surahPage) {
        items.add(_JuzItem(
          juzzMap[nextJuzIdx]['juz']!,
          juzzMap[nextJuzIdx]['start_page']!,
        ));
        nextJuzIdx++;
      }
      items.add(_SurahItem(surah));
    }
    return items;
  }

  // Retourne la liste à afficher (filtrée ou complète)
  List<_SheetItem> get _visibleItems {
    if (_query.isEmpty) return _allItems;
    // En mode recherche : uniquement les sourates qui correspondent
    return _allItems.whereType<_SurahItem>().where((item) {
      final fr = (item.data['nameFr'] as String).toLowerCase();
      final id = item.data['id'].toString();
      return fr.contains(_query) || id.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final sheetBg = isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white38 : Colors.black38;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final infoColor = isDark ? Colors.white54 : Colors.black45;
    final searchFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade100;

    final accentColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6C35);
    final juzBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : accentColor.withValues(alpha: 0.07);
    final dividerColor = Colors.grey.withValues(alpha: 0.07);
    final visibleItems = _visibleItems;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Champ de recherche ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une sourate…',
                    hintStyle: TextStyle(color: subtleColor),
                    prefixIcon: Icon(Icons.search, color: subtleColor),
                    filled: true,
                    fillColor: searchFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // ── Liste unique ──────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];

                    // ── En-tête Juz ─────────────────────────────────────────
                    if (item is _JuzItem) {
                      return InkWell(
                        onTap: () => widget.onJuzTap(item.startPage),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 9),
                          color: juzBg,
                          child: Row(
                            children: [
                              Text(
                                'Juz ${item.juzNum}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Page ${item.startPage}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: accentColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // ── Ligne sourate ───────────────────────────────────────
                    final s = (item as _SurahItem).data;
                    final id = s['id'] as int;
                    final nameFr = s['nameFr'] as String;
                    final ayahsCount = _kSurahVerseCount[id.clamp(1, 114)];
                    final madani = _kMadaniSurahs.contains(id);
                    final firstPage = suraAyahToPage[id]?[1] ?? 1;

                    return _SurahSheetTile(
                      surahId: id,
                      currentSurah: widget.currentSurah,
                      isDark: isDark,
                      dividerColor: dividerColor,
                      highlightColor: highlightColor,
                      subtleColor: subtleColor,
                      textColor: textColor,
                      infoColor: infoColor,
                      nameFr: nameFr,
                      ayahsCount: ayahsCount ?? 0,
                      madani: madani,
                      firstPage: firstPage,
                      reading: widget.reading,
                      onTap: () => widget.onSurahTap(id, context),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Tile sourate dans la bottom sheet (avec animation de téléchargement)
// ─────────────────────────────────────────────────────────────────────────────

class _SurahSheetTile extends StatefulWidget {
  final int surahId;
  final int currentSurah;
  final bool isDark;
  final Color dividerColor;
  final Color highlightColor;
  final Color subtleColor;
  final Color textColor;
  final Color infoColor;
  final String nameFr;
  final int ayahsCount;
  final bool madani;
  final int firstPage;
  final String reading;
  final Future<void> Function() onTap;

  const _SurahSheetTile({
    required this.surahId,
    required this.currentSurah,
    required this.isDark,
    required this.dividerColor,
    required this.highlightColor,
    required this.subtleColor,
    required this.textColor,
    required this.infoColor,
    required this.nameFr,
    required this.ayahsCount,
    required this.madani,
    required this.firstPage,
    required this.reading,
    required this.onTap,
  });

  @override
  State<_SurahSheetTile> createState() => _SurahSheetTileState();
}

class _SurahSheetTileState extends State<_SurahSheetTile> {
  double _fillProgress = 0.0;
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    if (!mounted) return;
    // Guard immédiat — bloque tout double-tap avant le premier await
    setState(() => _loading = true);

    final bool isCached =
        QuranImageService.instance.getSyncCached(widget.firstPage) != null ||
        await QuranImageService.instance.isPageCached(widget.firstPage);

    if (!mounted) return;

    if (isCached) {
      setState(() => _fillProgress = 1.0);
      if (QuranImageService.instance.getSyncCached(widget.firstPage) == null) {
        await QuranImageService.instance.getPageFile(widget.reading, widget.firstPage);
      }
      final file = QuranImageService.instance.getSyncCached(widget.firstPage);
      if (file != null && mounted) {
        await precacheImage(FileImage(file), context);
      }
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 80));
      await widget.onTap();
      if (mounted) setState(() { _fillProgress = 0.0; _loading = false; });
      return;
    }

    setState(() => _fillProgress = 0.0);

    try {
      await QuranImageService.instance.getPageFile(
        widget.reading,
        widget.firstPage,
        onProgress: (p) {
          if (mounted) setState(() => _fillProgress = p);
        },
      );
    } catch (_) {}

    if (!mounted) return;

    final file = QuranImageService.instance.getSyncCached(widget.firstPage);
    if (file == null) {
      setState(() { _fillProgress = 0.0; _loading = false; });
      return;
    }

    setState(() { _fillProgress = 1.0; _loading = false; });
    await precacheImage(FileImage(file), context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    await widget.onTap();
    if (mounted) setState(() { _fillProgress = 0.0; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final isHighlighted = widget.surahId == widget.currentSurah;

    return ClipRect(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isHighlighted ? widget.highlightColor : null,
              border: Border(
                bottom: BorderSide(color: widget.dividerColor, width: 0.5),
              ),
            ),
            child: InkWell(
              onTap: _loading ? null : _handleTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${widget.surahId}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isHighlighted ? gold : widget.subtleColor,
                          fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.nameFr,
                        style: TextStyle(
                          fontSize: 15,
                          color: isHighlighted ? gold : widget.textColor,
                          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.ayahsCount}v · ${widget.madani ? 'Médinoise' : 'Mecquoise'}',
                      style: TextStyle(fontSize: 11, color: widget.infoColor),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_fillProgress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SheetFillPainter(
                    progress: _fillProgress,
                    color: gold.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),

          // Pourcentage affiché pendant le téléchargement de la page
          if (_loading && _fillProgress > 0 && _fillProgress < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '${(_fillProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetFillPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SheetFillPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    canvas.drawCircle(center, maxRadius * progress, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SheetFillPainter old) => old.progress != progress;
}

class _SplitCirclePainter extends CustomPainter {
  final Color left;
  final Color right;
  const _SplitCirclePainter({required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        math.pi / 2, math.pi, true, Paint()..color = left);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, math.pi, true, Paint()..color = right);
  }

  @override
  bool shouldRepaint(_SplitCirclePainter old) =>
      old.left != left || old.right != right;
}
