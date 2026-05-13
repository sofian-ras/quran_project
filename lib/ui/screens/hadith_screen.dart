import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/hadith.dart';
import '../../services/hadith_db.dart';
import '../../services/hadith_favorites_service.dart';
import 'hadith_detail_screen.dart';
import 'hadith_favorites_screen.dart';
import 'hadith_fullscreen_viewer.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFC8A165);

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  bool _loading = true;
  bool _importing = true;
  String? _error;

  Hadith? _hadithOfDay;
  List<Map<String, dynamic>> _categories = [];
  List<Hadith> _searchResults = [];
  bool _searching = false;

  Set<int> _favorites = {};

  late final AnimationController _gridAnimCtrl;

  @override
  void initState() {
    super.initState();
    _gridAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _gridAnimCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await HadithDb.instance.importFromAssetsIfNeeded();
      final results = await Future.wait([
        HadithDb.instance.getHadithOfDay(),
        HadithDb.instance.getCategories(),
        HadithFavoritesService.instance.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _hadithOfDay = results[0] as Hadith?;
        _categories = results[1] as List<Map<String, dynamic>>;
        _favorites = results[2] as Set<int>;
        _importing = false;
        _loading = false;
      });
      _gridAnimCtrl.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _importing = false;
        });
      }
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await HadithDb.instance.search(q);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _openRandom() async {
    HapticFeedback.lightImpact();
    final h = await HadithDb.instance.getRandomHadith();
    if (h == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HadithDetailScreen(hadith: h)),
    );
  }

  Future<void> _toggleFavorite(int id) async {
    final isNow = await HadithFavoritesService.instance.toggle(id);
    if (!mounted) return;
    setState(() {
      if (isNow) {
        _favorites.add(id);
      } else {
        _favorites.remove(id);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _openHadith(Hadith h) {
    _searchFocusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HadithDetailScreen(hadith: h)),
    );
  }

  void _openCategory(String categoryId, String categoryName, int count) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HadithCategoryScreen(
          categoryId: categoryId,
          categoryName: categoryName,
          count: count,
          favorites: _favorites,
          onToggleFavorite: (id) async {
            final isNow = await HadithFavoritesService.instance.toggle(id);
            if (mounted) {
              setState(() {
                if (isNow) {
                  _favorites.add(id);
                } else {
                  _favorites.remove(id);
                }
              });
            }
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C2333) : const Color(0xFFFAF7F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HadithSettingsSheet(isDark: isDark, gold: _gold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _gold),
              if (_importing) ...[
                const SizedBox(height: 16),
                Text('Chargement des hadiths…', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _init, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 260,
            stretch: true,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black87,
            ),
            actionsIconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black87,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Mes favoris',
                icon: const Icon(Icons.bookmark_rounded, size: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HadithFavoritesScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Paramètres',
                icon: const Icon(Icons.settings_rounded, size: 22),
                onPressed: () => _showSettings(context, isDark),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _AnimatedHadithSearchBar(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  isDark: isDark,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              expandedTitleScale: 1.0,
              titlePadding: const EdgeInsets.only(bottom: 70),
              title: Text(
                'Hadiths',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              collapseMode: CollapseMode.pin,
              background: Stack(
                children: [
                  // Fond dégradé doré → couleur de fond de l'écran en bas
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [const Color(0xFF1A1206), theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor]
                              : [const Color(0xFFF5EDD8), theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor],
                          stops: const [0.0, 0.72, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Halo radial doré
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            _gold.withValues(alpha: isDark ? 0.30 : 0.18),
                            _gold.withValues(alpha: isDark ? 0.08 : 0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Citation centrée dans le flexible space
                  Positioned(
                    top: 78,
                    left: 36,
                    right: 36,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '« Les actes ne valent que par les intentions. »  — Bukhari & Muslim',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Random hadith button
                if (!_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _RandomHadithButton(
                      isDark: isDark,
                      gold: _gold,
                      onTap: _openRandom,
                    ),
                  ),

                if (_searching) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '${_searchResults.length} résultat${_searchResults.length > 1 ? 's' : ''}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                ] else ...[
                  // Hadith du jour
                  if (_hadithOfDay != null) ...[
                    const SizedBox(height: 20),
                    _HadithOfDayCard(
                      hadith: _hadithOfDay!,
                      isFavorite: _favorites.contains(_hadithOfDay!.id),
                      isDark: isDark,
                      gold: _gold,
                      onTap: () => _openHadith(_hadithOfDay!),
                      onToggleFavorite: () => _toggleFavorite(_hadithOfDay!.id),
                    ),
                  ],

                  // Themes section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'Par thème',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_searching)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= _searchResults.length) return const SizedBox(height: 40);
                  final h = _searchResults[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _HadithListTile(
                      hadith: h,
                      isFavorite: _favorites.contains(h.id),
                      isDark: isDark,
                      gold: _gold,
                      onTap: () => _openHadith(h),
                      onToggleFavorite: () => _toggleFavorite(h.id),
                    ),
                  );
                },
                childCount: _searchResults.length + 1,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final cat = _categories[i];
                    final delay = (i * 0.07).clamp(0.0, 0.65);
                    final end = (delay + 0.3).clamp(0.3, 1.0);
                    final interval = Interval(delay, end, curve: Curves.easeOut);
                    return AnimatedBuilder(
                      animation: _gridAnimCtrl,
                      builder: (context, child) {
                        final t = interval.transform(_gridAnimCtrl.value);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - t)),
                            child: child,
                          ),
                        );
                      },
                      child: _CategoryListTile(
                        categoryId: cat['category_id'] as String,
                        categoryName: cat['category_name'] as String,
                        count: cat['count'] as int,
                        isDark: isDark,
                        gold: _gold,
                        onTap: () => _openCategory(
                          cat['category_id'] as String,
                          cat['category_name'] as String,
                          cat['count'] as int,
                        ),
                      ),
                    );
                  },
                  childCount: _categories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared category icons map ──────────────────────────────────────────────────

const _kCategoryIcons = {
  'Actes rituels': Icons.mosque_rounded,
  'Foi': Icons.star_rounded,
  'Comportements': Icons.handshake_rounded,
  'Purification': Icons.water_drop_rounded,
  'Sciences': Icons.menu_book_rounded,
  'Invocations': Icons.favorite_rounded,
};

const _kCategoryImages = {
  'La jurisprudence et son fondement': 'assets/images/hadith_categorie/jurisprudence.webp',
  'Les vertus et les convenances': 'assets/images/hadith_categorie/vertus.webp',
  'Le dogme': 'assets/images/hadith_categorie/dogme.webp',
  'La biographie et l\'histoire': 'assets/images/hadith_categorie/biographie.webp',
  'Le Noble Coran et ses sciences': 'assets/images/hadith_categorie/coran_sciences.webp',
  'La prédication et la police religieuse': 'assets/images/hadith_categorie/predication.webp',
  'Le hadith et ses sciences': 'assets/images/hadith_categorie/hadith_sciences.webp',
};

const _kCategoryDescriptions = {
  'La jurisprudence et son fondement': 'Les règles du culte, des transactions et de la vie quotidienne selon la Sunna.',
  'Les vertus et les convenances': 'Les bonnes mœurs, la politesse islamique et les actes méritoires.',
  'Le dogme': 'Les fondements de la foi, les attributs divins et les piliers de l\'Islam.',
  'La biographie et l\'histoire': 'La vie du Prophète ﷺ, ses Compagnons et les grands événements de l\'Islam.',
  'Le Noble Coran et ses sciences': 'Les mérites de la récitation, les règles du tajwid et l\'exégèse coranique.',
  'La prédication et la police religieuse': 'L\'appel à l\'Islam, le commandement du bien et l\'interdiction du mal.',
  'Le hadith et ses sciences': 'La méthode des savants pour authentifier et transmettre les paroles prophétiques.',
};

IconData _iconForCategory(String name) =>
    _kCategoryIcons.entries
        .where((e) => name.toLowerCase().contains(e.key.toLowerCase()))
        .map((e) => e.value)
        .firstOrNull ??
    Icons.auto_stories_rounded;

// ── Category list tile ─────────────────────────────────────────────────────────

class _CategoryListTile extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final int count;
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;

  const _CategoryListTile({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.isDark,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = _kCategoryImages[categoryName];
    final description = _kCategoryDescriptions[categoryName];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image à gauche — 140px de large
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 140,
                      child: imagePath != null
                          ? Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallback(),
                            )
                          : _buildFallback(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Texte à droite
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF2A1F0E),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$count hadiths',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              height: 1.45,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ),
            Divider(
              height: 24,
              thickness: 0.5,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2218), const Color(0xFF1C1810)]
              : [const Color(0xFFFFF8EE), const Color(0xFFFAF2E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ── Category screen ────────────────────────────────────────────────────────────

class _HadithCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final int count;
  final Set<int> favorites;
  final Future<void> Function(int) onToggleFavorite;

  const _HadithCategoryScreen({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<_HadithCategoryScreen> createState() => _HadithCategoryScreenState();
}

class _HadithCategoryScreenState extends State<_HadithCategoryScreen> {
  static const _gold = Color(0xFFC8A165);
  static const _pageSize = 30;

  final _scrollCtrl = ScrollController();

  List<Hadith> _hadiths = [];
  late Set<int> _favorites;
  int _currentPage = 0;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _favorites = Set.from(widget.favorites);
    _loadPage(0);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    final items = await HadithDb.instance.getByCategory(
      widget.categoryId,
      page: page,
      pageSize: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      if (page == 0) {
        _hadiths = items;
        _initialLoading = false;
      } else {
        _hadiths.addAll(items);
      }
      _currentPage = page;
      _hasMore = items.length == _pageSize;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      setState(() => _loadingMore = true);
      _loadPage(_currentPage + 1);
    }
  }

  Future<void> _toggleFavorite(int id) async {
    await widget.onToggleFavorite(id);
    if (!mounted) return;
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black87,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.categoryName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (_initialLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _gold)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF2A2218), const Color(0xFF1C1810)]
                          : [const Color(0xFFFFF8EE), const Color(0xFFFAF2E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _gold.withValues(alpha: isDark ? 0.2 : 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForCategory(widget.categoryName),
                          color: _gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoryName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.count} hadiths',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i < _hadiths.length) {
                      final h = _hadiths[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 350),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: _HadithListTile(
                            hadith: h,
                            isFavorite: _favorites.contains(h.id),
                            isDark: isDark,
                            gold: _gold,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithFullscreenViewer(
                                  initialHadiths: _hadiths,
                                  initialIndex: i,
                                  totalCount: widget.count,
                                  categoryId: widget.categoryId,
                                  initialFavorites: _favorites,
                                ),
                              ),
                            ),
                            onToggleFavorite: () => _toggleFavorite(h.id),
                          ),
                        ),
                      );
                    }
                    if (_loadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const SizedBox(height: 40);
                  },
                  childCount: _hadiths.length + 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Hadith du jour card ────────────────────────────────────────────────────────

class _HadithOfDayCard extends StatefulWidget {
  final Hadith hadith;
  final bool isFavorite;
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _HadithOfDayCard({
    required this.hadith,
    required this.isFavorite,
    required this.isDark,
    required this.gold,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  State<_HadithOfDayCard> createState() => _HadithOfDayCardState();
}

class _HadithOfDayCardState extends State<_HadithOfDayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _arrowAnim = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hadith = widget.hadith;
    final isFavorite = widget.isFavorite;
    final isDark = widget.isDark;
    final gold = widget.gold;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A2218), const Color(0xFF1C1810)]
                    : [const Color(0xFFFFF8EE), const Color(0xFFFAF2E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Hadith du jour',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            key: ValueKey(isFavorite),
                            color: isFavorite
                                ? gold
                                : (isDark ? Colors.white38 : Colors.black38),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (hadith.title.isNotEmpty) ...[
                    Text(
                      hadith.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE8D5B0)
                            : const Color(0xFF4A3F30),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    hadith.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      height: 2.0,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: gold.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 12),
                  Text(
                    hadith.translation,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.6,
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lire la suite',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedBuilder(
                          animation: _arrowAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_arrowAnim.value, 0),
                            child: child,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, size: 13, color: gold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hadith list tile ───────────────────────────────────────────────────────────

class _HadithListTile extends StatelessWidget {
  final Hadith hadith;
  final bool isFavorite;
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _HadithListTile({
    required this.hadith,
    required this.isFavorite,
    required this.isDark,
    required this.gold,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAF7F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${hadith.id}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                              if (hadith.title.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    hadith.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFFE8D5B0)
                                          : const Color(0xFF4A3F30),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hadith.arabic,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Amiri',
                              fontSize: 15,
                              height: 1.7,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hadith.translation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.5,
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onToggleFavorite,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            key: ValueKey(isFavorite),
                            size: 18,
                            color: isFavorite
                                ? gold
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
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
      ),
    );
  }
}

// ── Settings sheet ─────────────────────────────────────────────────────────────

class _HadithSettingsSheet extends StatefulWidget {
  final bool isDark;
  final Color gold;
  const _HadithSettingsSheet({required this.isDark, required this.gold});

  @override
  State<_HadithSettingsSheet> createState() => _HadithSettingsSheetState();
}

class _HadithSettingsSheetState extends State<_HadithSettingsSheet> {
  double _arabicFontSize = HadithSettings.arabicFontSize;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getDouble('hadith_arabic_font_size');
      if (saved != null && mounted) {
        setState(() => _arabicFontSize = saved);
        HadithSettings.arabicFontSize = saved;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Paramètres',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taille du texte arabe',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: isDark ? Colors.white54 : Colors.black45)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_arabicFontSize.round()} px',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.gold.withValues(alpha: 0.25)),
            ),
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: _arabicFontSize,
                fontWeight: FontWeight.bold,
                height: 1.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _arabicFontSize,
              min: 16, max: 32, divisions: 8,
              activeColor: widget.gold,
              inactiveColor: widget.gold.withValues(alpha: 0.2),
              onChanged: (v) {
                setState(() => _arabicFontSize = v);
                HadithSettings.arabicFontSize = v;
                SharedPreferences.getInstance().then((p) => p.setDouble('hadith_arabic_font_size', v));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A', style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black26, fontSize: 12)),
              Text('A', style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black26, fontSize: 18,
                fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Random hadith button ───────────────────────────────────────────────────────

class _RandomHadithButton extends StatefulWidget {
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;

  const _RandomHadithButton({
    required this.isDark,
    required this.gold,
    required this.onTap,
  });

  @override
  State<_RandomHadithButton> createState() => _RandomHadithButtonState();
}

class _RandomHadithButtonState extends State<_RandomHadithButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Widget _buildQ(double phase, double left, double fontSize) {
    final angle = (_floatCtrl.value + phase) * 2 * math.pi;
    final dy = math.sin(angle) * 5.0;
    final opacity = (0.25 + 0.55 * (math.sin(angle + math.pi / 3) * 0.5 + 0.5))
        .clamp(0.0, 1.0);
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: Text(
              '?',
              style: TextStyle(
                color: widget.gold,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final gold = widget.gold;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2A2218), const Color(0xFF1C1810)]
                  : [const Color(0xFFFFF8EE), const Color(0xFFFAF2E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(FontAwesomeIcons.feather, color: gold, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hadith aléatoire',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE8D5B0)
                            : const Color(0xFF4A3F30),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Découvrir un hadith surprise',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                // Points d'interrogation flottants
                Expanded(
                  child: AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, __) => SizedBox(
                      height: 38,
                      child: Stack(
                        children: [
                          _buildQ(0.00, 8,  11),
                          _buildQ(0.28, 24, 16),
                          _buildQ(0.56, 42, 10),
                        ],
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: gold.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barre de recherche animée ───────────────────────────────────────────────────

class _AnimatedHadithSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _AnimatedHadithSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_AnimatedHadithSearchBar> createState() =>
      _AnimatedHadithSearchBarState();
}

class _AnimatedHadithSearchBarState extends State<_AnimatedHadithSearchBar> {
  static const _gold = _HadithScreenState._gold;

  static const _hints = [
    'le pèlerinage',
    'la prière du soir',
    'le jeûne du ramadan',
    'la patience dans l\'épreuve',
    'les droits du voisin',
    'la miséricorde de Dieu',
    'l\'intention sincère',
    'la zakât',
    'le pardon des péchés',
    'la mort et l\'au-delà',
    'la générosité',
    'l\'humilité du croyant',
    'la purification',
    'les bonnes mœurs',
    'la famille',
  ];

  String _typed = '';
  bool _erasing = false;
  int _hintIndex = 0;
  Timer? _timer;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    // Petite pause initiale avant de commencer
    _timer = Timer(const Duration(milliseconds: 800), _scheduleNext);
  }

  String get _currentHint => _hints[_hintIndex % _hints.length];

  void _scheduleNext() {
    if (!mounted || widget.controller.text.isNotEmpty) return;

    if (!_erasing) {
      if (_typed.length < _currentHint.length) {
        // Vitesse variable : 55-140ms de base
        int delay = 55 + _rng.nextInt(85);
        // Légère pause après un espace (rythme naturel inter-mot)
        if (_typed.isNotEmpty && _typed[_typed.length - 1] == ' ') {
          delay += 60 + _rng.nextInt(60);
        }
        // Rare pause "de réflexion" (1 chance sur 9)
        if (_rng.nextInt(9) == 0) delay += 180 + _rng.nextInt(220);

        _timer = Timer(Duration(milliseconds: delay), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _typed += _currentHint[_typed.length]);
          _scheduleNext();
        });
      } else {
        // Lecture du texte tapé avant d'effacer : 1.8–2.8s
        _timer = Timer(Duration(milliseconds: 1800 + _rng.nextInt(1000)), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _erasing = true);
          _scheduleNext();
        });
      }
    } else {
      if (_typed.isNotEmpty) {
        // Effacement plus rapide que la frappe : 35–60ms
        _timer = Timer(Duration(milliseconds: 35 + _rng.nextInt(25)), () {
          if (!mounted || widget.controller.text.isNotEmpty) return;
          setState(() => _typed = _typed.substring(0, _typed.length - 1));
          _scheduleNext();
        });
      } else {
        // Pause entre deux exemples : 500–900ms
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
          const Icon(Icons.search_rounded, color: _gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Hint frappe animée (caché dès qu'il y a du texte)
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
                        // Curseur clignotant
                        if (!_erasing || _typed.isEmpty)
                          _BlinkingCursor(isDark: isDark),
                      ],
                    );
                  },
                ),
                // TextField vraiment transparent
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
                    cursorColor: _gold,
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
          // Bouton clear
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
                constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final bool isDark;
  const _BlinkingCursor({required this.isDark});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
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
        margin: const EdgeInsets.only(left: 1),
        color: widget.isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }
}

// ── Shared settings ────────────────────────────────────────────────────────────

class HadithSettings {
  static final ValueNotifier<double> arabicFontSizeNotifier = ValueNotifier(22);
  static double get arabicFontSize => arabicFontSizeNotifier.value;
  static set arabicFontSize(double v) => arabicFontSizeNotifier.value = v;
}
