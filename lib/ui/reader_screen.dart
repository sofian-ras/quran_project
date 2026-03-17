import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../data/sura_ayah_to_page.dart';
import '../data/surah_number_of_ayahs.dart';
import '../data/quran_clean_plain.dart';
import '../services/audio_service.dart';
import '../services/mini_player_service.dart';
import '../services/page_images_service.dart';
import '../services/reading_history_service.dart';
import '../services/tafsir_service.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';
import 'tafsir_reader_screen.dart';
import 'widgets/mini_player_widget.dart';

// ── Modèle léger pour la roulette ─────────────────────────────────────────────
class _SurahInfo {
  final int id;
  final String nameFr;
  final int pageStart;
  final int ayahCount;

  const _SurahInfo({
    required this.id,
    required this.nameFr,
    required this.pageStart,
    required this.ayahCount,
  });
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
  int _readerTheme = 1; // 0=blanc 1=sepia 2=dark
  late final QuranPageController _qcfController;
  List<_SurahInfo> _surahList = [];

  // ── Sélection de verset ────────────────────────────────────────────────────
  int? _selVerseEnd;
  bool _isSelectingRange = false;

  // ── Thème ──────────────────────────────────────────────────────────────────
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
    _qcfController = QuranPageController();
    _buildSurahList();
    _loadTheme();
    AudioService.instance.suppressGlobalPlayer.value = true;
    MiniPlayerService.instance.currentAyahKey.addListener(_onAyahChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentPage > 1 && mounted) {
        _qcfController.jumpToPage(currentPage);
      }
    });
  }

  @override
  void dispose() {
    AudioService.instance.suppressGlobalPlayer.value = false;
    MiniPlayerService.instance.currentAyahKey.removeListener(_onAyahChanged);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _buildSurahList() {
    final list = <_SurahInfo>[];
    for (int i = 1; i <= 114; i++) {
      final pageStart = suraAyahToPage[i]?[1] ?? 1;
      final ayahCount = suraNumberOfAyahs[i] ?? 7;
      list.add(_SurahInfo(
        id: i,
        nameFr: surahFr[i] ?? 'Sourate $i',
        pageStart: pageStart,
        ayahCount: ayahCount,
      ));
    }
    _surahList = list;
  }

  void _onAyahChanged() {
    final key = MiniPlayerService.instance.currentAyahKey.value;
    if (key == null || !mounted) return;
    final parts = key.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return;
    final page = suraAyahToPage[surah]?[ayah] ?? currentPage;
    if (page != currentPage && mounted) {
      setState(() => currentPage = page);
      _qcfController.jumpToPage(page);
    }
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
    final surah = _surahList.lastWhere(
      (s) => s.pageStart <= page,
      orElse: () => _surahList.last,
    );
    ReadingHistoryService.instance.saveLastReading(
      page: page,
      surahId: surah.id,
      surahName: surah.nameFr,
    );
  }

  void _navigateToPage(int page) {
    final p = page.clamp(1, 604);
    setState(() => currentPage = p);
    _qcfController.jumpToPage(p);
  }

  // ── Sélection ─────────────────────────────────────────────────────────────
  void _clearSelection() {
    setState(() {
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

  void _showNavigationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NavigationPicker(
        surahList: _surahList,
        currentPage: currentPage,
        isDark: _readerTheme == 2,
        onConfirm: (surahId, ayah) {
          Navigator.pop(context);
          final page = suraAyahToPage[surahId]?[ayah] ?? 1;
          _navigateToPage(page);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final currentSurah = _surahList.isEmpty
        ? 1
        : _surahList.lastWhere(
            (s) => s.pageStart <= currentPage,
            orElse: () => _surahList.first,
          ).id;

    final imagePath = PageImagesService.localPagesPath != null
        ? '${PageImagesService.localPagesPath}/'
        : 'assets/pages/';

    return Scaffold(
      backgroundColor: _themeBg,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Mushaf images ────────────────────────────────────────────────
          Positioned.fill(
            child: QuranPageView(
              controller: _qcfController,
              pageImagePath: imagePath,
              themeModeAdaption: false,
              quranTextColor: _readerTheme == 2
                  ? Colors.white
                  : (_readerTheme == 0 ? Colors.black : const Color(0xFF2C1810)),
              topBarTextColor: _readerTheme == 2
                  ? Colors.white70
                  : (_readerTheme == 0 ? Colors.black87 : const Color(0xFF2C1810)),
              showSearchIcon: false,
              showPageNumber: true,
              highlightColor: const Color(0x554FC3F7),
              showAyahMenu: false,
              customAyahActions: const [],
              onPageChanged: (page) {
                if (!mounted) return;
                setState(() => currentPage = page.clamp(1, 604));
                _saveHistory(currentPage);
              },
              onAyahTap: (surah, ayah, page) {
                if (_isSelectingRange) {
                  setState(() {
                    _selVerseEnd = ayah;
                    _isSelectingRange = false;
                  });
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _showVerseMenu(surah, ayah);
                  return;
                }
                setState(() {
                  _selVerseEnd = null;
                  currentPage = page;
                });
                _showVerseMenu(surah, ayah);
              },
              onAyahLongPress: (surah, ayah, page) {
                setState(() {
                  _selVerseEnd = null;
                  _isSelectingRange = true;
                  currentPage = page;
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

          // ── Bandeau sélection de plage ────────────────────────────────────
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

          // ── Nom sourate (tap → roulette navigation) ───────────────────────
          Positioned(
            top: viewPadding.top + 60,
            left: 30,
            child: GestureDetector(
              onTap: _qcfController.showSelectionSheet,
              child: Text(
                surahFr[currentSurah] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: _themeIconColor.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
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
                MiniPlayerWidget(currentSurah: currentSurah),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
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

// ═══════════════════════════════════════════════════════════════════════════════
// _VerseMenuSheet
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

  String _getVerseText(int surah, int ayah) {
    final v = quranCleanPlain.firstWhere(
      (e) => e['surah_number'] == surah && e['verse_number'] == ayah,
      orElse: () => {'content': ''},
    );
    return v['content'] as String? ?? '';
  }

  String _getSurahNameAr(int surah) {
    const names = [
      'الفاتحة','البقرة','آل عمران','النساء','المائدة','الأنعام','الأعراف','الأنفال','التوبة','يونس',
      'هود','يوسف','الرعد','إبراهيم','الحجر','النحل','الإسراء','الكهف','مريم','طه',
      'الأنبياء','الحج','المؤمنون','النور','الفرقان','الشعراء','النمل','القصص','العنكبوت','الروم',
      'لقمان','السجدة','الأحزاب','سبأ','فاطر','يس','الصافات','ص','الزمر','غافر',
      'فصلت','الشورى','الزخرف','الدخان','الجاثية','الأحقاف','محمد','الفتح','الحجرات','ق',
      'الذاريات','الطور','النجم','القمر','الرحمن','الواقعة','الحديد','المجادلة','الحشر','الممتحنة',
      'الصف','الجمعة','المنافقون','التغابن','الطلاق','التحريم','الملك','القلم','الحاقة','المعارج',
      'نوح','الجن','المزمل','المدثر','القيامة','الإنسان','المرسلات','النبأ','النازعات','عبس',
      'التكوير','الانفطار','المطففين','الانشقاق','البروج','الطارق','الأعلى','الغاشية','الفجر','البلد',
      'الشمس','الليل','الضحى','الشرح','التين','العلق','القدر','البينة','الزلزلة','العاديات',
      'القارعة','التكاثر','العصر','الهمزة','الفيل','قريش','الماعون','الكوثر','الكافرون','النصر',
      'المسد','الإخلاص','الفلق','الناس',
    ];
    if (surah < 1 || surah > 114) return '';
    return names[surah - 1];
  }

  String get _verseText {
    final end = widget.verseEnd ?? widget.verseStart;
    final from = widget.verseStart <= end ? widget.verseStart : end;
    final to = widget.verseStart <= end ? end : widget.verseStart;
    final buf = StringBuffer();
    for (int i = from; i <= to; i++) {
      if (i > from) buf.write(' ');
      buf.write(_getVerseText(widget.surah, i));
    }
    return buf.toString();
  }

  String get _verseLabel {
    final sName = _getSurahNameAr(widget.surah);
    final end = widget.verseEnd;
    if (end == null || end == widget.verseStart) {
      return '$sName — verset ${widget.verseStart}';
    }
    return '$sName — versets ${widget.verseStart}–$end';
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
                      color:
                          const Color(0xFFC8A97E).withValues(alpha: 0.5),
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

// ═══════════════════════════════════════════════════════════════════════════════
// _NavigationPicker — Roulette Juzz | Sourate | Verset
// ═══════════════════════════════════════════════════════════════════════════════

class _NavigationPicker extends StatefulWidget {
  final List<_SurahInfo> surahList;
  final int currentPage;
  final bool isDark;
  final void Function(int surahId, int ayah) onConfirm;

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

  int get _verseCount => widget.surahList[_selSurahIdx].ayahCount;

  int _juzzOfPage(int page) {
    for (int j = juzzMap.length - 1; j >= 0; j--) {
      if (juzzMap[j]['start_page']! <= page) return juzzMap[j]['juz']!;
    }
    return 1;
  }

  int _juzzOfSurah(int idx) =>
      _juzzOfPage(widget.surahList[idx].pageStart);

  @override
  void initState() {
    super.initState();
    _selSurahIdx = widget.surahList
        .lastIndexWhere((s) => s.pageStart <= widget.currentPage)
        .clamp(0, widget.surahList.length - 1);
    _selJuzz = _juzzOfSurah(_selSurahIdx);
    _selAyah = 1;

    _juzzCtrl = FixedExtentScrollController(initialItem: _selJuzz - 1);
    _surahCtrl = FixedExtentScrollController(initialItem: _selSurahIdx);
    _ayahCtrl = FixedExtentScrollController(initialItem: 0);
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
    final startPage = juzzMap[idx]['start_page']!;
    final surahEntry = widget.surahList.lastWhere(
      (s) => s.pageStart <= startPage,
      orElse: () => widget.surahList.first,
    );
    final surahIdx = widget.surahList
        .indexWhere((s) => s.id == surahEntry.id)
        .clamp(0, widget.surahList.length - 1);
    setState(() {
      _selJuzz = juzz;
      _selSurahIdx = surahIdx;
      _selAyah = 1;
    });
    _surahCtrl.jumpToItem(surahIdx);
    _ayahCtrl.jumpToItem(0);
    _syncing = false;
  }

  void _onSurahChanged(int idx) {
    if (_syncing) return;
    _syncing = true;
    final juzz = _juzzOfSurah(idx);
    setState(() {
      _selSurahIdx = idx;
      _selJuzz = juzz;
      _selAyah = 1;
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
    final bg = widget.isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final fg = widget.isDark ? Colors.white : Colors.black87;
    final fgDim = widget.isDark ? Colors.white38 : Colors.black26;
    final accent = widget.isDark
        ? const Color(0xFF7B61FF)
        : const Color(0xFF5B4FCF);

    const itemH = 44.0;
    const wheelH = 220.0;

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
            width: 36,
            height: 4,
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
                Flexible(
                    flex: 7,
                    child: Center(
                        child: Text('Juzz',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fgDim)))),
                Flexible(
                    flex: 13,
                    child: Center(
                        child: Text('Sourate',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fgDim)))),
                Flexible(
                    flex: 7,
                    child: Center(
                        child: Text('Verset',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fgDim)))),
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
                  left: 16,
                  right: 16,
                  child: Container(
                    height: itemH,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.25)),
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
                            fontWeight: i == _selJuzz - 1
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == _selJuzz - 1 ? fg : fgDim,
                          ),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: wheelH * 0.6,
                          color: fgDim.withValues(alpha: 0.4)),
                      wheel(
                        ctrl: _surahCtrl,
                        itemCount: widget.surahList.length,
                        flex: 1.3,
                        onChanged: _onSurahChanged,
                        builder: (i) {
                          final s = widget.surahList[i];
                          final sel = i == _selSurahIdx;
                          return Text(
                            '${s.id}. ${s.nameFr}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: sel ? 15 : 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: sel ? fg : fgDim,
                            ),
                          );
                        },
                      ),
                      Container(
                          width: 1,
                          height: wheelH * 0.6,
                          color: fgDim.withValues(alpha: 0.4)),
                      wheel(
                        ctrl: _ayahCtrl,
                        itemCount: _verseCount,
                        flex: 0.7,
                        onChanged: _onAyahChanged,
                        builder: (i) => Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: i == _selAyah - 1 ? 17 : 14,
                            fontWeight: i == _selAyah - 1
                                ? FontWeight.w700
                                : FontWeight.w400,
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
                onPressed: () => widget.onConfirm(
                  widget.surahList[_selSurahIdx].id,
                  _selAyah,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Aller',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
