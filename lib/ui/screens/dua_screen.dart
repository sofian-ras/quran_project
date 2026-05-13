import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/dua_db.dart';

const _kAudioUserAgent =
    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';

// ─────────────────────────────────────────────
//  CONSTANTES COULEURS
// ─────────────────────────────────────────────
const _kGreen = Color(0xFF4B6B52);
const _kDarkBg = Color(0xFF0B1220);
const _kDarkCard = Color(0xFF111B2E);
const _kLightBg = Color(0xFFF2ECE5);
const _kLightCard = Color(0xFFF6F1EB);

// ─────────────────────────────────────────────
//  MODÈLE THÈME
// ─────────────────────────────────────────────
class _DuaTheme {
  final String id;
  final String titleFr;
  final String imageAsset;
  final Color color;
  final List<int> chapterIds;

  const _DuaTheme({
    required this.id,
    required this.titleFr,
    required this.imageAsset,
    required this.color,
    required this.chapterIds,
  });
}

// 13 thèmes couvrant les 133 chapitres de Hisnul Muslim
const _kThemes = <_DuaTheme>[
  _DuaTheme(
    id: 'matin',
    titleFr: 'Matin',
    imageAsset: 'assets/images/dua_categories/matin.webp',
    color: Color(0xFF1A4731),
    chapterIds: [2, 27],
  ),
  _DuaTheme(
    id: 'soir',
    titleFr: 'Soir & Sommeil',
    imageAsset: 'assets/images/dua_categories/soir_sommeil.webp',
    color: Color(0xFF2D1B4E),
    chapterIds: [28, 29, 30, 31],
  ),
  _DuaTheme(
    id: 'priere',
    titleFr: 'Prière',
    imageAsset: 'assets/images/dua_categories/priere.webp',
    color: Color(0xFF1A3A4A),
    chapterIds: [9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 32, 33, 42],
  ),
  _DuaTheme(
    id: 'anxiete',
    titleFr: 'Anxiété & Difficultés',
    imageAsset: 'assets/images/dua_categories/anxiete.webp',
    color: Color(0xFF3D2314),
    chapterIds: [34, 35, 36, 37, 38, 39, 40, 41, 43, 45, 46, 82],
  ),
  _DuaTheme(
    id: 'famille',
    titleFr: 'Mariage & Famille',
    imageAsset: 'assets/images/dua_categories/mariage_famille.webp',
    color: Color(0xFF4A1A2D),
    chapterIds: [47, 48, 79, 80, 81],
  ),
  _DuaTheme(
    id: 'maladie',
    titleFr: 'Maladie & Mort',
    imageAsset: 'assets/images/dua_categories/maladie_mort.webp',
    color: Color(0xFF1A3D1A),
    chapterIds: [49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 124],
  ),
  _DuaTheme(
    id: 'repas',
    titleFr: 'Repas & Jeûne',
    imageAsset: 'assets/images/dua_categories/repas_jeune.webp',
    color: Color(0xFF3A3A1A),
    chapterIds: [68, 69, 70, 71, 72, 73, 74, 75, 76],
  ),
  _DuaTheme(
    id: 'voyage',
    titleFr: 'Voyage',
    imageAsset: 'assets/images/dua_categories/voyage.webp',
    color: Color(0xFF1A2D4A),
    chapterIds: [95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105],
  ),
  _DuaTheme(
    id: 'hajj',
    titleFr: 'Hajj & Omra',
    imageAsset: 'assets/images/dua_categories/hajj_omra.webp',
    color: Color(0xFF2A1A00),
    chapterIds: [115, 116, 117, 118, 119, 120, 121],
  ),
  _DuaTheme(
    id: 'purification',
    titleFr: 'Purification & Quotidien',
    imageAsset: 'assets/images/dua_categories/purification.webp',
    color: Color(0xFF003A3A),
    chapterIds: [3, 4, 5, 6, 7, 8, 11],
  ),
  _DuaTheme(
    id: 'social',
    titleFr: 'Relations & Vie sociale',
    imageAsset: 'assets/images/dua_categories/relations.webp',
    color: Color(0xFF2A1A3A),
    chapterIds: [77, 78, 83, 84, 85, 86, 87, 89, 90, 91, 92, 93, 94, 106, 108, 109, 112, 113, 114, 122, 123, 125, 126, 127],
  ),
  _DuaTheme(
    id: 'meteo',
    titleFr: 'Météo & Nature',
    imageAsset: 'assets/images/dua_categories/meteo_nature.webp',
    color: Color(0xFF0A2A3A),
    chapterIds: [61, 62, 63, 64, 65, 66, 67],
  ),
  _DuaTheme(
    id: 'dhikr',
    titleFr: 'Dhikr & Mérites',
    imageAsset: 'assets/images/dua_categories/dhikr.webp',
    color: Color(0xFF2A2A00),
    chapterIds: [1, 44, 88, 107, 110, 111, 128, 129, 130, 131, 132, 133],
  ),
];

