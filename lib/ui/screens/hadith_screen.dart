import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            elevation: 0,
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
              IconButton(
                tooltip: 'Paramètres',
                icon: const Icon(Icons.settings_rounded, size: 22),
                onPressed: () => _showSettings(context, isDark),
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
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                      cursorColor: _gold,
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
                  childAspectRatio: 1.1,
                ),
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
                      child: _CategoryCard(
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

IconData _iconForCategory(String name) =>
    _kCategoryIcons.entries
        .where((e) => name.toLowerCase().contains(e.key.toLowerCase()))
        .map((e) => e.value)
        .firstOrNull ??
    Icons.auto_stories_rounded;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForCategory(categoryName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: gold.withValues(alpha: isDark ? 0.2 : 0.25),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: gold, size: 20),
              ),
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$count hadiths',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: gold.withValues(alpha: 0.6),
                  ),
                ],
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

// ── Shared settings ────────────────────────────────────────────────────────────

class HadithSettings {
  static final ValueNotifier<double> arabicFontSizeNotifier = ValueNotifier(22);
  static double get arabicFontSize => arabicFontSizeNotifier.value;
  static set arabicFontSize(double v) => arabicFontSizeNotifier.value = v;
}
