import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tafsir_service.dart';
import '../services/quran_text_db.dart';
import '../services/quran_ayah_metadata_db.dart';
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
  final double _fontSize = 18;
  final ScrollController _scrollCtrl = ScrollController();
  bool _searchVisible = false;

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

      // Source primaire : DB bundlée (toujours disponible, aucun téléchargement)
      try {
        final metaTexts =
            await QuranAyahMetadataDb.instance.getSurahTexts(surah);
        for (final v in verses) {
          final ar = metaTexts[v.verseKey] ?? '';
          if (ar.isNotEmpty) {
            arVerses[v.verseKey] = QVerse(
              verseKey: v.verseKey,
              surah: v.surah,
              ayah: v.ayah,
              ar: ar,
              fr: '',
              tafsir: null,
            );
          }
        }
      } catch (_) {}

      // Supplément : QuranTextDb si un pack est téléchargé (ajoute la traduction FR)
      try {
        final db = QuranTextDb.instance;
        if (await db.isReady()) {
          final keys = verses.map((v) => v.verseKey).toList();
          final dbVerses = await db.getVersesByKeys(keys);
          for (final entry in dbVerses.entries) {
            final existing = arVerses[entry.key];
            if (existing != null) {
              arVerses[entry.key] = QVerse(
                verseKey: existing.verseKey,
                surah: existing.surah,
                ayah: existing.ayah,
                ar: existing.ar.isNotEmpty ? existing.ar : entry.value.ar,
                fr: entry.value.fr,
                tafsir: entry.value.tafsir,
              );
            } else {
              arVerses[entry.key] = entry.value;
            }
          }
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

  void _showSearchSheet() => setState(() => _searchVisible = true);

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _searchVisible = false);
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
      extendBody: true,
      body: Stack(
        children: [
          // ── Fond image plein écran ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/tafsir/fond_tafsir.webp',
              fit: BoxFit.fill,
            ),
          ),

          // ── Nom du tafsir dans la banderole ────────────────────────────────
          Positioned(
            top: padding.top + 4, left: 0, right: 0,
            height: bannerH - padding.top - 10,
            child: Center(
              child: Text(
                widget.book.nameFr,
                style: const TextStyle(
                  fontSize:      18,
                  color:         Color(0xFF6B3E18),
                  letterSpacing: 3.0,
                  fontWeight:    FontWeight.w600,
                ),
              ),
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
                            bookSlug:   widget.book.slug,
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
                        size: 20, color: Color(0xFF6B3E18)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search_rounded,
                        size: 22, color: Color(0xFF6B3E18)),
                    onPressed: _showSearchSheet,
                  ),
                ],
              ),
            ),
          ),

          // ── Barrière recherche ──────────────────────────────────────────────
          if (_searchVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeSearch,
                child: const ColoredBox(color: Color(0x80000000)),
              ),
            ),

          // ── Panneau de recherche (toujours dans l'arbre pour AnimatedSlide) ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _searchVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !_searchVisible,
                child: _SearchSheet(
                  accentColor: widget.book.gradient.first,
                  onNavigate: (surah, ayah) {
                    _closeSearch();
                    _changeSurah(surah, ayah: ayah);
                  },
                ),
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
  final String bookSlug;
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
    required this.bookSlug,
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
          bookSlug: bookSlug,
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
  final String      bookSlug;

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
    required this.bookSlug,
  });

  @override
  Widget build(BuildContext context) {
    final hasArabic = arabicVerse?.ar != null && arabicVerse!.ar.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cadre verset : actions ────────────────────────────────────────
          _VerseIndicatorBox(
            surah:       verse.surah,
            ayah:        verse.ayah,
            verseKey:    verse.verseKey,
            accentColor: accentColor,
            dark:        dark,
            arabicText:  arabicVerse?.ar,
            tafsirText:  verse.text,
            bookNameAr:  bookNameAr,
            bookSlug:    bookSlug,
          ),
          const SizedBox(height: 22),

          // ── Carte verset enluminée ────────────────────────────────────────
          if (hasArabic) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFEFCF4), Color(0xFFF2E5C8)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFBFA068),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC8A97E).withAlpha(65),
                          blurRadius: 22,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                    child: Text(
                      arabicVerse!.ar,
                      textAlign:     TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily:    'UthmanTahaNaskh',
                        fontSize:      fontSize + 9,
                        color:         const Color(0xFF4A3F30),
                        height:        2.4,
                        letterSpacing: 0,
                        shadows: [
                          Shadow(
                            color:      const Color(0xFFC8A97E).withAlpha(55),
                            blurRadius: 18,
                            offset:     Offset.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _VerseFrameCornerPainter()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                fontWeight: FontWeight.w600,
                color:      const Color(0xFF4A3F30).withAlpha(200),
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

  static const _theme = Color(0xFF6B3E18);

  @override
  Widget build(BuildContext context) {
    final bottom    = MediaQuery.of(context).padding.bottom;
    final textColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
    final arName    = TafsirService.surahNames[currentSurah - 1];
    final dimColor  = _theme.withAlpha(dark ? 55 : 38);

    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      decoration: BoxDecoration(
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDD8A0), Color(0xFFF8EDD8)],
              ),
        color: dark ? const Color(0xFF0C1220) : null,
        border: Border(top: BorderSide(color: dimColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // ── ← Verset précédent ────────────────────────────────────────
          GestureDetector(
            onTap: onPrev,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 11,
                    color: onPrev != null ? _theme : dimColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'V. ${currentAyah > 1 ? currentAyah - 1 : "–"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: onPrev != null ? _theme : dimColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Centre : nom sourate (tappable → picker) ──────────────────
          Expanded(
            child: GestureDetector(
              onTap: onPicker,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    arName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'UthmanTahaNaskh',
                      fontSize: 19,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'verset $currentAyah / $totalAyahs',
                    style: TextStyle(
                      fontSize: 10,
                      color: _theme.withAlpha(dark ? 160 : 130),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Verset suivant → ──────────────────────────────────────────
          GestureDetector(
            onTap: onNext,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'V. ${currentAyah < totalAyahs ? currentAyah + 1 : "–"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: onNext != null ? _theme : dimColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: onNext != null ? _theme : dimColor,
                  ),
                ],
              ),
            ),
          ),
        ],
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
  late int _surah;
  late int _ayah;
  late FixedExtentScrollController _surahCtrl;
  late FixedExtentScrollController _ayahCtrl;

  int get _maxAyah => TafsirService.surahAyahCounts[_surah - 1];

  @override
  void initState() {
    super.initState();
    _surah = widget.currentSurah;
    _ayah  = 1;
    _surahCtrl = FixedExtentScrollController(initialItem: _surah - 1);
    _ayahCtrl  = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _surahCtrl.dispose();
    _ayahCtrl.dispose();
    super.dispose();
  }

  void _onSurahChanged(int index) {
    setState(() {
      _surah = index + 1;
      _ayah  = 1;
    });
    _ayahCtrl.jumpToItem(0);
  }

  @override
  Widget build(BuildContext context) {
    final dark      = Theme.of(context).brightness == Brightness.dark;
    final bg        = dark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    final textColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
    final accent    = widget.accentColor;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    const itemH       = 48.0;
    const visibleItems = 5;
    const wheelH      = itemH * visibleItems;

    return Container(
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
      padding: EdgeInsets.fromLTRB(0, 14, 0, bottomPad + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ornemental ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('✦', style: TextStyle(fontSize: 7, color: accent.withAlpha(dark ? 130 : 95))),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 3,
                decoration: BoxDecoration(
                  color: accent.withAlpha(dark ? 110 : 75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('✦', style: TextStyle(fontSize: 7, color: accent.withAlpha(dark ? 130 : 95))),
            ],
          ),
          const SizedBox(height: 14),

          // ── Titre ───────────────────────────────────────────────────────
          Text(
            'Aller au verset',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),

          // ── Ligne séparatrice ────────────────────────────────────────────
          Container(
            height: 0.8,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                accent.withAlpha(dark ? 70 : 50),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 6),

          // ── Labels ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Sourate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Verset',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Roulettes ───────────────────────────────────────────────────
          SizedBox(
            height: wheelH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // Bande de sélection centrale
                  Positioned(
                    top: itemH * 2,
                    left: 0,
                    right: 0,
                    height: itemH,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent.withAlpha(dark ? 35 : 22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          top: BorderSide(
                              color: accent.withAlpha(dark ? 90 : 60),
                              width: 0.8),
                          bottom: BorderSide(
                              color: accent.withAlpha(dark ? 90 : 60),
                              width: 0.8),
                        ),
                      ),
                    ),
                  ),

                  // Roues
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Roulette sourate ──────────────────────────────
                      Expanded(
                        flex: 3,
                        child: ListWheelScrollView.useDelegate(
                          controller: _surahCtrl,
                          itemExtent: itemH,
                          physics: const FixedExtentScrollPhysics(),
                          diameterRatio: 1.6,
                          perspective: 0.003,
                          onSelectedItemChanged: _onSurahChanged,
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 114,
                            builder: (ctx, i) {
                              final s        = i + 1;
                              final selected = s == _surah;
                              return Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$s.',
                                      style: TextStyle(
                                        fontSize: selected ? 12 : 10,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: selected
                                            ? textColor
                                            : textColor.withAlpha(90),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      TafsirService.surahNames[i],
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily: 'UthmanTahaNaskh',
                                        fontSize: selected ? 20 : 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: selected
                                            ? accent
                                            : textColor.withAlpha(90),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ── Séparateur vertical ───────────────────────────
                      Container(
                        width: 0.8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: accent.withAlpha(dark ? 55 : 40),
                      ),

                      // ── Roulette verset ───────────────────────────────
                      Expanded(
                        flex: 2,
                        child: ListWheelScrollView.useDelegate(
                          controller: _ayahCtrl,
                          itemExtent: itemH,
                          physics: const FixedExtentScrollPhysics(),
                          diameterRatio: 1.6,
                          perspective: 0.003,
                          onSelectedItemChanged: (i) =>
                              setState(() => _ayah = i + 1),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _maxAyah,
                            builder: (ctx, i) {
                              final a        = i + 1;
                              final selected = a == _ayah;
                              return Center(
                                child: Text(
                                  '$a',
                                  style: TextStyle(
                                    fontSize: selected ? 18 : 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: selected
                                        ? textColor
                                        : textColor.withAlpha(90),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Fondu haut
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: itemH * 1.6,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [bg, bg.withAlpha(0)],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Fondu bas
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    height: itemH * 1.6,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [bg, bg.withAlpha(0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Container(
            height: 0.8,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                accent.withAlpha(dark ? 70 : 50),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // ── Bouton confirmer ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onSelect(_surah, _ayah),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Confirmer',
                  style: TextStyle(
                    color: dark ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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

// ══════════════════════════════════════════════════════════════════════════════
// Feuille de recherche sourate + verset
// ══════════════════════════════════════════════════════════════════════════════

class _SearchSheet extends StatefulWidget {
  final Color accentColor;
  final void Function(int surah, int ayah) onNavigate;

  const _SearchSheet({required this.accentColor, required this.onNavigate});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _surahCtrl = TextEditingController();
  final _ayahCtrl  = TextEditingController();
  List<String> _suggestions = [];
  int? _resolvedSurah;

  @override
  void initState() {
    super.initState();
    _surahCtrl.addListener(_onSurahChanged);
  }

  @override
  void dispose() {
    _surahCtrl.dispose();
    _ayahCtrl.dispose();
    super.dispose();
  }

  void _onSurahChanged() {
    final q = _surahCtrl.text.trim();
    if (q.isEmpty) {
      setState(() { _suggestions = []; _resolvedSurah = null; });
      return;
    }
    final asNum = int.tryParse(q);
    if (asNum != null) {
      setState(() {
        _resolvedSurah = (asNum >= 1 && asNum <= 114) ? asNum : null;
        _suggestions   = [];
      });
      return;
    }
    // Filtre sur les noms arabes
    final matches = <String>[];
    for (int i = 0; i < 114; i++) {
      if (TafsirService.surahNames[i].contains(q)) {
        matches.add('${i + 1} — ${TafsirService.surahNames[i]}');
        if (matches.length >= 6) break;
      }
    }
    setState(() { _suggestions = matches; _resolvedSurah = null; });
  }

  void _selectSurah(String option) {
    final num = int.tryParse(option.split(' ').first);
    setState(() {
      _resolvedSurah = num;
      _suggestions   = [];
    });
    _surahCtrl.text = option;
    _surahCtrl.selection =
        TextSelection.collapsed(offset: option.length);
  }

  void _navigate() {
    final surah = _resolvedSurah;
    if (surah == null) return;
    final maxAyahs = TafsirService.surahAyahCounts[surah - 1];
    final ayah = (int.tryParse(_ayahCtrl.text.trim()) ?? 1).clamp(1, maxAyahs);
    widget.onNavigate(surah, ayah);
  }

  @override
  Widget build(BuildContext context) {
    final dark      = Theme.of(context).brightness == Brightness.dark;
    final bg        = dark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    final textColor = dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810);
    final accent    = widget.accentColor;
    final topPad    = MediaQuery.of(context).padding.top;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent.withAlpha(60)),
    );
    final inputDeco = InputDecoration(
      filled: true,
      fillColor: accent.withAlpha(dark ? 20 : 12),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    );

    return Container(
      width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(55),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Aller à un verset',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),

            // ── Sourate ───────────────────────────────────────────────────
            Text('Sourate',
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(150))),
            const SizedBox(height: 6),
            TextField(
              controller: _surahCtrl,
              style: TextStyle(color: textColor, fontSize: 15),
              textDirection: TextDirection.rtl,
              decoration: inputDeco.copyWith(
                hintText: 'Numéro ou nom en arabe',
                hintStyle: TextStyle(
                    color: textColor.withAlpha(80),
                    fontSize: 14,
                    fontWeight: FontWeight.normal),
              ),
            ),

            // ── Suggestions ───────────────────────────────────────────────
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 190),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withAlpha(50)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: accent.withAlpha(30),
                    indent: 12,
                    endIndent: 12,
                  ),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => _selectSurah(_suggestions[i]),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Text(
                        _suggestions[i],
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // ── Verset ────────────────────────────────────────────────────
            Text('Verset',
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(150))),
            const SizedBox(height: 6),
            TextField(
              controller: _ayahCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: inputDeco.copyWith(
                hintText: _resolvedSurah != null
                    ? '1 – ${TafsirService.surahAyahCounts[_resolvedSurah! - 1]}'
                    : 'Numéro de verset',
                hintStyle: TextStyle(
                    color: textColor.withAlpha(80),
                    fontSize: 14,
                    fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: 20),

            // ── Bouton ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _resolvedSurah != null ? _navigate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: accent.withAlpha(60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Aller au verset',
                  style: TextStyle(
                    color: dark ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
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

// ══════════════════════════════════════════════════════════════════════════════
// Indicateur verset ornemental  (remplace _OrnamentalDivider)
// ══════════════════════════════════════════════════════════════════════════════

class _VerseIndicatorBox extends StatefulWidget {
  final int     surah;
  final int     ayah;
  final String  verseKey;
  final Color   accentColor;
  final bool    dark;
  final String? arabicText;
  final String  tafsirText;
  final String  bookNameAr;
  final String  bookSlug;

  const _VerseIndicatorBox({
    required this.surah,
    required this.ayah,
    required this.verseKey,
    required this.accentColor,
    required this.dark,
    required this.arabicText,
    required this.tafsirText,
    required this.bookNameAr,
    required this.bookSlug,
  });

  @override
  State<_VerseIndicatorBox> createState() => _VerseIndicatorBoxState();
}

class _VerseIndicatorBoxState extends State<_VerseIndicatorBox> {
  bool _isFav = false;
  static const _favKey = 'tafsir_favorites';

  String get _itemKey => '${widget.bookSlug}:${widget.verseKey}';

  String get _shareText {
    final buf = StringBuffer();
    final ar = widget.arabicText;
    if (ar != null && ar.isNotEmpty) {
      buf.writeln(ar);
      buf.writeln();
    }
    buf.writeln('── ${widget.bookNameAr} ──');
    buf.writeln(widget.tafsirText);
    buf.write('[${widget.verseKey}]');
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_favKey) ?? [];
    if (mounted) setState(() => _isFav = list.contains(_itemKey));
  }

  Future<void> _toggleFav() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = (prefs.getStringList(_favKey) ?? []).toList();
    if (_isFav) {
      list.remove(_itemKey);
    } else {
      list.add(_itemKey);
    }
    await prefs.setStringList(_favKey, list);
    if (mounted) setState(() => _isFav = !_isFav);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copié dans le presse-papier'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFC8A97E);
    const iconColor   = Color(0xFFC8A97E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:        Colors.transparent,
              border:       Border.all(color: borderColor, width: 1.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Share.share(_shareText),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Icon(Icons.share_rounded,
                        size: 18, color: iconColor),
                  ),
                ),
                GestureDetector(
                  onTap: _copy,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Icon(Icons.content_copy_rounded,
                        size: 18, color: iconColor),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleFav,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    child: Icon(
                      _isFav
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: _isFav
                          ? const Color(0xFFE8B04A)
                          : iconColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8D5B3), Color(0xFFCFAF7E)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'آية ${widget.ayah}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'UthmanTahaNaskh',
                      fontSize:   15,
                      color: Color(0xFF4A3F30),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    const lineColor    = Color(0xFFC8A97E);
    const titleColor   = Color(0xFF4A3F30);
    const diamondColor = Color(0xFFC8A97E);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.8,
                  decoration: const BoxDecoration(
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
                  style: const TextStyle(
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [lineColor, Colors.transparent]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text('◆',
            style: TextStyle(fontSize: 9, color: diamondColor)),
      ],
    );
  }
}