// ─────────────────────────────────────────────
//  ECRAN PRINCIPAL — GRILLE CATÉGORIES
// ─────────────────────────────────────────────
class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, Object?>> _cats = [];
  Map<String, Object?>? _duaOfDay;
  String _query = '';
  List<Map<String, Object?>> _searchResults = [];
  Timer? _debounce;
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await DuaDb.instance.importFromAssetsIfEmpty();
      final cats = await DuaDb.instance.getCategories();

      Map<String, Object?>? duaOfDay;
      if (cats.isNotEmpty) {
        // Choisir une catégorie non-vide pour le duʿa du jour
        for (final cat in cats) {
          final id = cat['id'] as String;
          final count = (cat['dua_count'] as int?) ?? 0;
          if (count > 0) {
            final duas = await DuaDb.instance.getDuasByCategory(id);
            if (duas.isNotEmpty) {
              final idx = DateTime.now().day % duas.length;
              duaOfDay = {
                ...duas[idx],
                'cat_title_fr': cat['title_fr'] ?? '',
                'cat_id': id,
              };
              break;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _cats = cats;
        _duaOfDay = duaOfDay;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _duaCountForTheme(_DuaTheme theme) {
    int total = 0;
    for (final chId in theme.chapterIds) {
      final cat = _cats.firstWhere(
        (c) => c['id'] == 'c$chId',
        orElse: () => {},
      );
      total += (cat['dua_count'] as int?) ?? 0;
    }
    return total;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _query = '';
        _searchResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await DuaDb.instance.searchDuas(v);
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _searchResults = results;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invocations')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur:\n\n$_error'),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : _kLightBg;
    final cardBg = isDark ? _kDarkCard : _kLightCard;
    final stroke = isDark ? Colors.white12 : Colors.black12;
    final muted = isDark ? Colors.white54 : Colors.black45;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar + barre de recherche ──
          SliverAppBar(
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 210,
            pinned: true,
            floating: false,
            stretch: true,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              expandedTitleScale: 1.0,
              titlePadding: const EdgeInsets.only(bottom: 72),
              title: const Text(
                'Invocations',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                  fontSize: 18,
                ),
              ),
              collapseMode: CollapseMode.pin,
              background: Stack(
                children: [
                  // Fond dégradé vert
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [const Color(0xFF0D1A10), _kDarkBg]
                              : [const Color(0xFFDEEBDF), _kLightBg],
                        ),
                      ),
                    ),
                  ),
                  // Halo radial
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            _kGreen.withValues(alpha: isDark ? 0.30 : 0.18),
                            _kGreen.withValues(alpha: isDark ? 0.08 : 0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Verset
                  Padding(
                    padding: const EdgeInsets.only(bottom: 44),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ادْعُونِي أَسْتَجِبْ لَكُمْ',
                            style: TextStyle(
                              color: _kGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              '« Invoquez-Moi, Je vous répondrai. »  — Ghafir : 60',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _AnimatedDuaSearchBar(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ── Contenu : résultats recherche OU grille catégories ──
          if (_query.isNotEmpty)
            _SearchResultsSliver(
              results: _searchResults,
              isDark: isDark,
              cardBg: cardBg,
              stroke: stroke,
              muted: muted,
              textColor: textColor,
              searchFocus: _searchFocus,
            )
          else ...[
            // Duʿa du jour
            if (_duaOfDay != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _DuaOfDayBanner(
                    dua: _duaOfDay!,
                    isDark: isDark,
                    cardBg: cardBg,
                    stroke: stroke,
                    muted: muted,
                    onOpenCategory: (catId, titleFr, duaCount) {
                      _searchFocus.unfocus();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DuaCategoryScreen(
                          categoryId: catId,
                          titleFr: titleFr,
                          duaCount: duaCount,
                        ),
                      ));
                    },
                  ),
                ),
              ),

            // Titre section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'Toutes les catégories',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ),

            // Grille 2 colonnes des THÈMES
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final theme = _kThemes[i];
                    final count = _duaCountForTheme(theme);
                    return _ThemeCard(
                      theme: theme,
                      duaCount: count,
                      onTap: () {
                        _searchFocus.unfocus();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _DuaThemeScreen(theme: theme),
                        ));
                      },
                    );
                  },
                  childCount: _kThemes.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BARRE DE RECHERCHE
// ─────────────────────────────────────────────
class _AnimatedDuaSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _AnimatedDuaSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_AnimatedDuaSearchBar> createState() => _AnimatedDuaSearchBarState();
}

