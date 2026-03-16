import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_service.dart';
import '../services/mini_player_service.dart';
import '../services/reading_history_service.dart';
import '../services/tafsir_service.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';
import 'tafsir_reader_screen.dart';
import 'widgets/mini_player_widget.dart';
import 'widgets/quran_search_overlay.dart';

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
  int _readerTheme = 1; // 0=blanc 1=sepia 2=dark
  final PageController _pageController = PageController();

  bool _showHud = true;
  bool _showSearch = false;

  // Position temps réel du PageView (0-indexed, double) pour sync HUD
  final ValueNotifier<double> _pagePos = ValueNotifier(0.0);

  // Lookup O(1) page → juzz/hizb (construit une fois en initState)
  late final Map<int, int> _pageJuzz;
  late final Map<int, int> _pageHizb;

  // ── Thème QCF ──────────────────────────────────────────────────────────────
  QcfThemeData get _qcfTheme {
    switch (_readerTheme) {
      case 0:
        return const QcfThemeData();
      case 2:
        return QcfThemeData.dark();
      default:
        return QcfThemeData.sepia();
    }
  }

  // Doit correspondre exactement au pageBackgroundColor du thème QCF
  // pour que les marges FittedBox soient invisibles pendant le swipe
  Color get _themeBg => _readerTheme == 2
      ? const Color(0xFF1E1E1E)   // = QcfThemeData.dark().pageBackgroundColor
      : (_readerTheme == 0
          ? Colors.white           // = QcfThemeData().pageBackgroundColor
          : const Color(0xFFF5E6D3)); // = QcfThemeData.sepia().pageBackgroundColor

  // Couleur des icônes/texte du HUD
  Color get _hudFg =>
      _readerTheme == 2 ? Colors.white70 : const Color(0xFF4A3F30);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage.clamp(1, 604);
    _pageJuzz = _buildLookup(juzzMap, 'juz');
    _pageHizb = _buildLookup(hizbMap, 'hizb');
    _loadTheme();
    AudioService.instance.suppressGlobalPlayer.value = true;
    MiniPlayerService.instance.currentAyahKey.addListener(_onAyahChanged);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pagePos.dispose();
    _pageController.dispose();
    AudioService.instance.suppressGlobalPlayer.value = false;
    MiniPlayerService.instance.currentAyahKey.removeListener(_onAyahChanged);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onPageScroll() {
    if (_pageController.hasClients) {
      _pagePos.value = _pageController.page ?? (currentPage - 1).toDouble();
    }
  }

  void _onAyahChanged() {
    final key = MiniPlayerService.instance.currentAyahKey.value;
    if (key == null || !mounted) return;
    final parts = key.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return;
    final page = getPageNumber(surah, ayah);
    if (page != currentPage && mounted) setState(() => currentPage = page);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _readerTheme = prefs.getInt('reader_theme') ?? 1);
  }

  Future<void> _cycleTheme() async {
    final next = (_readerTheme + 1) % 3;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_theme', next);
    if (!mounted) return;
    setState(() => _readerTheme = next);
  }

  void _saveHistory(int page) {
    final surahId = getPageData(page).first['surah'] as int;
    ReadingHistoryService.instance.saveLastReading(
      page: page,
      surahId: surahId,
      surahName: surahFr[surahId] ?? 'Sourate $surahId',
    );
  }

  // Construit un Map<page, valeur> depuis juzzMap/hizbMap (exécuté une seule fois)
  static Map<int, int> _buildLookup(List<Map<String, int>> src, String key) {
    final map = <int, int>{};
    for (int i = 0; i < src.length; i++) {
      final start = src[i]['start_page']!;
      final end = (i + 1 < src.length) ? src[i + 1]['start_page']! - 1 : 604;
      for (int p = start; p <= end; p++) {
        map[p] = src[i][key]!;
      }
    }
    return map;
  }

  String _hizbText(int page) {
    final v = _pageHizb[page];
    return v != null ? 'Hizb $v' : '';
  }

  String _juzzText(int page) {
    final v = _pageJuzz[page];
    return v != null ? 'Juzz $v' : '';
  }

  void _toggleHud() {
    if (_showSearch) {
      setState(() => _showSearch = false);
      return;
    }
    setState(() => _showHud = !_showHud);
  }

  void _openSearch() => setState(() {
        _showSearch = true;
        _showHud = true;
      });

  void _showVerseMenu(int surah, int verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseMenuSheet(
        surah: surah,
        verseStart: verse,
        isDark: _readerTheme == 2,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final surahId = getPageData(currentPage).first['surah'] as int;

    final mq = MediaQuery.of(context);

    // Compute FittedBox scale (height-constrained) and where QCF text starts.
    // QcfPage uses a ListView without explicit padding, so Flutter adds
    // mq.padding (top + bottom) automatically. Inside FittedBox the content is
    // scaled by safeH/screenH, so the text's y-position in SafeArea coords is:
    //   textTopInSafeArea = scale * mq.padding.top
    final safeH = mq.size.height - mq.padding.top - mq.padding.bottom;
    final fittedScale = safeH / mq.size.height;
    final textTopInSafeArea = fittedScale * mq.padding.top;

    return Scaffold(
      backgroundColor: _themeBg,
      body: Stack(
        children: [
          // ── Page (FittedBox préserve le ratio, fond identique = marges invisibles)
          Positioned.fill(
            child: SafeArea(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: mq.size.width,
                  height: mq.size.height,
                  child: MediaQuery(
                    data: mq,
                    child: PageviewQuran(
                      controller: _pageController,
                      initialPageNumber: currentPage,
                      theme: _qcfTheme,
                      sp: 1.sp,
                      h: 1.h,
                      onPageChanged: (page) {
                        if (!mounted) return;
                        setState(() => currentPage = page.clamp(1, 604));
                        _saveHistory(currentPage);
                      },
                      onTap: (surah, verse) => _toggleHud(),
                      onLongPress: (surah, verse) =>
                          _showVerseMenu(surah, verse),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── HUD haut — overlay, n'affecte pas la taille de la page ────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showHud,
              child: AnimatedOpacity(
                opacity: _showHud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: _topHud(surahId, textTopInSafeArea),
              ),
            ),
          ),

          // ── HUD bas — overlay, n'affecte pas la taille de la page ─────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showHud,
              child: AnimatedOpacity(
                opacity: _showHud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: _bottomHud(surahId),
              ),
            ),
          ),

          // ── Overlay de recherche ───────────────────────────────────────
          if (_showSearch)
            Positioned.fill(
              child: QuranSearchOverlay(
                pageController: _pageController,
                isDark: _readerTheme == 2,
                onClose: () => setState(() => _showSearch = false),
              ),
            ),
        ],
      ),
    );
  }

  // ── HUD haut ──────────────────────────────────────────────────────────────

  // Construit la rangée de contenu HUD pour une page donnée
  Widget _hudRow(int page) {
    final sid = getPageData(page).first['surah'] as int;
    final svgPath = 'assets/images/Translated_Quran/surah_svg/$sid.svg';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SvgPicture.asset(
              svgPath,
              height: 26,
              colorFilter: ColorFilter.mode(
                  _qcfTheme.verseNumberColor.withValues(alpha: 0.7),
                  BlendMode.srcIn),
              placeholderBuilder: (_) => Text(
                getSurahNameArabic(sid),
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 18,
                  color: _qcfTheme.verseNumberColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _openSearch,
          child: Icon(Icons.search_rounded,
              size: 20, color: _hudFg.withValues(alpha: 0.6)),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(_juzzText(page),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _qcfTheme.verseNumberColor.withValues(alpha: 0.7))),
              const SizedBox(width: 8),
              Text(_hizbText(page),
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          _qcfTheme.verseNumberColor.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topHud(int surahId, double textTopOffset) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, textTopOffset, 12, 8),
            child: AnimatedBuilder(
              animation: _pagePos,
              builder: (_, __) {
                final pos = _pagePos.value;
                final base = pos.floor();       // index 0-based de la page courante
                final frac = pos - base;        // 0.0 → 1.0 pendant le swipe

                // Deux pages simultanément, comme le PageView
                final pageA = (base + 1).clamp(1, 604); // page sortante
                final pageB = (base + 2).clamp(1, 604); // page entrante

                return Stack(
                  children: [
                    // Page sortante : glisse dans la direction du swipe
                    Transform.translate(
                      offset: Offset(frac * screenWidth, 0),
                      child: _hudRow(pageA),
                    ),
                    // Page entrante : arrive depuis la direction opposée
                    if (frac > 0.001)
                      Transform.translate(
                        offset: Offset((frac - 1) * screenWidth, 0),
                        child: _hudRow(pageB),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── HUD bas ───────────────────────────────────────────────────────────────
  Widget _bottomHud(int surahId) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini lecteur — visible uniquement si audio chargé
              ValueListenableBuilder<String?>(
                valueListenable:
                    MiniPlayerService.instance.currentAyahKey,
                builder: (_, key, __) {
                  if (key == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                    child: MiniPlayerWidget(currentSurah: surahId),
                  );
                },
              ),

              // Barre page : thème · N/604 · fermer
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Thème
                    GestureDetector(
                      onTap: _cycleTheme,
                      child: Icon(
                        _readerTheme == 0
                            ? Icons.light_mode_outlined
                            : _readerTheme == 1
                                ? Icons.brightness_medium_outlined
                                : Icons.dark_mode_outlined,
                        size: 18,
                        color: _hudFg.withValues(alpha: 0.55),
                      ),
                    ),

                    // Page — droite si impaire, gauche si paire
                    Expanded(
                      child: Align(
                        alignment: currentPage.isOdd
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          '$currentPage',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _hudFg.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _VerseMenuSheet
// ═══════════════════════════════════════════════════════════════════════════════

class _VerseMenuSheet extends StatefulWidget {
  final int surah;
  final int verseStart;
  final bool isDark;

  const _VerseMenuSheet({
    required this.surah,
    required this.verseStart,
    required this.isDark,
  });

  @override
  State<_VerseMenuSheet> createState() => _VerseMenuSheetState();
}

class _VerseMenuSheetState extends State<_VerseMenuSheet> {
  bool _sharingImage = false;
  final GlobalKey _verseImageKey = GlobalKey();

  String get _verseText =>
      getVerse(widget.surah, widget.verseStart, verseEndSymbol: true);

  String get _verseLabel {
    final sName = getSurahNameArabic(widget.surah);
    return '$sName — verset ${widget.verseStart}';
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _verseText));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Verset copié'),
          duration: Duration(seconds: 2)),
    );
  }

  void _shareText() {
    Share.share(_verseText, subject: _verseLabel);
    Navigator.pop(context);
  }

  Future<void> _shareImage() async {
    setState(() => _sharingImage = true);
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final boundary = _verseImageKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/verse_${widget.surah}_${widget.verseStart}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: _verseLabel);
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  void _openTafsir() {
    Navigator.pop(context);
    final book = TafsirService.catalog.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TafsirReaderScreen(
          book: book,
          initialSurah: widget.surah,
        ),
      ),
    );
  }

  void _playAudio() {
    MiniPlayerService.instance.playFrom(
      surah: widget.surah,
      ayah: widget.verseStart,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? const Color(0xFF1A2035)
        : const Color(0xFFFAF6EE);
    final textColor = widget.isDark
        ? const Color(0xFFE8D5B3)
        : const Color(0xFF4A3F30);
    final subColor = widget.isDark
        ? const Color(0xFF8B9BB4)
        : const Color(0xFF8B7355);
    final dividerColor =
        widget.isDark ? Colors.white12 : const Color(0xFFE0D5C5);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Label
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_verseLabel,
                  style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),

            // Prévisualisation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RepaintBoundary(
                key: _verseImageKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF0C1220)
                        : const Color(0xFFF5F0E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFC8A97E)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _verseText,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'UthmanTahaNaskh',
                      fontSize: 22,
                      height: 1.8,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),

            if (_sharingImage)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),

            const SizedBox(height: 8),
            Divider(color: dividerColor, height: 1),
            _ActionTile(icon: Icons.copy_rounded, label: 'Copier', color: textColor, onTap: _copyText),
            _ActionTile(icon: Icons.share_rounded, label: 'Partager le texte', color: textColor, onTap: _shareText),
            _ActionTile(icon: Icons.image_outlined, label: 'Partager en image', color: textColor, onTap: _sharingImage ? null : _shareImage),
            _ActionTile(icon: Icons.menu_book_rounded, label: 'Lire le Tafsir', color: textColor, onTap: _openTafsir),
            _ActionTile(icon: Icons.headphones_rounded, label: 'Écouter', color: textColor, onTap: _playAudio),
            Divider(color: dividerColor, height: 1),
            _ActionTile(
              icon: Icons.close_rounded,
              label: 'Fermer',
              color: subColor,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
