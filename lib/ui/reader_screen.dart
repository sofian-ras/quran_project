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

  // ── HUD visibilité ─────────────────────────────────────────────────────────
  bool _showHud = true;

  // ── Thème QCF ──────────────────────────────────────────────────────────────
  QcfThemeData get _qcfTheme {
    switch (_readerTheme) {
      case 0:
        return QcfThemeData();
      case 2:
        return QcfThemeData.dark();
      default:
        return QcfThemeData.sepia();
    }
  }

  Color get _themeBg => _readerTheme == 2
      ? const Color(0xFF0B1025)
      : (_readerTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));

  Color get _hudBg => _readerTheme == 2
      ? const Color(0xFF0B1025)
      : (_readerTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));

  Color get _hudFg =>
      _readerTheme == 2 ? Colors.white70 : const Color(0xFF4A3F30);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage.clamp(1, 604);
    _loadTheme();
    AudioService.instance.suppressGlobalPlayer.value = true;
    MiniPlayerService.instance.currentAyahKey.addListener(_onAyahChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    AudioService.instance.suppressGlobalPlayer.value = false;
    MiniPlayerService.instance.currentAyahKey.removeListener(_onAyahChanged);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
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

  void _toggleHud() => setState(() => _showHud = !_showHud);

  void _showVerseMenu(int surah, int verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseMenuSheet(
        surah: surah,
        verseStart: verse,
        isDark: _readerTheme == 2,
        onDismiss: () {},
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final surahId = getPageData(currentPage).first['surah'] as int;

    return Scaffold(
      backgroundColor: _themeBg,
      body: Stack(
        children: [
          // ── Mushaf plein écran ─────────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (ctx, constraints) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
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
                  onTap: (surah, verse) {
                    // Tap simple = bascule HUD
                    _toggleHud();
                  },
                  onLongPress: (surah, verse) {
                    // Long press = menu verset
                    _showVerseMenu(surah, verse);
                  },
                ),
              ),
            ),
          ),

          // ── HUD haut ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showHud,
              child: AnimatedOpacity(
                opacity: _showHud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: _topHud(surahId),
              ),
            ),
          ),

          // ── HUD bas ───────────────────────────────────────────────────
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
        ],
      ),
    );
  }

  // ── HUD haut ──────────────────────────────────────────────────────────────
  Widget _topHud(int surahId) {
    final svgPath = 'assets/images/Translated_Quran/surah_svg/$surahId.svg';
    final translitFr = surahFr[surahId] ?? 'Sourate $surahId';
    final gradStart = _hudBg.withValues(alpha: 0.92);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradStart, _hudBg.withValues(alpha: 0.0)],
          stops: const [0.55, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Nom sourate (gauche) ────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    svgPath,
                    height: 30,
                    colorFilter: ColorFilter.mode(_hudFg, BlendMode.srcIn),
                    placeholderBuilder: (_) => Text(
                      getSurahNameArabic(surahId),
                      style: TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 18,
                        color: _hudFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    translitFr,
                    style: TextStyle(
                      fontSize: 10,
                      color: _hudFg.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),

              // ── Recherche (centre) ──────────────────────────────────
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: search overlay
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hudFg.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _hudFg.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Juzz / Hizb (droite) ────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _juzzText(currentPage),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _hudFg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hizbText(currentPage),
                    style: TextStyle(
                      fontSize: 10,
                      color: _hudFg.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HUD bas ───────────────────────────────────────────────────────────────
  Widget _bottomHud(int surahId) {
    final gradEnd = _hudBg.withValues(alpha: 0.92);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hudBg.withValues(alpha: 0.0), gradEnd],
          stops: const [0.0, 0.5],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini lecteur flottant (pas pleine largeur)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: MiniPlayerWidget(currentSurah: surahId),
              ),

              const SizedBox(height: 6),

              // Numéro de page + thème
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: _hudFg.withValues(alpha: 0.6),
                      ),
                    ),

                    // Page N / 604
                    Text(
                      '$currentPage / 604',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _hudFg.withValues(alpha: 0.55),
                      ),
                    ),

                    // Fermer / retour
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _hudFg.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _VerseMenuSheet — Bottom sheet d'actions sur un verset
// ═══════════════════════════════════════════════════════════════════════════════

class _VerseMenuSheet extends StatefulWidget {
  final int surah;
  final int verseStart;
  final bool isDark;
  final VoidCallback onDismiss;

  const _VerseMenuSheet({
    required this.surah,
    required this.verseStart,
    required this.isDark,
    required this.onDismiss,
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
    widget.onDismiss();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verset copié'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText() {
    Share.share(_verseText, subject: _verseLabel);
    Navigator.pop(context);
    widget.onDismiss();
  }

  Future<void> _shareImage() async {
    setState(() => _sharingImage = true);
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final boundary = _verseImageKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/verse_${widget.surah}_${widget.verseStart}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDismiss();
      await Share.shareXFiles([XFile(file.path)], subject: _verseLabel);
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  void _openTafsir() {
    Navigator.pop(context);
    widget.onDismiss();
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
    final bg = widget.isDark ? const Color(0xFF1A2035) : const Color(0xFFFAF6EE);
    final textColor =
        widget.isDark ? const Color(0xFFE8D5B3) : const Color(0xFF4A3F30);
    final subColor =
        widget.isDark ? const Color(0xFF8B9BB4) : const Color(0xFF8B7355);
    final dividerColor =
        widget.isDark ? Colors.white12 : const Color(0xFFE0D5C5);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                _verseLabel,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
                      color: const Color(0xFFC8A97E).withValues(alpha: 0.5),
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
            _ActionTile(icon: Icons.copy_rounded, label: 'Copier', color: textColor, isDark: widget.isDark, onTap: _copyText),
            _ActionTile(icon: Icons.share_rounded, label: 'Partager le texte', color: textColor, isDark: widget.isDark, onTap: _shareText),
            _ActionTile(icon: Icons.image_outlined, label: 'Partager en image', color: textColor, isDark: widget.isDark, onTap: _sharingImage ? null : _shareImage),
            _ActionTile(icon: Icons.menu_book_rounded, label: 'Lire le Tafsir', color: textColor, isDark: widget.isDark, onTap: _openTafsir),
            _ActionTile(icon: Icons.headphones_rounded, label: 'Écouter', color: textColor, isDark: widget.isDark, onTap: _playAudio),
            Divider(color: dividerColor, height: 1),
            _ActionTile(
              icon: Icons.close_rounded,
              label: 'Fermer',
              color: subColor,
              isDark: widget.isDark,
              onTap: () {
                Navigator.pop(context);
                widget.onDismiss();
              },
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
  final bool isDark;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
