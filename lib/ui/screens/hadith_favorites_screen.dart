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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Hadiths sauvegardés'),
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
                    return _HadithFavoriteCard(
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
                    );
                  },
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
              if (hadith.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    hadith.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
            Icons.bookmark_border_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
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
