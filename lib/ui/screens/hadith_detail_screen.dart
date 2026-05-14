import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/hadith.dart';
import '../../services/hadith_favorites_service.dart';
import 'hadith_screen.dart' show HadithSettings;
import 'hadith_fullscreen_viewer.dart';

class HadithDetailScreen extends StatefulWidget {
  final Hadith hadith;

  const HadithDetailScreen({super.key, required this.hadith});

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFC8A165);

  bool _isFavorite = false;
  bool _explanationExpanded = false;

  late final AnimationController _animCtrl;

  late final Animation<double> _fadeBadges;
  late final Animation<Offset> _slideBadges;
  late final Animation<double> _fadeArabic;
  late final Animation<double> _scaleArabic;
  late final Animation<double> _fadeDivider;
  late final Animation<double> _fadeTranslation;
  late final Animation<Offset> _slideTranslation;
  late final Animation<double> _fadeExplanation;

  @override
  void initState() {
    super.initState();
    _explanationExpanded = widget.hadith.explanation.length < 300;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeBadges = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _slideBadges = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _fadeArabic = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );
    _scaleArabic = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );

    _fadeDivider = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
    );

    _fadeTranslation = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.4, 0.78, curve: Curves.easeOut),
    );
    _slideTranslation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.4, 0.78, curve: Curves.easeOut),
    ));

    _fadeExplanation = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _animCtrl.forward();
    _loadFavoriteState();
    HadithFavoritesService.instance.notifier.addListener(_onFavoritesChanged);
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {
        _isFavorite = HadithFavoritesService.instance.notifier.value
            .contains(widget.hadith.id);
      });
    }
  }

  @override
  void dispose() {
    HadithFavoritesService.instance.notifier.removeListener(_onFavoritesChanged);
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteState() async {
    final fav =
        await HadithFavoritesService.instance.isFavorite(widget.hadith.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final isNow = await HadithFavoritesService.instance.toggle(widget.hadith.id);
    if (mounted) setState(() => _isFavorite = isNow);
    HapticFeedback.lightImpact();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HadithFullscreenViewer(
          initialHadiths: [widget.hadith],
          initialIndex: 0,
          totalCount: 1,
          initialFavorites: _isFavorite ? {widget.hadith.id} : {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final h = widget.hadith;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1206) : const Color(0xFFF5EDD8),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1206), const Color(0xFF261B0C)]
                : [const Color(0xFFF5EDD8), const Color(0xFFEDE0C4)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF1A1206) : const Color(0xFFF5EDD8),
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
                tooltip: 'Plein écran',
                icon: const Icon(Icons.open_in_full_rounded, size: 20),
                onPressed: _openFullscreen,
              ),
              IconButton(
                tooltip: 'Partager',
                icon: const Icon(Icons.share_rounded, size: 22),
                onPressed: () {
                  Share.share(
                    '${h.arabic}\n\n${h.translation}\n\n— Hadith N°${h.id}',
                  );
                },
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isFavorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
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
                  // Badges
                  FadeTransition(
                    opacity: _fadeBadges,
                    child: SlideTransition(
                      position: _slideBadges,
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _gold.withValues(alpha: 0.4)),
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
                            if (h.categoryName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _gold.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  h.categoryName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF6B5A45),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (h.title.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _fadeBadges,
                      child: SlideTransition(
                        position: _slideBadges,
                        child: Text(
                          h.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE8D5B0)
                                : const Color(0xFF4A3F30),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Arabic text
                  FadeTransition(
                    opacity: _fadeArabic,
                    child: ScaleTransition(
                      scale: _scaleArabic,
                      child: ValueListenableBuilder<double>(
                        valueListenable: HadithSettings.arabicFontSizeNotifier,
                        builder: (context, fontSize, _) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 14),
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
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              height: 1.8,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  FadeTransition(
                    opacity: _fadeDivider,
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: _gold.withValues(alpha: 0.3))),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Traduction',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _gold,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: _gold.withValues(alpha: 0.3))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Translation
                  FadeTransition(
                    opacity: _fadeTranslation,
                    child: SlideTransition(
                      position: _slideTranslation,
                      child: Text(
                        h.translation.isNotEmpty ? h.translation : '—',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.8,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.85)
                              : const Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                  ),

                  // Explanation
                  if (h.explanation.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeExplanation,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _explanationExpanded = !_explanationExpanded),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF5F0E8),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(color: _gold, width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Explication',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _gold,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _explanationExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: _gold,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _explanationExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF5F0E8),
                                  borderRadius: BorderRadius.circular(10),
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
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
