import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/hadith.dart';
import '../../services/hadith_db.dart';
import '../../services/hadith_favorites_service.dart';
import 'hadith_detail_screen.dart';
import 'hadith_favorites_screen.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  static const _gold = Color(0xFFC8A165);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _importing = false;
  String? _error;

  Hadith? _hadithOfDay;
  List<Map<String, dynamic>> _categories = [];
  List<Hadith> _searchResults = [];
  bool _searching = false;

  Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      setState(() => _importing = true);
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HadithDetailScreen(hadith: h)),
    );
  }

  void _openCategory(String categoryId, String categoryName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HadithCategoryScreen(
          categoryId: categoryId,
          categoryName: categoryName,
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
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Hadiths',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: 'Hadith aléatoire',
                icon: const Icon(Icons.shuffle_rounded, size: 22),
                onPressed: _openRandom,
              ),
              IconButton(
                tooltip: 'Mes favoris',
                icon: const Icon(Icons.bookmark_rounded, size: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HadithFavoritesScreen()),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : const Color(0xFFF2EDE6),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un hadith…',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
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
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final cat = _categories[i];
                    return _CategoryCard(
                      categoryId: cat['category_id'] as String,
                      categoryName: cat['category_name'] as String,
                      count: cat['count'] as int,
                      isDark: isDark,
                      gold: _gold,
                      onTap: () => _openCategory(
                        cat['category_id'] as String,
                        cat['category_name'] as String,
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

// ── Category card ──────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final int count;
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.isDark,
    required this.gold,
    required this.onTap,
  });

  static const _icons = {
    'Actes rituels': Icons.mosque_rounded,
    'Foi': Icons.star_rounded,
    'Comportements': Icons.handshake_rounded,
    'Purification': Icons.water_drop_rounded,
    'Sciences': Icons.menu_book_rounded,
    'Invocations': Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _icons.entries
        .where((e) => categoryName.toLowerCase().contains(e.key.toLowerCase()))
        .map((e) => e.value)
        .firstOrNull ?? Icons.auto_stories_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: gold.withValues(alpha: isDark ? 0.15 : 0.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: gold, size: 26),
              const Spacer(),
              Text(
                categoryName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count hadiths',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category screen ────────────────────────────────────────────────────────────

class _HadithCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Set<int> favorites;
  final Future<void> Function(int) onToggleFavorite;

  const _HadithCategoryScreen({
    required this.categoryId,
    required this.categoryName,
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i < _hadiths.length) {
                      final h = _hadiths[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HadithListTile(
                          hadith: h,
                          isFavorite: _favorites.contains(h.id),
                          isDark: isDark,
                          gold: _gold,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HadithDetailScreen(hadith: h),
                            ),
                          ),
                          onToggleFavorite: () => _toggleFavorite(h.id),
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

class _HadithOfDayCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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
              border: Border.all(color: gold.withValues(alpha: 0.3)),
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
                        onTap: onToggleFavorite,
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
                    child: Text(
                      'Lire la suite →',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: gold,
                        fontWeight: FontWeight.w600,
                      ),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${hadith.id}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hadith.arabic,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Amiri',
                        fontSize: 15,
                        height: 1.6,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.88)
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hadith.translation,
                      maxLines: 2,
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
    );
  }
}
