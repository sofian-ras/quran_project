import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/hadith.dart';
import '../../services/hadith_favorites_service.dart';

class HadithDetailScreen extends StatefulWidget {
  final Hadith hadith;

  const HadithDetailScreen({super.key, required this.hadith});

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  static const _gold = Color(0xFFC8A165);

  bool _isFavorite = false;
  bool _explanationExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final fav = await HadithFavoritesService.instance.isFavorite(widget.hadith.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final isNow = await HadithFavoritesService.instance.toggle(widget.hadith.id);
    if (mounted) setState(() => _isFavorite = isNow);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final h = widget.hadith;

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
            title: h.title.isNotEmpty
                ? Text(
                    h.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            actions: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    key: ValueKey(_isFavorite),
                    color: _isFavorite ? _gold : null,
                    size: 24,
                  ),
                ),
                onPressed: _toggleFavorite,
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hadith number badge ────────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _gold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Hadith N° ${h.id}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _gold,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Arabic text block ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      h.arabic.isNotEmpty ? h.arabic : '—',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontFamily: 'Amiri',
                        fontSize: 22,
                        height: 2.0,
                        color: isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Divider with label ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: _gold.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Traduction',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _gold,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: _gold.withValues(alpha: 0.3))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── French translation ─────────────────────────────────────
                  Text(
                    h.translation.isNotEmpty ? h.translation : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.8,
                      fontSize: 15,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF2D2D2D),
                    ),
                  ),

                  // ── Explanation (collapsible) ──────────────────────────────
                  if (h.explanation.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _explanationExpanded = !_explanationExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _explanationExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: _gold,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Explication',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _gold,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _explanationExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF5F0E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            h.explanation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.7,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0xFF555555),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