class _AnimatedDuaSearchBarState extends State<_AnimatedDuaSearchBar> {
  static const _hints = [
    'invocation du matin',
    'protection contre le mal',
    'après la prière',
    'avant de dormir',
    'en période d\'épreuve',
    'demander le pardon',
    'pour ses parents',
    'entrée dans la mosquée',
    'avant de manger',
    'quand il pleut',
    'pour la guérison',
    'le voyage',
    'gratitude envers Dieu',
    'supplication du vendredi',
    'pour un enfant',
  ];

  String _typed = '';
  bool _erasing = false;
  int _hintIndex = 0;
  Timer? _timer;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 800), _scheduleNext);
  }

  String get _currentHint => _hints[_hintIndex % _hints.length];

  void _scheduleNext() {
    if (!mounted || widget.controller.text.isNotEmpty) return;

    if (!_erasing) {
      if (_typed.length < _currentHint.length) {
        int delay = 55 + _rng.nextInt(85);
        if (_typed.isNotEmpty && _typed[_typed.length - 1] == ' ') {
          delay += 60 + _rng.nextInt(60);
        }
        if (_rng.nextInt(9) == 0) delay += 180 + _rng.nextInt(220);

        _timer = Timer(Duration(milliseconds: delay), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _typed += _currentHint[_typed.length]);
          _scheduleNext();
        });
      } else {
        _timer = Timer(Duration(milliseconds: 1800 + _rng.nextInt(1000)), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _erasing = true);
          _scheduleNext();
        });
      }
    } else {
      if (_typed.isNotEmpty) {
        _timer = Timer(Duration(milliseconds: 35 + _rng.nextInt(25)), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _typed = _typed.substring(0, _typed.length - 1));
          _scheduleNext();
        });
      } else {
        _timer = Timer(Duration(milliseconds: 500 + _rng.nextInt(400)), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() {
            _hintIndex = (_hintIndex + 1) % _hints.length;
            _erasing = false;
          });
          _scheduleNext();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: _kGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (_, val, __) {
                    if (val.text.isNotEmpty) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _typed,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        if (!_erasing || _typed.isEmpty)
                          _DuaBlinkingCursor(isDark: isDark),
                      ],
                    );
                  },
                ),
                Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    cursorColor: _kGreen,
                    decoration: const InputDecoration(
                      hintText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.only(bottom: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (_, val, __) {
              if (val.text.isEmpty) return const SizedBox(width: 12);
              return IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DuaBlinkingCursor extends StatefulWidget {
  final bool isDark;
  const _DuaBlinkingCursor({required this.isDark});

  @override
  State<_DuaBlinkingCursor> createState() => _DuaBlinkingCursorState();
}

class _DuaBlinkingCursorState extends State<_DuaBlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 1.5,
        height: 16,
        color: _kGreen,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BANNIÈRE DUʿA DU JOUR
// ─────────────────────────────────────────────
class _DuaOfDayBanner extends StatelessWidget {
  final Map<String, Object?> dua;
  final bool isDark;
  final Color cardBg;
  final Color stroke;
  final Color muted;
  final void Function(String catId, String titleFr, int duaCount) onOpenCategory;

  const _DuaOfDayBanner({
    required this.dua,
    required this.isDark,
    required this.cardBg,
    required this.stroke,
    required this.muted,
    required this.onOpenCategory,
  });

  @override
  Widget build(BuildContext context) {
    final ar = (dua['ar'] as String?)?.trim() ?? '';
    final fr = (dua['fr'] as String?)?.trim() ?? '';
    final en = (dua['en'] as String?)?.trim() ?? '';
    final catTitleFr = (dua['cat_title_fr'] as String?)?.trim() ?? '';
    final catId = (dua['cat_id'] as String?) ?? '';
    final audioUrl = (dua['audio_url'] as String?)?.trim() ?? '';
    final shown = fr.isNotEmpty ? fr : en;

    return GestureDetector(
      onTap: () => onOpenCategory(catId, catTitleFr, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: stroke),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre accent verte
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invocation du jour',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (ar.isNotEmpty)
                        Text(
                          ar,
                          textDirection: TextDirection.rtl,
                          locale: const Locale('ar'),
                          style: const TextStyle(
                              fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.7,
                          ),
                        ),
                      if (ar.isNotEmpty) const SizedBox(height: 8),
                      if (shown.isNotEmpty)
                        Text(
                          shown,
                          style: TextStyle(fontSize: 13, height: 1.45, color: muted),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (catTitleFr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                catTitleFr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const Spacer(),
                          if (audioUrl.isNotEmpty)
                            _InlineAudioButton(audioUrl: audioUrl),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CARTE THÈME (GRILLE)
// ─────────────────────────────────────────────
class _ThemeCard extends StatelessWidget {
  final _DuaTheme theme;
  final int duaCount;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.duaCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de fond
              Image.asset(
                theme.imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.color,
                        Color.lerp(theme.color, Colors.black, 0.5)!,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

              // Voile sombre bas
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.6, 1.0],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge nombre de duas
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$duaCount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Titre
                    Text(
                      theme.titleFr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────
//  RÉSULTATS DE RECHERCHE
// ─────────────────────────────────────────────
class _SearchResultsSliver extends StatelessWidget {
  final List<Map<String, Object?>> results;
  final bool isDark;
  final Color cardBg;
  final Color stroke;
  final Color muted;
  final Color textColor;
  final FocusNode searchFocus;

  const _SearchResultsSliver({
    required this.results,
    required this.isDark,
    required this.cardBg,
    required this.stroke,
    required this.muted,
    required this.textColor,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text('Aucun résultat', style: TextStyle(color: muted)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final d = results[i];
          final ar = (d['ar'] as String?)?.trim() ?? '';
          final fr = (d['fr'] as String?)?.trim() ?? '';
          final en = (d['en'] as String?)?.trim() ?? '';
          final catTitleFr = (d['cat_title_fr'] as String?)?.trim() ?? '';
          final catId = (d['cat_id'] as String?) ?? '';
          final shown = fr.isNotEmpty ? fr : en;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GestureDetector(
              onTap: () {
                searchFocus.unfocus();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DuaCategoryScreen(
                    categoryId: catId,
                    titleFr: catTitleFr,
                    duaCount: 0,
                  ),
                ));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: stroke),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (catTitleFr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          catTitleFr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kGreen,
                          ),
                        ),
                      ),
                    if (ar.isNotEmpty)
                      Text(
                        ar,
                        textDirection: TextDirection.rtl,
                        locale: const Locale('ar'),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (ar.isNotEmpty && shown.isNotEmpty) const SizedBox(height: 4),
                    if (shown.isNotEmpty)
                      Text(
                        shown,
                        style: TextStyle(fontSize: 13, color: muted, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: results.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ÉCRAN THÈME — LISTE DES SOUS-CATÉGORIES
// ─────────────────────────────────────────────
class _DuaThemeScreen extends StatefulWidget {
  final _DuaTheme theme;

  const _DuaThemeScreen({required this.theme});

  @override
  State<_DuaThemeScreen> createState() => __DuaThemeScreenState();
}

class __DuaThemeScreenState extends State<_DuaThemeScreen> {
  bool _loading = true;
  List<Map<String, Object?>> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = widget.theme.chapterIds.map((id) => 'c$id').toList();
    final cats = await DuaDb.instance.getCategoriesByIds(ids);
    if (!mounted) return;
    setState(() {
      _cats = cats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : _kLightBg;
    final cardBg = isDark ? _kDarkCard : _kLightCard;
    final stroke = isDark ? Colors.white12 : Colors.black12;
    final muted = isDark ? Colors.white54 : Colors.black45;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bg,
            elevation: 0,
            pinned: true,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
            title: Text(
              widget.theme.titleFr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _kGreen,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cat = _cats[i];
                  final id = (cat['id'] as String?) ?? '';
                  final titleFr = (cat['title_fr'] as String?)?.trim() ?? '';
                  final titleEn = (cat['title_en'] as String?)?.trim() ?? '';
                  final duaCount = (cat['dua_count'] as int?) ?? 0;
                  final displayTitle = titleFr.isNotEmpty ? titleFr : titleEn;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DuaCategoryScreen(
                            categoryId: id,
                            titleFr: displayTitle,
                            duaCount: duaCount,
                          ),
                        ));
                      },
                      child: Container(
                        margin: EdgeInsets.fromLTRB(16, i == 0 ? 8 : 0, 16, 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: stroke),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (duaCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _kGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$duaCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kGreen,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: muted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _cats.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ÉCRAN CATÉGORIE — LISTE DES DUʿA
// ─────────────────────────────────────────────
class DuaCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String titleFr;
  final int duaCount;

  const DuaCategoryScreen({
    super.key,
    required this.categoryId,
    required this.titleFr,
    required this.duaCount,
  });

  @override
  State<DuaCategoryScreen> createState() => _DuaCategoryScreenState();
}

class _DuaCategoryScreenState extends State<DuaCategoryScreen> {
  bool _loading = true;
  List<Map<String, Object?>> _items = [];

  AudioPlayer? _audioPlayer;
  StreamSubscription? _audioSub;
  String? _playingId;
  bool _audioLoading = false;

  Set<String> _favorites = {};
  static const _prefsKey = 'dua_favorites';

  @override
  void initState() {
    super.initState();
    _load();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _favorites = list.toSet());
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    await prefs.setStringList(_prefsKey, _favorites.toList());
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await DuaDb.instance.getDuasByCategory(widget.categoryId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<File> _downloadAudio(String duaId, String url) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dua_v4_$duaId.mp3');
    if (await file.exists()) return file;
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'User-Agent': _kAudioUserAgent},
      ),
    );
    await file.writeAsBytes(response.data!);
    return file;
  }

  Future<void> _toggleAudio(String duaId, String url) async {
    if (_playingId == duaId) {
      await _audioPlayer?.stop();
      _audioSub?.cancel();
      if (mounted) setState(() => _playingId = null);
      return;
    }

    _audioSub?.cancel();
    await _audioPlayer?.stop();
    _audioPlayer ??= AudioPlayer();

    if (mounted) setState(() { _playingId = duaId; _audioLoading = true; });

    try {
      final file = await _downloadAudio(duaId, url);
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.file(file.path),
          tag: MediaItem(id: duaId, title: 'Duʿa'),
        ),
      );
      _audioSub = _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingId = null);
        }
      });
      await _audioPlayer!.play();
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }

    if (mounted) setState(() => _audioLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : _kLightBg;
    final cardBg = isDark ? _kDarkCard : _kLightCard;
    final stroke = isDark ? Colors.white12 : Colors.black12;
    final muted = isDark ? Colors.white54 : Colors.black45;

    final int total = _items.isNotEmpty ? _items.length : widget.duaCount;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bg,
            elevation: 0,
            pinned: true,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.titleFr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (total > 0)
                  Text(
                    '$total invocation${total > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final dua = _items[i];
                  final id = (dua['id'] as String?) ?? '$i';
                  return Padding(
                    padding: EdgeInsets.fromLTRB(12, i == 0 ? 8 : 0, 12, 10),
                    child: GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        _audioSub?.cancel();
                        await _audioPlayer?.stop();
                        if (!mounted) return;
                        setState(() => _playingId = null);
                        await nav.push(
                          MaterialPageRoute(
                            builder: (_) => _DuaDetailScreen(
                              items: _items,
                              initialIndex: i,
                              categoryTitle: widget.titleFr,
                            ),
                          ),
                        );
                        await _loadFavorites();
                      },
                      child: _DuaCard(
                        dua: dua,
                        index: i,
                        isDark: isDark,
                        cardBg: cardBg,
                        stroke: stroke,
                        muted: muted,
                        isPlaying: _playingId == id,
                        isAudioLoading: _audioLoading && _playingId == id,
                        isFavorite: _favorites.contains(id),
                        onToggleAudio: () {
                          final url = (dua['audio_url'] as String?)?.trim() ?? '';
                          if (url.isNotEmpty) _toggleAudio(id, url);
                        },
                        onToggleFavorite: () => _toggleFavorite(id),
                      ),
                    ),
                  );
                },
                  childCount: _items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CARTE DUʿA
// ─────────────────────────────────────────────
class _DuaCard extends StatelessWidget {
  final Map<String, Object?> dua;
  final int index;
  final bool isDark;
  final Color cardBg;
  final Color stroke;
  final Color muted;
  final bool isPlaying;
  final bool isAudioLoading;
  final bool isFavorite;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleFavorite;

  const _DuaCard({
    required this.dua,
    required this.index,
    required this.isDark,
    required this.cardBg,
    required this.stroke,
    required this.muted,
    required this.isPlaying,
    required this.isAudioLoading,
    required this.isFavorite,
    required this.onToggleAudio,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final ar = (dua['ar'] as String?)?.trim() ?? '';
    final fr = (dua['fr'] as String?)?.trim() ?? '';
    final en = (dua['en'] as String?)?.trim() ?? '';
    final phonetic = (dua['phonetic'] as String?)?.trim() ?? '';
    final source = (dua['source'] as String?)?.trim() ?? '';
    final explanation = (dua['explanation'] as String?)?.trim() ?? '';
    final repeat = (dua['repeat_count'] as int?) ?? 1;
    final audioUrl = (dua['audio_url'] as String?)?.trim() ?? '';
    final shown = fr.isNotEmpty ? fr : en;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Numéro + badge répétition
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (repeat > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '× $repeat',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ),
              ],
            ),

            // Texte arabe
            if (ar.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                ar,
                textDirection: TextDirection.rtl,
                locale: const Locale('ar'),
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.85,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            // Phonétique
            if (phonetic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                phonetic,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: muted,
                  height: 1.4,
                ),
              ),
            ],

            // Traduction française
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                shown,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],

            // Explication
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                explanation,
                style: TextStyle(fontSize: 13, color: muted, height: 1.4),
              ),
            ],

            // Source (collapsible)
            if (source.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CollapsibleSource(source: source, muted: muted),
            ],

            // Barre d'actions : audio + copier + partager + favoris
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                if (audioUrl.isNotEmpty)
                  _AudioPlayButton(
                    isPlaying: isPlaying,
                    isLoading: isAudioLoading,
                    onTap: onToggleAudio,
                  ),
                const Spacer(),
                _ActionIcon(
                  icon: Icons.copy_rounded,
                  color: muted,
                  tooltip: 'Copier',
                  onTap: () {
                    final title = (dua['title_fr'] as String?)?.trim() ?? '';
                    final parts = <String>[
                      if (title.isNotEmpty) title,
                      if (ar.isNotEmpty) ar,
                      if (phonetic.isNotEmpty) phonetic,
                      if (shown.isNotEmpty) shown,
                      if (source.isNotEmpty) source,
                    ];
                    Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copié dans le presse-papiers'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: Icons.share_rounded,
                  color: muted,
                  tooltip: 'Partager',
                  onTap: () {
                    final title = (dua['title_fr'] as String?)?.trim() ?? '';
                    final parts = <String>[
                      if (title.isNotEmpty) title,
                      if (ar.isNotEmpty) ar,
                      if (phonetic.isNotEmpty) phonetic,
                      if (shown.isNotEmpty) shown,
                      if (source.isNotEmpty) source,
                    ];
                    Share.share(parts.join('\n\n'));
                  },
                ),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isFavorite ? _kGreen : muted,
                  tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  onTap: onToggleFavorite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SOURCE COLLAPSIBLE
// ─────────────────────────────────────────────
class _CollapsibleSource extends StatefulWidget {
  final String source;
  final Color muted;

  const _CollapsibleSource({required this.source, required this.muted});

  @override
  State<_CollapsibleSource> createState() => _CollapsibleSourceState();
}

class _CollapsibleSourceState extends State<_CollapsibleSource> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Text(
        widget.source,
        style: TextStyle(fontSize: 11, color: widget.muted, height: 1.35),
        maxLines: _expanded ? null : 2,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOUTON LECTURE AUDIO
// ─────────────────────────────────────────────
class _AudioPlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const _AudioPlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kGreen,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: _kGreen,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            isPlaying ? 'Arrêter' : 'Écouter',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ICÔNE D'ACTION (copier / partager / favoris)
// ─────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOUTON AUDIO INLINE (bannière dua du jour)
// ─────────────────────────────────────────────
class _InlineAudioButton extends StatefulWidget {
  final String audioUrl;

  const _InlineAudioButton({required this.audioUrl});

  @override
  State<_InlineAudioButton> createState() => _InlineAudioButtonState();
}

// ─────────────────────────────────────────────
//  ÉCRAN DÉTAIL DUʿA (plein écran + swipe)
// ─────────────────────────────────────────────
class _DuaDetailScreen extends StatefulWidget {
  final List<Map<String, Object?>> items;
  final int initialIndex;
  final String categoryTitle;

  const _DuaDetailScreen({
    required this.items,
    required this.initialIndex,
    required this.categoryTitle,
  });

  @override
  State<_DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends State<_DuaDetailScreen> {
  late PageController _controller;
  late int _currentIndex;

  AudioPlayer? _audioPlayer;
  StreamSubscription? _audioSub;
  String? _playingId;
  bool _audioLoading = false;

  Set<String> _favorites = {};
  static const _prefsKey = 'dua_favorites';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _loadFavorites();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _favorites = list.toSet());
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    await prefs.setStringList(_prefsKey, _favorites.toList());
  }

  Future<File> _downloadAudio(String duaId, String url) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dua_v4_$duaId.mp3');
    if (await file.exists()) return file;
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'User-Agent': _kAudioUserAgent},
      ),
    );
    await file.writeAsBytes(response.data!);
    return file;
  }

  Future<void> _toggleAudio(String duaId, String url) async {
    if (_playingId == duaId) {
      await _audioPlayer?.stop();
      _audioSub?.cancel();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    _audioSub?.cancel();
    await _audioPlayer?.stop();
    _audioPlayer ??= AudioPlayer();
    if (mounted) setState(() { _playingId = duaId; _audioLoading = true; });
    try {
      final file = await _downloadAudio(duaId, url);
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.file(file.path),
          tag: MediaItem(id: duaId, title: 'Duʿa'),
        ),
      );
      _audioSub = _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingId = null);
        }
      });
      await _audioPlayer!.play();
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
    if (mounted) setState(() => _audioLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : _kLightBg;
    final muted = isDark ? Colors.white54 : Colors.black45;

    final dua = widget.items[_currentIndex];
    final id = (dua['id'] as String?) ?? '$_currentIndex';
    final audioUrl = (dua['audio_url'] as String?)?.trim() ?? '';
    final ar = (dua['ar'] as String?)?.trim() ?? '';
    final fr = (dua['fr'] as String?)?.trim() ?? '';
    final en = (dua['en'] as String?)?.trim() ?? '';
    final phonetic = (dua['phonetic'] as String?)?.trim() ?? '';
    final source = (dua['source'] as String?)?.trim() ?? '';
    final shown = fr.isNotEmpty ? fr : en;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.categoryTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kGreen,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentIndex + 1} / ${widget.items.length}',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (index) async {
          _audioSub?.cancel();
          await _audioPlayer?.stop();
          if (mounted) setState(() { _playingId = null; _currentIndex = index; });
        },
        itemBuilder: (context, i) => _DuaDetailPage(
          dua: widget.items[i],
          index: i,
          isDark: isDark,
          muted: muted,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? _kDarkCard : _kLightCard,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (audioUrl.isNotEmpty)
                  _AudioPlayButton(
                    isPlaying: _playingId == id,
                    isLoading: _audioLoading && _playingId == id,
                    onTap: () => _toggleAudio(id, audioUrl),
                  ),
                const Spacer(),
                _ActionIcon(
                  icon: Icons.copy_rounded,
                  color: muted,
                  tooltip: 'Copier',
                  onTap: () {
                    final title = (dua['title_fr'] as String?)?.trim() ?? '';
                    final parts = <String>[
                      if (title.isNotEmpty) title,
                      if (ar.isNotEmpty) ar,
                      if (phonetic.isNotEmpty) phonetic,
                      if (shown.isNotEmpty) shown,
                      if (source.isNotEmpty) source,
                    ];
                    Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copié dans le presse-papiers'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: Icons.share_rounded,
                  color: muted,
                  tooltip: 'Partager',
                  onTap: () {
                    final title = (dua['title_fr'] as String?)?.trim() ?? '';
                    final parts = <String>[
                      if (title.isNotEmpty) title,
                      if (ar.isNotEmpty) ar,
                      if (phonetic.isNotEmpty) phonetic,
                      if (shown.isNotEmpty) shown,
                      if (source.isNotEmpty) source,
                    ];
                    Share.share(parts.join('\n\n'));
                  },
                ),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: _favorites.contains(id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _favorites.contains(id) ? _kGreen : muted,
                  tooltip: _favorites.contains(id)
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  onTap: () => _toggleFavorite(id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE CONTENU DUʿA (dans le PageView)
// ─────────────────────────────────────────────
class _DuaDetailPage extends StatelessWidget {
  final Map<String, Object?> dua;
  final int index;
  final bool isDark;
  final Color muted;

  const _DuaDetailPage({
    required this.dua,
    required this.index,
    required this.isDark,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final ar = (dua['ar'] as String?)?.trim() ?? '';
    final fr = (dua['fr'] as String?)?.trim() ?? '';
    final en = (dua['en'] as String?)?.trim() ?? '';
    final phonetic = (dua['phonetic'] as String?)?.trim() ?? '';
    final source = (dua['source'] as String?)?.trim() ?? '';
    final explanation = (dua['explanation'] as String?)?.trim() ?? '';
    final repeat = (dua['repeat_count'] as int?) ?? 1;
    final shown = fr.isNotEmpty ? fr : en;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (repeat > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '× $repeat',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                    ),
                  ),
                ),
            ],
          ),
          if (ar.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              ar,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 30,
                height: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (phonetic.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              phonetic,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: muted,
                height: 1.6,
              ),
            ),
          ],
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(shown, style: const TextStyle(fontSize: 16, height: 1.6)),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              explanation,
              style: TextStyle(fontSize: 14, color: muted, height: 1.5),
            ),
          ],
          if (source.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 8),
            Text(
              source,
              style: TextStyle(fontSize: 12, color: muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOUTON AUDIO INLINE (bannière dua du jour)
// ─────────────────────────────────────────────
class _InlineAudioButtonState extends State<_InlineAudioButton> {
  AudioPlayer? _player;
  StreamSubscription? _playerSub;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    _player ??= AudioPlayer();
    if (mounted) setState(() => _loading = true);
    try {
      final dir = await getTemporaryDirectory();
      final safeId = widget.audioUrl.hashCode.abs();
      final file = File('${dir.path}/dua_inline_$safeId.mp3');
      if (!await file.exists()) {
        final response = await Dio().get<List<int>>(
          widget.audioUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'User-Agent': _kAudioUserAgent},
          ),
        );
        await file.writeAsBytes(response.data!);
      }
      await _player!.setAudioSource(
        AudioSource.uri(
          Uri.file(file.path),
          tag: const MediaItem(id: 'dua_inline', title: 'Duʿa'),
        ),
      );
      await _player!.play();
      await _playerSub?.cancel();
      _playerSub = _player!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playing = false);
        }
      });
      if (mounted) setState(() { _playing = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _playing = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Icon(
        _playing ? Icons.stop_rounded : Icons.play_circle_outline_rounded,
        color: _kGreen,
        size: 28,
      ),
    );
  }
}
