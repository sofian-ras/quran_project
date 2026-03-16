import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  // ── Sélection de verset ────────────────────────────────────────────────────
  int? _selSurah;
  int? _selVerseStart;
  int? _selVerseEnd; // null = sélection simple (1 verset)
  bool _isSelectingRange = false;

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

  Color get _themeIconColor =>
      _readerTheme == 2 ? Colors.white60 : Colors.black45;

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

  // ── Sélection ─────────────────────────────────────────────────────────────

  void _clearSelection() {
    setState(() {
      _selSurah = null;
      _selVerseStart = null;
      _selVerseEnd = null;
      _isSelectingRange = false;
    });
  }

  void _showVerseMenu(int surah, int verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseMenuSheet(
        surah: surah,
        verseStart: verse,
        verseEnd: _selVerseEnd,
        isDark: _readerTheme == 2,
        onDismiss: _clearSelection,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final surahId = getPageData(currentPage).first['surah'] as int;
    final surahNameFr = surahFr[surahId] ?? '';

    return Scaffold(
      backgroundColor: _themeBg,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Mushaf QCF ───────────────────────────────────────────────────
          Positioned.fill(
            child: PageviewQuran(
              initialPageNumber: currentPage,
              theme: _qcfTheme,
              sp: 1.sp,
              h: 1.h,
              verseBackgroundColor: (surah, verse) {
                if (_selSurah == null || surah != _selSurah) return null;
                final end = _selVerseEnd ?? _selVerseStart;
                if (end == null) return null;
                final from =
                    _selVerseStart! <= end ? _selVerseStart! : end;
                final to =
                    _selVerseStart! <= end ? end : _selVerseStart!;
                if (verse >= from && verse <= to) {
                  return Colors.amber.withValues(alpha: 0.35);
                }
                return null;
              },
              onPageChanged: (page) {
                if (!mounted) return;
                setState(() => currentPage = page.clamp(1, 604));
                _saveHistory(currentPage);
              },
              onTap: (surah, verse) {
                if (_isSelectingRange) {
                  // Deuxième tap = fin de plage
                  setState(() {
                    _selVerseEnd = verse;
                    _isSelectingRange = false;
                  });
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _showVerseMenu(surah, verse);
                  return;
                }
                // Tap simple : sélectionne et ouvre le menu
                setState(() {
                  _selSurah = surah;
                  _selVerseStart = verse;
                  _selVerseEnd = null;
                });
                _showVerseMenu(surah, verse);
              },
              onLongPress: (surah, verse) {
                // Long press = démarre une sélection de plage
                setState(() {
                  _selSurah = surah;
                  _selVerseStart = verse;
                  _selVerseEnd = null;
                  _isSelectingRange = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Tapez le verset de fin de sélection'),
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () {
                        _clearSelection();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                    ),
                    duration: const Duration(seconds: 10),
                  ),
                );
              },
            ),
          ),

          // ── Bandeau de sélection de plage ────────────────────────────────
          if (_isSelectingRange)
            Positioned(
              top: viewPadding.top + 8,
              left: 50,
              right: 50,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sélection de plage — tapez le verset de fin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Bouton retour ─────────────────────────────────────────────────
          Positioned(
            top: viewPadding.top + 10,
            left: 10,
            child: Opacity(
              opacity: 0.5,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    size: 20, color: _themeIconColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ── Sourate + Juzz/Hizb ──────────────────────────────────────────
          Positioned(
            top: viewPadding.top + 60,
            left: 30,
            child: Text(
              surahNameFr,
              style: TextStyle(
                fontSize: 12,
                color: _themeIconColor.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            top: viewPadding.top + 60,
            right: 30,
            child: Text(
              '${_juzzText(currentPage)} · ${_hizbText(currentPage)}',
              style: TextStyle(
                fontSize: 12,
                color: _themeIconColor.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ── Barre bas : MiniPlayer + contrôles ───────────────────────────
          Positioned(
            bottom: viewPadding.bottom + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayerWidget(currentSurah: surahId),
                const SizedBox(height: 6),
                _bottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: Icon(
                _readerTheme == 0
                    ? Icons.light_mode_outlined
                    : _readerTheme == 1
                        ? Icons.brightness_medium_outlined
                        : Icons.dark_mode_outlined,
                size: 20,
                color: _themeIconColor,
              ),
              onPressed: _cycleTheme,
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

// ═══════════════════════════════════════════════════════════════════════════════
// _VerseMenuSheet — Bottom sheet d'actions sur un verset / plage de versets
// ═══════════════════════════════════════════════════════════════════════════════

class _VerseMenuSheet extends StatefulWidget {
  final int surah;
  final int verseStart;
  final int? verseEnd;
  final bool isDark;
  final VoidCallback onDismiss;

  const _VerseMenuSheet({
    required this.surah,
    required this.verseStart,
    required this.isDark,
    required this.onDismiss,
    this.verseEnd,
  });

  @override
  State<_VerseMenuSheet> createState() => _VerseMenuSheetState();
}

class _VerseMenuSheetState extends State<_VerseMenuSheet> {
  bool _sharingImage = false;
  final GlobalKey _verseImageKey = GlobalKey();

  // ── Texte du verset / plage ───────────────────────────────────────────────

  String get _verseText {
    final end = widget.verseEnd ?? widget.verseStart;
    final from = widget.verseStart <= end ? widget.verseStart : end;
    final to = widget.verseStart <= end ? end : widget.verseStart;
    final buf = StringBuffer();
    for (int i = from; i <= to; i++) {
      if (i > from) buf.write(' ');
      buf.write(getVerse(widget.surah, i, verseEndSymbol: true));
    }
    return buf.toString();
  }

  String get _verseLabel {
    final sName = getSurahNameArabic(widget.surah);
    final end = widget.verseEnd;
    if (end == null || end == widget.verseStart) {
      return '$sName — verset ${widget.verseStart}';
    }
    return '$sName — versets ${widget.verseStart}–$end';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

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

    // Laisser le temps au widget de se construire
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
      final file = File('${dir.path}/verse_${widget.surah}_${widget.verseStart}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onDismiss();

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _verseLabel,
      );
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  void _openTafsir() {
    Navigator.pop(context);
    widget.onDismiss();
    final book = TafsirService.books.first;
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
    // Ne pas effacer la surbrillance — elle suit l'audio
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1A2035) : const Color(0xFFFAF6EE);
    final textColor = widget.isDark ? const Color(0xFFE8D5B3) : const Color(0xFF4A3F30);
    final subColor = widget.isDark ? const Color(0xFF8B9BB4) : const Color(0xFF8B7355);
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

            // Label verset
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                _verseLabel,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Prévisualisation du verset (Arabic) — aussi utilisé pour la capture image
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

            // Actions
            _ActionTile(
              icon: Icons.copy_rounded,
              label: 'Copier',
              color: textColor,
              isDark: widget.isDark,
              onTap: _copyText,
            ),
            _ActionTile(
              icon: Icons.share_rounded,
              label: 'Partager le texte',
              color: textColor,
              isDark: widget.isDark,
              onTap: _shareText,
            ),
            _ActionTile(
              icon: Icons.image_outlined,
              label: 'Partager en image',
              color: textColor,
              isDark: widget.isDark,
              onTap: _sharingImage ? null : _shareImage,
            ),
            _ActionTile(
              icon: Icons.menu_book_rounded,
              label: 'Lire le Tafsir',
              color: textColor,
              isDark: widget.isDark,
              onTap: _openTafsir,
            ),
            _ActionTile(
              icon: Icons.headphones_rounded,
              label: 'Écouter',
              color: textColor,
              isDark: widget.isDark,
              onTap: _playAudio,
            ),
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

// ── Tuile d'action ────────────────────────────────────────────────────────────

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
