import 'package:flutter/material.dart';
import '../../models/hadith.dart';
import '../../services/hadith_db.dart';
import '../../services/hadith_favorites_service.dart';
import 'hadith_detail_screen.dart';

class HadithFavoritesScreen extends StatefulWidget {
  const HadithFavoritesScreen({super.key});

  @override
  State<HadithFavoritesScreen> createState() => _HadithFavoritesScreenState();
}

class _HadithFavoritesScreenState extends State<HadithFavoritesScreen> {
  static const _gold = Color(0xFFC8A165);

  List<Hadith> _hadiths = [];
  bool _loading = true;
  final Map<int, int> _versions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = (await HadithFavoritesService.instance.getAll()).toList();
    final hadiths = await HadithDb.instance.getFavoriteHadiths(ids);
    if (mounted) setState(() { _hadiths = hadiths; _loading = false; });
  }

  void _removeFavorite(Hadith h, int index) {
    setState(() => _hadiths.removeAt(index));
    HadithFavoritesService.instance.remove(h.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hadith retiré des favoris'),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF2A2A2A),
        action: SnackBarAction(
          label: 'Annuler',
          textColor: _gold,
          onPressed: () async {
            await HadithFavoritesService.instance.toggle(h.id);
            if (mounted) {
              setState(() {
                _versions[h.id] = (_versions[h.id] ?? 0) + 1;
                _hadiths.insert(index, h);
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1206) : const Color(0xFFF5EDD8),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1206) : const Color(0xFFF5EDD8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : Colors.black87,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            'Hadiths sauvegardés',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hadiths.isEmpty
                ? _EmptyState(isDark: isDark)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _hadiths.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = _hadiths[i];
                      return Dismissible(
                        key: ValueKey('${h.id}_${_versions[h.id] ?? 0}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 36,
                          ),
                        ),
                        onDismissed: (_) => _removeFavorite(h, i),
                        child: _HadithFavoriteCard(
                          hadith: h,
                          gold: _gold,
                          isDark: isDark,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithDetailScreen(hadith: h),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _HadithFavoriteCard extends StatelessWidget {
  final Hadith hadith;
  final Color gold;
  final bool isDark;
  final VoidCallback onTap;

  const _HadithFavoriteCard({
    required this.hadith,
    required this.gold,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFAF7F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hadith.title.isNotEmpty) ...[
                Text(
                  hadith.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              if (hadith.categoryName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hadith.categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      color: gold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                hadith.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  height: 1.8,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hadith.translation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: isDark ? const Color(0xFFC8A165).withValues(alpha: 0.4) : const Color(0xFFC8A165).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun hadith sauvegardé',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
