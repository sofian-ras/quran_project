import 'package:flutter/material.dart';
import '../services/tafsir_service.dart';
import '../services/quran_text_db.dart';

class TafsirReaderScreen extends StatefulWidget {
  final TafsirBook book;
  final int initialSurah;

  const TafsirReaderScreen({
    super.key,
    required this.book,
    this.initialSurah = 1,
  });

  @override
  State<TafsirReaderScreen> createState() => _TafsirReaderScreenState();
}

class _TafsirReaderScreenState extends State<TafsirReaderScreen> {
  late int _currentSurah;
  List<TafsirVerse> _verses = [];
  Map<String, QVerse> _arabicVerses = {};
  bool _loading = true;
  String? _error;
  double _fontSize = 18;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentSurah = widget.initialSurah;
    _loadSurah(_currentSurah);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurah(int surah) async {
    setState(() {
      _loading = true;
      _error = null;
      _verses = [];
      _arabicVerses = {};
    });

    try {
      final verses = await TafsirService.getSurah(widget.book, surah);

      // Try to load Arabic verse text from the local DB
      Map<String, QVerse> arVerses = {};
      try {
        final db = QuranTextDb.instance;
        if (await db.isReady()) {
          final keys = verses.map((v) => v.verseKey).toList();
          arVerses = await db.getVersesByKeys(keys);
        }
      } catch (_) {
        // Arabic text optional — tafsir alone is still meaningful
      }

      if (mounted) {
        setState(() {
          _verses = verses;
          _arabicVerses = arVerses;
          _loading = false;
        });
        // Scroll to top on surah change
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur de chargement : $e';
        });
      }
    }
  }

  void _changeSurah(int surah) {
    if (surah == _currentSurah) return;
    setState(() => _currentSurah = surah);
    _loadSurah(surah);
  }

  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SurahPickerSheet(
        currentSurah: _currentSurah,
        onSelect: (s) {
          Navigator.pop(ctx);
          _changeSurah(s);
        },
      ),
    );
  }

  // ── Colors ─────────────────────────────────────────────────────────────────

  Color get _bg {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF0A0F1A) : const Color(0xFFF9F4EC);
  }

  Color get _cardBg {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF111827) : Colors.white;
  }

  Color get _textPrimary {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A);
  }

  Color get _textSecondary {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF8A9BB0) : const Color(0xFF6B6B6B);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surahName = TafsirService.surahNames[_currentSurah - 1];

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Top bar ────────────────────────────────────────────────────────
          _TopBar(
            book: widget.book,
            surahName: surahName,
            surahNumber: _currentSurah,
            dark: dark,
            fontSize: _fontSize,
            onBack: () => Navigator.pop(context),
            onSurahTap: _showSurahPicker,
            onFontIncrease: () => setState(() => _fontSize = (_fontSize + 1.5).clamp(14, 28)),
            onFontDecrease: () => setState(() => _fontSize = (_fontSize - 1.5).clamp(14, 28)),
          ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? _LoadingView(bg: _bg)
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: () => _loadSurah(_currentSurah))
                    : _verses.isEmpty
                        ? _EmptyView()
                        : _VersesList(
                            verses: _verses,
                            arabicVerses: _arabicVerses,
                            scrollCtrl: _scrollCtrl,
                            fontSize: _fontSize,
                            cardBg: _cardBg,
                            textPrimary: _textPrimary,
                            textSecondary: _textSecondary,
                            dark: dark,
                            bookGradient: widget.book.gradient,
                          ),
          ),
        ],
      ),

      // ── Bottom nav ──────────────────────────────────────────────────────────
      bottomNavigationBar: _BottomNav(
        currentSurah: _currentSurah,
        dark: dark,
        bg: _cardBg,
        onPrev: _currentSurah > 1 ? () => _changeSurah(_currentSurah - 1) : null,
        onNext: _currentSurah < 114 ? () => _changeSurah(_currentSurah + 1) : null,
        onPicker: _showSurahPicker,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Top bar
// ══════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final TafsirBook book;
  final String surahName;
  final int surahNumber;
  final bool dark;
  final double fontSize;
  final VoidCallback onBack;
  final VoidCallback onSurahTap;
  final VoidCallback onFontIncrease;
  final VoidCallback onFontDecrease;

  const _TopBar({
    required this.book,
    required this.surahName,
    required this.surahNumber,
    required this.dark,
    required this.fontSize,
    required this.onBack,
    required this.onSurahTap,
    required this.onFontIncrease,
    required this.onFontDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 8, 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0A0F1A) : const Color(0xFFF9F4EC),
        border: Border(
          bottom: BorderSide(
            color: dark
                ? Colors.white.withAlpha(15)
                : const Color(0xFF1A1A1A).withAlpha(15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: dark ? Colors.white70 : const Color(0xFF1A1A1A)),
            onPressed: onBack,
          ),

          // Surah selector (centre)
          Expanded(
            child: GestureDetector(
              onTap: onSurahTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    surahName,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sourate $surahNumber',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.expand_more_rounded,
                          size: 14, color: dark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Font size controls
          IconButton(
            icon: Icon(Icons.text_decrease_rounded,
                size: 18, color: dark ? Colors.white54 : Colors.black45),
            onPressed: onFontDecrease,
          ),
          IconButton(
            icon: Icon(Icons.text_increase_rounded,
                size: 18, color: dark ? Colors.white54 : Colors.black45),
            onPressed: onFontIncrease,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Verses list
// ══════════════════════════════════════════════════════════════════════════════

class _VersesList extends StatelessWidget {
  final List<TafsirVerse> verses;
  final Map<String, QVerse> arabicVerses;
  final ScrollController scrollCtrl;
  final double fontSize;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final List<Color> bookGradient;

  const _VersesList({
    required this.verses,
    required this.arabicVerses,
    required this.scrollCtrl,
    required this.fontSize,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.bookGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: verses.length,
      itemBuilder: (context, i) {
        final v = verses[i];
        final ar = arabicVerses[v.verseKey];
        return _VerseBlock(
          verse: v,
          arabicVerse: ar,
          fontSize: fontSize,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          accentColor: bookGradient.first,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Single verse block
// ══════════════════════════════════════════════════════════════════════════════

class _VerseBlock extends StatelessWidget {
  final TafsirVerse verse;
  final QVerse? arabicVerse;
  final double fontSize;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final Color accentColor;

  const _VerseBlock({
    required this.verse,
    required this.arabicVerse,
    required this.fontSize,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withAlpha(60)
                : Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Ayah header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Ayah number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(dark ? 60 : 25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withAlpha(dark ? 100 : 60),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '﴿ ${_toArabicNumerals(verse.ayah)} ﴾',
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 13,
                      color: dark
                          ? Colors.white70
                          : accentColor.withAlpha(220),
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),

          // ── Arabic verse (if available) ────────────────────────────────────
          if (arabicVerse?.ar != null && arabicVerse!.ar.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                arabicVerse!.ar,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'UthmanTahaNaskh',
                  fontSize: fontSize + 4,
                  color: textPrimary,
                  height: 2.0,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Thin ornamental divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accentColor.withAlpha(dark ? 80 : 60),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ] else ...[
            const SizedBox(height: 8),
          ],

          // ── Tafsir text ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Text(
              verse.text,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: fontSize,
                color: textPrimary.withAlpha(dark ? 220 : 210),
                height: 1.9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _toArabicNumerals(int n) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? ar[d] : c;
    }).join();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom navigation
// ══════════════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final int currentSurah;
  final bool dark;
  final Color bg;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPicker;

  const _BottomNav({
    required this.currentSurah,
    required this.dark,
    required this.bg,
    required this.onPrev,
    required this.onNext,
    required this.onPicker,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final textColor = dark ? Colors.white70 : const Color(0xFF1A1A1A);

    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, bottom + 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color: dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            label: 'Précédente',
            enabled: onPrev != null,
            onTap: onPrev,
            textColor: textColor,
          ),

          // Surah picker button
          GestureDetector(
            onTap: onPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                TafsirService.surahNames[currentSurah - 1],
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),

          // Next
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            label: 'Suivante',
            enabled: onNext != null,
            onTap: onNext,
            textColor: textColor,
            reverse: true,
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final Color textColor;
  final bool reverse;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.textColor,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? textColor : textColor.withAlpha(60);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reverse
              ? [Text(label, style: TextStyle(fontSize: 12, color: color)),
                 const SizedBox(width: 2),
                 Icon(icon, size: 22, color: color)]
              : [Icon(icon, size: 22, color: color),
                 const SizedBox(width: 2),
                 Text(label, style: TextStyle(fontSize: 12, color: color))],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Surah picker bottom sheet
// ══════════════════════════════════════════════════════════════════════════════

class _SurahPickerSheet extends StatelessWidget {
  final int currentSurah;
  final void Function(int) onSelect;

  const _SurahPickerSheet({
    required this.currentSurah,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF1A1A1A);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choisir une sourate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: dark ? Colors.white12 : Colors.black12, height: 1),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: 114,
                itemBuilder: (ctx, i) {
                  final surah = i + 1;
                  final selected = surah == currentSurah;
                  return InkWell(
                    onTap: () => onSelect(surah),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      color: selected
                          ? (dark
                              ? Colors.white.withAlpha(15)
                              : Colors.black.withAlpha(6))
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Number
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? const Color(0xFF1A5C42).withAlpha(dark ? 120 : 40)
                                  : Colors.transparent,
                              border: Border.all(
                                color: dark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Text(
                              '$surah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? (dark ? Colors.white : const Color(0xFF1A5C42))
                                    : textColor.withAlpha(160),
                              ),
                            ),
                          ),
                          // Surah name (Arabic, RTL)
                          Text(
                            TafsirService.surahNames[i],
                            style: TextStyle(
                              fontFamily: 'ScheherazadeNew',
                              fontSize: 20,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? textColor : textColor.withAlpha(200),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// State widgets
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  final Color bg;
  const _LoadingView({required this.bg});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1A5C42),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement…',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black38,
              ),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Aucune donnée disponible',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white38
                : Colors.black38,
          ),
        ),
      );
}
