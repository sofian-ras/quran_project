import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/dua_db.dart';

// ─────────────────────────────────────────────
//  CONSTANTES COULEURS
// ─────────────────────────────────────────────
const _kGreen = Color(0xFF4B6B52);
const _kDarkBg = Color(0xFF0B1220);
const _kDarkCard = Color(0xFF111B2E);
const _kLightBg = Color(0xFFF2ECE5);
const _kLightCard = Color(0xFFF6F1EB);

// Palette de 8 dégradés foncés pour les cartes sans image
const _kGradients = [
  [Color(0xFF1A4731), Color(0xFF0D2B1D)],
  [Color(0xFF2D1B4E), Color(0xFF1A0F2E)],
  [Color(0xFF3D2314), Color(0xFF1F0E08)],
  [Color(0xFF1A3A4A), Color(0xFF0D1F28)],
  [Color(0xFF4A1A2D), Color(0xFF2A0D19)],
  [Color(0xFF1A3D1A), Color(0xFF0D2010)],
  [Color(0xFF3A3A1A), Color(0xFF1F1F08)],
  [Color(0xFF1A2D4A), Color(0xFF0D1728)],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
            elevation: 0,
            floating: true,
            snap: true,
            title: const Text(
              'Invocations',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _kGreen,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  cardBg: cardBg,
                  stroke: stroke,
                  onChanged: _onSearchChanged,
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

            // Grille 2 colonnes
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
                    final cat = _cats[i];
                    final id = cat['id'] as String;
                    final chapterId = int.tryParse(id.replaceFirst('c', '')) ?? (i + 1);
                    final titleFr = (cat['title_fr'] as String?)?.trim() ?? '';
                    final titleEn = (cat['title_en'] as String?)?.trim() ?? '';
                    final duaCount = (cat['dua_count'] as int?) ?? 0;
                    final displayTitle = titleFr.isNotEmpty ? titleFr : titleEn;

                    return _CategoryCard(
                      chapterId: chapterId,
                      title: displayTitle,
                      duaCount: duaCount,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DuaCategoryScreen(
                            categoryId: id,
                            titleFr: displayTitle,
                            duaCount: duaCount,
                          ),
                        ));
                      },
                    );
                  },
                  childCount: _cats.length,
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
class _SearchBar extends StatelessWidget {
  final Color cardBg;
  final Color stroke;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.cardBg,
    required this.stroke,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Rechercher une invocation…',
          hintStyle: TextStyle(fontSize: 14),
          prefixIcon: Icon(Icons.search, color: _kGreen, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
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
//  CARTE CATÉGORIE (GRILLE)
// ─────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final int chapterId;
  final String title;
  final int duaCount;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.chapterId,
    required this.title,
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
              // Fond : image ou dégradé
              _CategoryBackground(chapterId: chapterId),

              // Voile sombre bas
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),

              // Contenu
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge nombre de duas (coin haut-droit)
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
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                      maxLines: 3,
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
//  FOND CARTE : IMAGE ou DÉGRADÉ
// ─────────────────────────────────────────────
class _CategoryBackground extends StatelessWidget {
  final int chapterId;

  const _CategoryBackground({required this.chapterId});

  @override
  Widget build(BuildContext context) {
    final colors = _kGradients[chapterId % _kGradients.length];
    return Image.asset(
      'assets/images/dua_categories/chapter_$chapterId.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: const SizedBox.expand(),
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

  const _SearchResultsSliver({
    required this.results,
    required this.isDark,
    required this.cardBg,
    required this.stroke,
    required this.muted,
    required this.textColor,
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
                        style: const TextStyle(fontSize: 16, height: 1.6),
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

  @override
  void initState() {
    super.initState();
    _load();
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
      await _audioPlayer!.setUrl(url);
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
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final dua = _items[i];
                  final id = (dua['id'] as String?) ?? '$i';
                  return Padding(
                    padding: EdgeInsets.fromLTRB(12, i == 0 ? 8 : 0, 12, 10),
                    child: _DuaCard(
                      dua: dua,
                      index: i,
                      isDark: isDark,
                      cardBg: cardBg,
                      stroke: stroke,
                      muted: muted,
                      isPlaying: _playingId == id,
                      isAudioLoading: _audioLoading && _playingId == id,
                      onToggleAudio: () {
                        final url = (dua['audio_url'] as String?)?.trim() ?? '';
                        if (url.isNotEmpty) _toggleAudio(id, url);
                      },
                    ),
                  );
                },
                childCount: _items.length,
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
  final VoidCallback onToggleAudio;

  const _DuaCard({
    required this.dua,
    required this.index,
    required this.isDark,
    required this.cardBg,
    required this.stroke,
    required this.muted,
    required this.isPlaying,
    required this.isAudioLoading,
    required this.onToggleAudio,
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
                style: const TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 22,
                  height: 1.85,
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

            // Bouton audio
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _AudioPlayButton(
                isPlaying: isPlaying,
                isLoading: isAudioLoading,
                onTap: onToggleAudio,
              ),
            ],
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
//  BOUTON AUDIO INLINE (bannière dua du jour)
// ─────────────────────────────────────────────
class _InlineAudioButton extends StatefulWidget {
  final String audioUrl;

  const _InlineAudioButton({required this.audioUrl});

  @override
  State<_InlineAudioButton> createState() => _InlineAudioButtonState();
}

class _InlineAudioButtonState extends State<_InlineAudioButton> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
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
      await _player!.setUrl(widget.audioUrl);
      await _player!.play();
      _player!.playerStateStream.listen((s) {
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
