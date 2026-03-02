import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
        accentColor: widget.book.gradient.first,
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
    return dark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
  }

  Color get _textPrimary {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
  }

  Color get _textSecondary {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF8A9BB0) : const Color(0xFF6B6B6B);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark    = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.of(context).padding;
    final screen  = MediaQuery.of(context).size;
    // fond_tafsir.webp : 1035×1631 — banderole courbée, bas max Y=181
    const double imgH        = 1631.0;
    const double bannerHImg  =  181.0;
    final bannerH = screen.height * (bannerHImg / imgH);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Fond image plein écran ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/tafsir/fond_tafsir.webp',
              fit: BoxFit.fill,
            ),
          ),

          // ── Contenu ────────────────────────────────────────────────────────
          Positioned(
            top: bannerH, left: 0, right: 0, bottom: 0,
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
                            surah: _currentSurah,
                            textPrimary: _textPrimary,
                            textSecondary: _textSecondary,
                            dark: dark,
                            bookGradient: widget.book.gradient,
                            bookNameAr: widget.book.nameAr,
                            verseKeys: _verseKeys,
                          ),
          ),

          // ── Barre de navigation (back + taille police) ─────────────────────
          Positioned(
            top: padding.top, left: 0, right: 0,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _GoldIconBtn(
                    icon: Icons.text_decrease_rounded,
                    onTap: () => setState(
                        () => _fontSize = (_fontSize - 1.5).clamp(14, 28)),
                  ),
                  _GoldIconBtn(
                    icon: Icons.text_increase_rounded,
                    onTap: () => setState(
                        () => _fontSize = (_fontSize + 1.5).clamp(14, 28)),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentSurah: _currentSurah,
        currentAyah: _currentAyah,
        totalAyahs: _totalAyahs,
        dark: dark,
        accentColor: widget.book.gradient.first,
        onPrev:     _loading || _currentAyah <= 1           ? null : _prevVerse,
        onNext:     _loading || _currentAyah >= _totalAyahs  ? null : _nextVerse,
        onPicker: _showSurahPicker,
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
  final int surah;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final List<Color> bookGradient;
  final String bookNameAr;
  final Map<int, GlobalKey> verseKeys;

  const _VersesList({
    required this.verses,
    required this.arabicVerses,
    required this.scrollCtrl,
    required this.fontSize,
    required this.surah,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.bookGradient,
    required this.bookNameAr,
    required this.verseKeys,
  });

  @override
  Widget build(BuildContext context) {
    final accent = bookGradient.first;
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      itemCount: verses.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _SurahHeader(
            surah: surah,
            accentColor: accent,
            dark: dark,
            textPrimary: textPrimary,
          );
        }
        final v = verses[i - 1];
        final ar = arabicVerses[v.verseKey];
        final vKey = verseKeys.putIfAbsent(v.ayah, () => GlobalKey());
        return _VerseBlock(
          key: vKey,
          verse: v,
          arabicVerse: ar,
          fontSize: fontSize,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          accentColor: accent,
          bookNameAr: bookNameAr,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Single verse block — open book style (no card border)
// ══════════════════════════════════════════════════════════════════════════════

class _VerseBlock extends StatelessWidget {
  final TafsirVerse verse;
  final QVerse?     arabicVerse;
  final double      fontSize;
  final Color       textPrimary;
  final Color       textSecondary;
  final bool        dark;
  final Color       accentColor;
  final String      bookNameAr;

  const _VerseBlock({
    super.key,
    required this.verse,
    required this.arabicVerse,
    required this.fontSize,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.accentColor,
    required this.bookNameAr,
  });

  @override
  Widget build(BuildContext context) {
    final hasArabic = arabicVerse?.ar != null && arabicVerse!.ar.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Indicateur verset ornemental ──────────────────────────────────
          _VerseIndicatorBox(
            surah:      verse.surah,
            ayah:       verse.ayah,
            accentColor: accentColor,
            dark:        dark,
          ),
          const SizedBox(height: 22),

          // ── Texte arabe du verset avec guillemets ─────────────────────────
          if (hasArabic) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                children: [
                  // Guillemets décoratifs
                  Positioned(
                    top: 0, right: 4,
                    child: Text('«',
                        style: TextStyle(
                          fontFamily: 'UthmanTahaNaskh',
                          fontSize: fontSize + 14,
                          color: accentColor.withAlpha(dark ? 120 : 90),
                          height: 1,
                        )),
                  ),
                  Positioned(
                    bottom: 0, left: 4,
                    child: Text('»',
                        style: TextStyle(
                          fontFamily: 'UthmanTahaNaskh',
                          fontSize: fontSize + 14,
                          color: accentColor.withAlpha(dark ? 120 : 90),
                          height: 1,
                        )),
                  ),
                  // Texte arabe
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 8),
                    child: Text(
                      arabicVerse!.ar,
                      textAlign:     TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily:   'UthmanTahaNaskh',
                        fontSize:     fontSize + 7,
                        color:        textPrimary,
                        height:       2.2,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color:      accentColor.withAlpha(dark ? 80 : 45),
                            blurRadius: 14,
                            offset:     Offset.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Boutons d'action ────────────────────────────────────────────
            _ActionButtons(
              arabicText: arabicVerse!.ar,
              tafsirText: verse.text,
              bookNameAr: bookNameAr,
              verseKey:   verse.verseKey,
              accentColor: accentColor,
              dark:        dark,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 8),
          ],

          // ── En-tête section tafsir ────────────────────────────────────────
          _TafsirSectionTitle(
            bookNameAr:  bookNameAr,
            accentColor: accentColor,
            dark:        dark,
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 12),

          // ── Texte du tafsir ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              verse.text,
              textAlign:     TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize:   fontSize,
                color:      textPrimary.withAlpha(dark ? 215 : 200),
                height:     2.1,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Surah header at the top of the verses list
// ══════════════════════════════════════════════════════════════════════════════

class _SurahHeader extends StatelessWidget {
  final int surah;
  final Color accentColor;
  final bool dark;
  final Color textPrimary;

  const _SurahHeader({
    required this.surah,
    required this.accentColor,
    required this.dark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final arName   = TafsirService.surahNames[surah - 1];
    final frName   = surahFr[surah] ?? 'Sourate $surah';
    final count    = TafsirService.surahAyahCounts[surah - 1];
    final lineColor = accentColor.withAlpha(dark ? 100 : 70);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          // Nom arabe
          Text(
            arName,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'UthmanTahaNaskh',
              fontSize: 38,
              color: textPrimary,
              shadows: [
                Shadow(
                  color: accentColor.withAlpha(dark ? 110 : 60),
                  blurRadius: 20,
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Nom français en petites capitales
          Text(
            frName.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: textPrimary.withAlpha(160),
              letterSpacing: 3.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count versets',
            style: TextStyle(
              fontSize: 11,
              color: accentColor.withAlpha(dark ? 160 : 130),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          // Ligne décorative
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, lineColor],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: accentColor.withAlpha(dark ? 180 : 140),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lineColor, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
  final Color accentColor;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPicker;

  const _BottomNav({
    required this.currentSurah,
    required this.currentAyah,
    required this.totalAyahs,
    required this.dark,
    required this.accentColor,
    required this.onPrev,
    required this.onNext,
    required this.onPicker,
  });

  @override
  Widget build(BuildContext context) {
    final bottom    = MediaQuery.of(context).padding.bottom;
    final bg        = dark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    final textColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
    final frName    = surahFr[currentSurah] ?? 'Sourate $currentSurah';
    final arName    = TafsirService.surahNames[currentSurah - 1];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ornamental top separator ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        accentColor.withAlpha(dark ? 60 : 45),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 8,
                      color: accentColor.withAlpha(dark ? 120 : 90),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accentColor.withAlpha(dark ? 60 : 45),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Navigation row ──────────────────────────────────────────────
          Row(
            children: [
              // Suivant (gauche, RTL → avance dans la lecture)
              _CircleNavBtn(
                icon: Icons.chevron_left_rounded,
                enabled: onNext != null,
                accentColor: accentColor,
                textColor: textColor,
                dark: dark,
                onTap: onNext,
              ),
              const SizedBox(width: 12),

              // Picker central
              Expanded(
                child: GestureDetector(
                  onTap: onPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(dark ? 22 : 14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withAlpha(dark ? 55 : 38),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          arName,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'UthmanTahaNaskh',
                            fontSize: 22,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          frName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w300,
                            color: textColor.withAlpha(140),
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Verset $currentAyah / $totalAyahs',
                              style: TextStyle(
                                fontSize: 10,
                                color: accentColor
                                    .withAlpha(dark ? 180 : 150),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_less_rounded,
                              size: 12,
                              color: accentColor
                                  .withAlpha(dark ? 140 : 110),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Précédent (droite, RTL → recule dans la lecture)
              _CircleNavBtn(
                icon: Icons.chevron_right_rounded,
                enabled: onPrev != null,
                accentColor: accentColor,
                textColor: textColor,
                dark: dark,
                onTap: onPrev,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleNavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final Color textColor;
  final bool dark;
  final VoidCallback? onTap;

  const _CircleNavBtn({
    required this.icon,
    required this.enabled,
    required this.accentColor,
    required this.textColor,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? accentColor.withAlpha(dark ? 35 : 20)
              : Colors.transparent,
          border: Border.all(
            color: enabled
                ? accentColor.withAlpha(dark ? 70 : 50)
                : textColor.withAlpha(25),
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: enabled ? textColor : textColor.withAlpha(35),
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
  final Color accentColor;
  final void Function(int surah, int ayah) onSelect;

  const _SurahPickerSheet({
    required this.currentSurah,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  // null = étape 1 (sourates) ; non-null = étape 2 (versets)
  int? _selectedSurah;

  @override
  Widget build(BuildContext context) {
    final dark      = Theme.of(context).brightness == Brightness.dark;
    final bg        = dark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    final textColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
    final accent    = widget.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(55),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Handle ornemental ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('✦',
                      style: TextStyle(
                          fontSize: 7,
                          color: accent.withAlpha(dark ? 130 : 95))),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(dark ? 110 : 75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('✦',
                      style: TextStyle(
                          fontSize: 7,
                          color: accent.withAlpha(dark ? 130 : 95))),
                ],
              ),
            ),

            // ── Breadcrumb étapes ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  _StepChip(
                    label: 'Sourate',
                    number: '1',
                    active: _selectedSurah == null,
                    done: _selectedSurah != null,
                    accent: accent,
                    dark: dark,
                    textColor: textColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: _selectedSurah != null
                          ? accent.withAlpha(dark ? 180 : 150)
                          : textColor.withAlpha(50),
                    ),
                  ),
                  _StepChip(
                    label: 'Verset',
                    number: '2',
                    active: _selectedSurah != null,
                    done: false,
                    accent: accent,
                    dark: dark,
                    textColor: textColor,
                  ),
                  if (_selectedSurah != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _selectedSurah = null),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 12,
                              color: accent.withAlpha(dark ? 180 : 150)),
                          const SizedBox(width: 3),
                          Text(
                            'Retour',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent.withAlpha(dark ? 180 : 150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Séparateur ornemental ─────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    accent.withAlpha(dark ? 70 : 50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Contenu ───────────────────────────────────────────────────
            Expanded(
              child: _selectedSurah == null
                  ? _SurahList(
                      scrollCtrl: scrollCtrl,
                      currentSurah: widget.currentSurah,
                      dark: dark,
                      textColor: textColor,
                      accentColor: accent,
                      onSurahTap: (s) => setState(() => _selectedSurah = s),
                    )
                  : _VerseGrid(
                      surah: _selectedSurah!,
                      scrollCtrl: scrollCtrl,
                      dark: dark,
                      textColor: textColor,
                      accentColor: accent,
                      onVerseTap: (a) => widget.onSelect(_selectedSurah!, a),
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
  final Color accentColor;
  final void Function(int) onSurahTap;

  const _SurahList({
    required this.scrollCtrl,
    required this.currentSurah,
    required this.dark,
    required this.textColor,
    required this.accentColor,
    required this.onSurahTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: 114,
      itemBuilder: (ctx, i) {
        final surah    = i + 1;
        final selected = surah == currentSurah;
        final frName   = surahFr[surah] ?? 'Sourate $surah';
        final arName   = TafsirService.surahNames[i];
        final count    = TafsirService.surahAyahCounts[i];

        return InkWell(
          onTap: () => onSurahTap(surah),
          splashColor: accentColor.withAlpha(20),
          highlightColor: accentColor.withAlpha(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected
                      ? accentColor.withAlpha(dark ? 200 : 180)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                // Badge numéro avec gradient si sélectionné
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              accentColor.withAlpha(dark ? 180 : 160),
                              accentColor.withAlpha(dark ? 120 : 100),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selected
                        ? null
                        : accentColor.withAlpha(dark ? 20 : 12),
                    border: Border.all(
                      color: selected
                          ? accentColor.withAlpha(dark ? 200 : 180)
                          : accentColor.withAlpha(dark ? 50 : 35),
                      width: selected ? 0 : 1,
                    ),
                  ),
                  child: Text(
                    '$surah',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : textColor.withAlpha(160),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nom français + nombre de versets
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? textColor : textColor.withAlpha(210),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count versets',
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor.withAlpha(dark ? 140 : 110),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Nom arabe (naturel RTL, à droite)
                Text(
                  arName,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanTahaNaskh',
                    fontSize: 19,
                    color: selected
                        ? accentColor.withAlpha(dark ? 220 : 200)
                        : textColor.withAlpha(120),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: selected
                      ? accentColor.withAlpha(dark ? 180 : 160)
                      : textColor.withAlpha(60),
                ),
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
  final Color accentColor;
  final void Function(int) onVerseTap;

  const _VerseGrid({
    required this.surah,
    required this.scrollCtrl,
    required this.dark,
    required this.textColor,
    required this.accentColor,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    final count  = TafsirService.surahAyahCounts[surah - 1];
    final arName = TafsirService.surahNames[surah - 1];
    final frName = surahFr[surah] ?? 'Sourate $surah';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini en-tête sourate
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  frName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                arName,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'UthmanTahaNaskh',
                  fontSize: 19,
                  color: accentColor.withAlpha(dark ? 200 : 170),
                ),
              ),
            ],
          ),
        ),

        // Grille des versets
        Expanded(
          child: GridView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: count,
            itemBuilder: (ctx, i) {
              final ayah = i + 1;
              return InkWell(
                onTap: () => onVerseTap(ayah),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withAlpha(dark ? 50 : 30),
                        accentColor.withAlpha(dark ? 28 : 14),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: accentColor.withAlpha(dark ? 80 : 55),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$ayah',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withAlpha(210),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step chip (breadcrumb du picker)
// ══════════════════════════════════════════════════════════════════════════════

class _StepChip extends StatelessWidget {
  final String label;
  final String number;
  final bool active;
  final bool done;
  final Color accent;
  final bool dark;
  final Color textColor;

  const _StepChip({
    required this.label,
    required this.number,
    required this.active,
    required this.done,
    required this.accent,
    required this.dark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (active || done)
                ? accent.withAlpha(dark ? 200 : 180)
                : Colors.transparent,
            border: Border.all(
              color: (active || done)
                  ? accent.withAlpha(dark ? 220 : 200)
                  : textColor.withAlpha(60),
            ),
          ),
          child: Text(
            done ? '✓' : number,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: (active || done) ? Colors.white : textColor.withAlpha(90),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active
                ? textColor
                : done
                    ? accent.withAlpha(dark ? 160 : 140)
                    : textColor.withAlpha(80),
          ),
        ),
      ],
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

// Petit bouton icône style or pour la navigation
class _GoldIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;

  const _GoldIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: const Color(0xFF4A3F30).withAlpha(220)),
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Indicateur verset ornemental  (remplace _OrnamentalDivider)
// ══════════════════════════════════════════════════════════════════════════════

class _VerseIndicatorBox extends StatelessWidget {
  final int   surah;
  final int   ayah;
  final Color accentColor;
  final bool  dark;

  const _VerseIndicatorBox({
    required this.surah,
    required this.ayah,
    required this.accentColor,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    // Parchment-style colours matching the manuscript aesthetic
    final bg          = dark ? const Color(0xFF1C2333) : const Color(0xFFFAF6EE);
    const borderColor = Color(0xFFC8A97E); // medium gold
    final textColor   = dark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);
    final sepColor    = dark ? const Color(0xFFB08050) : const Color(0xFFC8A97E);
    final surahName   = TafsirService.surahNames[surah - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          // Base card with parchment background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color:  bg,
              border: Border.all(color: borderColor, width: 1.3),
              borderRadius: BorderRadius.circular(4),
              boxShadow: dark
                  ? []
                  : [
                      BoxShadow(
                        color:      Colors.black.withAlpha(14),
                        blurRadius: 6,
                        offset:     const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  surahName,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanTahaNaskh',
                    fontSize:   20,
                    color:      textColor,
                    height:     1.2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ' ─── ',
                    style: TextStyle(color: sepColor, fontSize: 13),
                  ),
                ),
                Text(
                  'آية $ayah',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanTahaNaskh',
                    fontSize:   20,
                    color:      textColor,
                    height:     1.2,
                  ),
                ),
              ],
            ),
          ),
          // Arabesque corner ornaments painted on top
          Positioned.fill(
            child: CustomPaint(painter: _VerseFrameCornerPainter()),
          ),
        ],
      ),
    );
  }
}

// ── Arabesque corner ornaments for the verse indicator box ────────────────────

class _VerseFrameCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const c = Color(0xFFC8A97E);
    final p = Paint()
      ..color = c.withAlpha(180)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fp = Paint()
      ..color = c.withAlpha(160)
      ..style = PaintingStyle.fill;

    const arm = 14.0;

    void drawCorner(double x, double y, double sx, double sy) {
      // L-arm going inward
      canvas.drawLine(Offset(x, y + sy * arm), Offset(x, y), p);
      canvas.drawLine(Offset(x, y), Offset(x + sx * arm, y), p);
      // Tiny diamond ornament at vertex
      canvas.drawPath(
        Path()
          ..moveTo(x, y - sy * 4)
          ..lineTo(x + sx * 4, y)
          ..lineTo(x, y + sy * 4)
          ..lineTo(x - sx * 4, y)
          ..close(),
        fp,
      );
    }

    drawCorner(0,          0,            1,  1);
    drawCorner(size.width, 0,           -1,  1);
    drawCorner(0,          size.height,  1, -1);
    drawCorner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// Boutons d'action par verset (Copier / Partager)
// ══════════════════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  final String arabicText;
  final String tafsirText;
  final String bookNameAr;
  final String verseKey;
  final Color  accentColor;
  final bool   dark;
  final Color  textPrimary;

  const _ActionButtons({
    required this.arabicText,
    required this.tafsirText,
    required this.bookNameAr,
    required this.verseKey,
    required this.accentColor,
    required this.dark,
    required this.textPrimary,
  });

  String get _fullText =>
      '$arabicText\n\n── $bookNameAr ──\n$tafsirText\n\n[$verseKey]';

  @override
  Widget build(BuildContext context) {
    // Golden manuscript palette
    final chipBg     = dark ? const Color(0xFF4A2E06) : const Color(0xFFE8D5B3);
    final chipBg2    = dark ? const Color(0xFF6B4510) : const Color(0xFFCFAF7E);
    final chipBorder = dark ? const Color(0xFF8B6814) : const Color(0xFFC8A97E);
    final labelColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionChip(
            icon:    Icons.copy_rounded,
            label:   'Copier',
            bg:      chipBg,
            bg2:     chipBg2,
            border:  chipBorder,
            color:   labelColor,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _fullText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copié dans le presse-papier'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 12),
          _ActionChip(
            icon:   Icons.share_rounded,
            label:  'Partager',
            bg:     chipBg,
            bg2:    chipBg2,
            border: chipBorder,
            color:  labelColor,
            onTap:  () => Share.share(_fullText),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        bg;
  final Color        bg2;
  final Color        border;
  final Color        color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.bg2,
    required this.border,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [bg, bg2],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(18),
              blurRadius: 4,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                color:      color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// En-tête de section tafsir  "── تفسير ابن كثير ──  ◆"
// ══════════════════════════════════════════════════════════════════════════════

class _TafsirSectionTitle extends StatelessWidget {
  final String bookNameAr;
  final Color  accentColor;
  final bool   dark;
  final Color  textPrimary;

  const _TafsirSectionTitle({
    required this.bookNameAr,
    required this.accentColor,
    required this.dark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor  = accentColor.withAlpha(dark ? 60 : 45);
    final titleColor = textPrimary.withAlpha(dark ? 200 : 180);
    final diamondColor = accentColor.withAlpha(dark ? 160 : 130);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.transparent, lineColor]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  bookNameAr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily:  'UthmanTahaNaskh',
                    fontSize:    20,
                    color:       titleColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [lineColor, Colors.transparent]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text('◆',
            style: TextStyle(fontSize: 9, color: diamondColor)),
      ],
    );
  }
}
