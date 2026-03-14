import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';

import '../services/quran_pages_hitbox_db.dart';
import '../services/mini_player_service.dart';
import 'widgets/mini_player_widget.dart';
import 'widgets/ayah_bubble.dart';
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
  final String reading; // conservé pour la compatibilité API, plus utilisé pour le rendu

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
  int _readerTheme = 1; // 0=blanc, 1=papier, 2=sombre

  late QuranPageController _qcfController;

  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;
  Timer? _saveTimer;
  Offset? _lastTouchPosition;

  // ── Notes ─────────────────────────────────────────────────────────────────
  Set<String> _noteKeys = {};

  Future<void> _loadNoteKeys() async {
    final all = await VerseNotesService.instance.getAll();
    if (!mounted) return;
    setState(() => _noteKeys = all.keys.toSet());
  }

  Color get _themeBg => _readerTheme == 2
      ? const Color(0xFF0B1025)
      : (_readerTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));

  Color get _themeIconColor => _readerTheme == 2 ? Colors.white60 : Colors.black45;

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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    currentPage = widget.initialPage;

    final startPage = (widget.initialPage < 1)
        ? 1
        : (widget.initialPage > 604 ? 604 : widget.initialPage);

    _qcfController = QuranPageController();

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

    // Saute à la page initiale après la construction du widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (startPage > 1 && mounted) {
        _qcfController.jumpToPage(startPage);
      }
    });
  }

  @override
  void dispose() {
    MiniPlayerService.instance.currentAyahKey.removeListener(_onPlayingAyahChanged);
    _saveTimer?.cancel();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<void> _onPlayingAyahChanged() async {
    if (!mounted) return;
    final key = MiniPlayerService.instance.currentAyahKey.value;

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
      _qcfController.jumpToPage(page);
    }
    setState(() {});
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
          if (mounted) Navigator.pop(context);
          final page = await QuranPagesHitboxDb.instance.getPageForAyah(surah, ayah);
          if (page != null && mounted) {
            _qcfController.jumpToPage(page);
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
          if (page != null && mounted) _qcfController.jumpToPage(page);
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
      reading: widget.reading,
    );

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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Lecteur QCF ───────────────────────────────────────────────────
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _lastTouchPosition = e.position,
              child: QuranPageView(
                controller: _qcfController,
                themeModeAdaption: true,
                showSearchIcon: false,
                showPageNumber: true,
                highlightColor: const Color(0x554FC3F7),
                showAyahMenu: false,
                customAyahActions: const [],
                onAyahTap: (surah, ayah, page) {
                  setState(() {
                    currentPage = page;
                    _showUI = true;
                  });
                  _saveTimer?.cancel();
                  _saveTimer = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    _saveToHistory(page);
                  });
                  final touch = _lastTouchPosition ??
                      Offset(
                        MediaQuery.of(context).size.width / 2,
                        MediaQuery.of(context).size.height / 2,
                      );
                  final anchor = Rect.fromCenter(
                    center: touch,
                    width: 120,
                    height: 32,
                  );
                  AyahBubble.show(
                    context,
                    surah: surah,
                    ayah: ayah,
                    anchorGlobalRect: anchor,
                    onDismiss: () {},
                    onNote: () => _showNoteEditor(surah, ayah),
                    hasNote: _noteKeys.contains('$surah:$ayah'),
                  );
                },
              ),
            ),
          ),

          // ── French surah name below package top bar — portrait ───────────
          if (!isLandscape)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: _showUI ? (viewPadding.top + 60) : (viewPadding.top - 40),
              left: 30,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: Text(
                    surahNameFr,
                    style: TextStyle(
                      fontSize: 12,
                      color: _themeIconColor.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // ── French juzz/hizb below package top bar — portrait ────────────
          if (!isLandscape)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: _showUI ? (viewPadding.top + 60) : (viewPadding.top - 40),
              right: 30,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: Text(
                    '${_juzzText(currentPage)} · ${_hizbText(currentPage)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _themeIconColor.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // ── TOP overlay — portrait ────────────────────────────────────────
          if (!isLandscape)
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: 0.5,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: _themeIconColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── TOP-LEFT back — landscape ─────────────────────────────────────
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

          // ── Cover package's Arabic page-number bar — portrait ────────────
          if (!isLandscape)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(color: _themeBg),
            ),

          // ── BOTTOM overlay — portrait ─────────────────────────────────────
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiniPlayerWidget(currentSurah: currentSurah),
                      const SizedBox(height: 6),
                      _bottomBarPortrait(surahNameFr),
                    ],
                  ),
                ),
              ),
            ),

          // ── BOTTOM bar — landscape ────────────────────────────────────────
          if (isLandscape)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              bottom: _showUI ? (viewPadding.bottom + 6) : (viewPadding.bottom - 80),
              left: viewPadding.left + 56,
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
        ],
      ),
    );
  }

  /// Pill theme + notes — paysage droite.
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
                icon: Icon(
                  _readerTheme == 0 ? Icons.light_mode_outlined
                      : _readerTheme == 1 ? Icons.brightness_medium_outlined
                      : Icons.dark_mode_outlined,
                  size: 18, color: _themeIconColor,
                ),
                onPressed: _cycleReaderTheme,
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

  /// Pill info paysage gauche.
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
              TextButton.icon(
                onPressed: _showNavigationPicker,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                icon: Icon(Icons.menu_book, color: _themeIconColor, size: 15),
                label: Text(
                  surahNameFr,
                  style: TextStyle(color: _themeIconColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
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

  Widget _bottomBarPortrait(String surahNameFr) {
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _readerTheme == 0 ? Icons.light_mode_outlined
                        : _readerTheme == 1 ? Icons.brightness_medium_outlined
                        : Icons.dark_mode_outlined,
                    size: 20, color: _themeIconColor,
                  ),
                  onPressed: _cycleReaderTheme,
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _noteKeys.isNotEmpty ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                    size: 20,
                    color: _noteKeys.isNotEmpty ? const Color(0xFFFF8F00) : _themeIconColor,
                  ),
                  onPressed: _showNotesListModal,
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.search, size: 20, color: _themeIconColor),
                  onPressed: _qcfController.showSearch,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '$currentPage',
                style: TextStyle(
                  color: _themeIconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Nombre de versets par sourate ─────────────────────────────────────────────
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

const _kJuzzStart = [
  [1,   1], [2, 142], [2, 253], [3,  92], [4,  24],
  [4, 148], [5,  82], [6, 111], [7,  87], [8,  41],
  [9,  93], [11,  6], [12, 53], [15,   1], [17,  1],
  [18, 75], [21,   1], [23,   1], [25,  21], [27, 56],
  [29, 46], [33,  31], [36,  28], [39,  32], [41, 47],
  [46,  1], [51,  31], [58,   1], [67,   1], [78,   1],
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
                              final surah = int.tryParse(parts[0]) ?? 0;
                              final ayah  = int.tryParse(parts[1]) ?? 0;
                              final name  = surahFr[surah] ?? 'Sourate $surah';
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
                                  margin: const EdgeInsets.symmetric(vertical: 5),
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
                                ),
                              );
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

  @override
  void initState() {
    super.initState();
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
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: fgDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(flex: 7,  child: Center(child: Text('Juzz',    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
                Flexible(flex: 13, child: Center(child: Text('Sourate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
                Flexible(flex: 7,  child: Center(child: Text('Verset',  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgDim)))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: wheelH,
            child: Stack(
              children: [
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
                      Container(width: 1, height: wheelH * 0.6, color: fgDim.withValues(alpha: 0.4)),
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
                      Container(width: 1, height: wheelH * 0.6, color: fgDim.withValues(alpha: 0.4)),
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
