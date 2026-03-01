import 'package:flutter/material.dart';
import '../services/tafsir_service.dart';
import '../services/quran_text_db.dart';
import '../surah_name.dart';

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
  int _currentAyah = 1;  // verset actuellement "actif" (nav prev/next)
  int _targetAyah  = 0;  // 0 = pas de cible ; > 0 = scroll après chargement
  List<TafsirVerse> _verses = [];
  Map<String, QVerse> _arabicVerses = {};
  bool _loading = true;
  String? _error;
  double _fontSize = 18;
  final ScrollController _scrollCtrl = ScrollController();

  // Clés GlobalKey pour chaque verset (permettent de scroller vers un ayah)
  final Map<int, GlobalKey> _verseKeys = {};

  int get _totalAyahs => TafsirService.surahAyahCounts[_currentSurah - 1];

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
      _verseKeys.clear();
    });

    try {
      final verses = await TafsirService.getSurah(widget.book, surah);

      Map<String, QVerse> arVerses = {};
      try {
        final db = QuranTextDb.instance;
        if (await db.isReady()) {
          final keys = verses.map((v) => v.verseKey).toList();
          arVerses = await db.getVersesByKeys(keys);
        }
      } catch (_) {}

      if (mounted) {
        final target = _targetAyah > 0 ? _targetAyah : 1;
        setState(() {
          _verses      = verses;
          _arabicVerses = arVerses;
          _loading     = false;
          _currentAyah = target.clamp(1, TafsirService.surahAyahCounts[surah - 1]);
        });

        // Scroll vers le haut d'abord
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }

        // Puis scroll vers l'ayah cible (si pas le premier)
        if (_targetAyah > 1) {
          _scrollToAyah(_targetAyah);
        } else {
          _targetAyah = 0;
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

  void _scrollToAyah(int ayah) {
    // Double frame : laisse le ListView construire ses items visibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Estimation grossière pour forcer le build des items lointains
        final approxOffset = (ayah - 1) * 320.0;
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(
            approxOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
          );
        }
        // Précision avec ensureVisible après le jump
        await Future.delayed(const Duration(milliseconds: 50));
        final key = _verseKeys[ayah];
        if (key?.currentContext != null && mounted) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
        _targetAyah = 0;
      });
    });
  }

  void _changeSurah(int surah, {int ayah = 1}) {
    _targetAyah = ayah;
    if (surah == _currentSurah) {
      // Même sourate déjà chargée : scroll direct
      setState(() => _currentAyah = ayah.clamp(1, _totalAyahs));
      if (ayah > 1) {
        _scrollToAyah(ayah);
      } else if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    setState(() => _currentSurah = surah);
    _loadSurah(surah);
  }

  void _prevVerse() {
    if (_currentAyah <= 1) return;
    final target = _currentAyah - 1;
    setState(() => _currentAyah = target);
    _scrollToAyah(target);
  }

  void _nextVerse() {
    if (_currentAyah >= _totalAyahs) return;
    final target = _currentAyah + 1;
    setState(() => _currentAyah = target);
    _scrollToAyah(target);
  }

  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SurahPickerSheet(
        currentSurah: _currentSurah,
        onSelect: (s, a) {
          Navigator.pop(ctx);
          _changeSurah(s, ayah: a);
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
    final surahFrName = surahFr[_currentSurah] ?? 'Sourate $_currentSurah';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _TopBar(
            book: widget.book,
            surahName: surahFrName,
            surahNumber: _currentSurah,
            dark: dark,
            fontSize: _fontSize,
            onBack: () => Navigator.pop(context),
            onSurahTap: _showSurahPicker,
            onFontIncrease: () =>
                setState(() => _fontSize = (_fontSize + 1.5).clamp(14, 28)),
            onFontDecrease: () =>
                setState(() => _fontSize = (_fontSize - 1.5).clamp(14, 28)),
          ),
          Expanded(
            child: _loading
                ? _LoadingView(bg: _bg)
                : _error != null
                    ? _ErrorView(
                        message: _error!,
                        onRetry: () => _loadSurah(_currentSurah))
                    : _verses.isEmpty
                        ? const _EmptyView()
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
                            verseKeys: _verseKeys,
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentSurah: _currentSurah,
        currentAyah: _currentAyah,
        totalAyahs: _totalAyahs,
        dark: dark,
        bg: _cardBg,
        onPrev:     _loading || _currentAyah <= 1           ? null : _prevVerse,
        onNext:     _loading || _currentAyah >= _totalAyahs  ? null : _nextVerse,
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
  final String surahName;   // Nom français
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
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: dark ? Colors.white70 : const Color(0xFF1A1A1A)),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onSurahTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    surahName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
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
                          size: 14,
                          color: dark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
  final Map<int, GlobalKey> verseKeys;

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
    required this.verseKeys,
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
        // Crée ou réutilise la GlobalKey pour cet ayah
        final vKey =
            verseKeys.putIfAbsent(v.ayah, () => GlobalKey());
        return _VerseBlock(
          key: vKey,
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
    super.key,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge verset (numéros occidentaux, en français)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(dark ? 60 : 25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withAlpha(dark ? 100 : 60),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Verset ${verse.ayah}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dark
                          ? Colors.white70
                          : accentColor.withAlpha(220),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Texte arabe du verset (si disponible) ─────────────────────────
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

          // ── Texte du tafsir ────────────────────────────────────────────────
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
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom navigation
// ══════════════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final int currentSurah;
  final int currentAyah;
  final int totalAyahs;
  final bool dark;
  final Color bg;
  final VoidCallback? onPrev;   // verset précédent
  final VoidCallback? onNext;   // verset suivant
  final VoidCallback onPicker;

  const _BottomNav({
    required this.currentSurah,
    required this.currentAyah,
    required this.totalAyahs,
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
    final frName = surahFr[currentSurah] ?? 'Sourate $currentSurah';

    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, bottom + 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color:
                dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Suivant → à GAUCHE (lecture arabe RTL : avancer = aller à gauche)
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            label: 'Suivant',
            enabled: onNext != null,
            onTap: onNext,
            textColor: textColor,
            reverse: true,
          ),

          // Bouton central : ouvre le picker sourate + verset
          GestureDetector(
            onTap: onPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        frName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Verset $currentAyah / $totalAyahs',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_less_rounded,
                      size: 16, color: textColor.withAlpha(160)),
                ],
              ),
            ),
          ),

          // Précédent → à DROITE (lecture arabe RTL : reculer = aller à droite)
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            label: 'Précédent',
            enabled: onPrev != null,
            onTap: onPrev,
            textColor: textColor,
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
              ? [
                  Text(label, style: TextStyle(fontSize: 12, color: color)),
                  const SizedBox(width: 2),
                  Icon(icon, size: 22, color: color)
                ]
              : [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 2),
                  Text(label, style: TextStyle(fontSize: 12, color: color))
                ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Picker sourate + verset (deux étapes)
// ══════════════════════════════════════════════════════════════════════════════

class _SurahPickerSheet extends StatefulWidget {
  final int currentSurah;
  final void Function(int surah, int ayah) onSelect;

  const _SurahPickerSheet({
    required this.currentSurah,
    required this.onSelect,
  });

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  // null = étape 1 (liste sourates) ; non-null = étape 2 (liste versets)
  int? _selectedSurah;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF1A1A1A);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
            const SizedBox(height: 4),

            // ── En-tête ────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (_selectedSurah != null)
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: textColor),
                      onPressed: () =>
                          setState(() => _selectedSurah = null),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      _selectedSurah == null
                          ? 'Choisir une sourate'
                          : 'Choisir un verset — ${surahFr[_selectedSurah!] ?? 'Sourate $_selectedSurah'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                color: dark ? Colors.white12 : Colors.black12, height: 1),

            // ── Contenu ────────────────────────────────────────────────────
            Expanded(
              child: _selectedSurah == null
                  ? _SurahList(
                      scrollCtrl: scrollCtrl,
                      currentSurah: widget.currentSurah,
                      dark: dark,
                      textColor: textColor,
                      onSurahTap: (s) =>
                          setState(() => _selectedSurah = s),
                    )
                  : _VerseGrid(
                      surah: _selectedSurah!,
                      scrollCtrl: scrollCtrl,
                      dark: dark,
                      textColor: textColor,
                      onVerseTap: (a) =>
                          widget.onSelect(_selectedSurah!, a),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Liste des sourates ────────────────────────────────────────────────────────

class _SurahList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final int currentSurah;
  final bool dark;
  final Color textColor;
  final void Function(int) onSurahTap;

  const _SurahList({
    required this.scrollCtrl,
    required this.currentSurah,
    required this.dark,
    required this.textColor,
    required this.onSurahTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: 114,
      itemBuilder: (ctx, i) {
        final surah = i + 1;
        final selected = surah == currentSurah;
        final frName = surahFr[surah] ?? 'Sourate $surah';
        final arName = TafsirService.surahNames[i];
        final verseCount = TafsirService.surahAyahCounts[i];

        return InkWell(
          onTap: () => onSurahTap(surah),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            color: selected
                ? (dark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(6))
                : null,
            child: Row(
              children: [
                // Badge numéro
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0xFF1A5C42)
                            .withAlpha(dark ? 160 : 60)
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
                          ? (dark
                              ? Colors.white
                              : const Color(0xFF1A5C42))
                          : textColor.withAlpha(160),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Noms (français principal + arabe secondaire)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? textColor : textColor.withAlpha(200),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$verseCount versets · ',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withAlpha(100),
                            ),
                          ),
                          Text(
                            arName,
                            style: TextStyle(
                              fontFamily: 'ScheherazadeNew',
                              fontSize: 13,
                              color: textColor.withAlpha(100),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Flèche
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: textColor.withAlpha(80)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Grille des versets ────────────────────────────────────────────────────────

class _VerseGrid extends StatelessWidget {
  final int surah;
  final ScrollController scrollCtrl;
  final bool dark;
  final Color textColor;
  final void Function(int) onVerseTap;

  const _VerseGrid({
    required this.surah,
    required this.scrollCtrl,
    required this.dark,
    required this.textColor,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = TafsirService.surahAyahCounts[surah - 1];
    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) {
        final ayah = i + 1;
        return InkWell(
          onTap: () => onVerseTap(ayah),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: dark ? Colors.white12 : Colors.black12,
                width: 0.8,
              ),
            ),
            child: Text(
              '$ayah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withAlpha(200),
              ),
            ),
          ),
        );
      },
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
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
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
