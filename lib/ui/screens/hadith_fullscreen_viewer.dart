import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/hadith.dart';
import '../../services/hadith_db.dart';
import '../../services/hadith_favorites_service.dart';
import 'hadith_screen.dart' show HadithSettings;

class HadithFullscreenViewer extends StatefulWidget {
  final List<Hadith> initialHadiths;
  final int initialIndex;
  final int totalCount;
  final String? categoryId;
  final Set<int> initialFavorites;

  const HadithFullscreenViewer({
    super.key,
    required this.initialHadiths,
    required this.initialIndex,
    required this.totalCount,
    this.categoryId,
    this.initialFavorites = const {},
  });

  @override
  State<HadithFullscreenViewer> createState() => _HadithFullscreenViewerState();
}

class _HadithFullscreenViewerState extends State<HadithFullscreenViewer> {
  static const _gold = Color(0xFFC8A165);
  static const _pageSize = 30;

  late final PageController _pageCtrl;
  final Map<int, Hadith> _cache = {};
  final Set<int> _loadingDbPages = {};
  late Set<int> _favorites;

  int _currentIndex = 0;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _favorites = Set.from(widget.initialFavorites);
    _pageCtrl = PageController(initialPage: widget.initialIndex);

    for (var i = 0; i < widget.initialHadiths.length; i++) {
      _cache[i] = widget.initialHadiths[i];
    }

    _ensureLoaded(widget.initialIndex);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    setState(() => _controlsVisible = true);
    _startHideTimer();
    _ensureLoaded(index);
  }

  void _ensureLoaded(int index) {
    for (final i in [index - 1, index, index + 1, index + 2]) {
      if (i < 0 || i >= widget.totalCount) continue;
      if (_cache.containsKey(i)) continue;
      _fetchBatch(i);
    }
  }

  Future<void> _fetchBatch(int index) async {
    final dbPage = index ~/ _pageSize;
    if (_loadingDbPages.contains(dbPage)) return;
    _loadingDbPages.add(dbPage);

    try {
      final List<Hadith> items;
      if (widget.categoryId != null) {
        items = await HadithDb.instance.getByCategory(
          widget.categoryId!,
          page: dbPage,
          pageSize: _pageSize,
        );
      } else {
        items = await HadithDb.instance.getPage(dbPage, pageSize: _pageSize);
      }
      if (!mounted) return;
      setState(() {
        final startIdx = dbPage * _pageSize;
        for (var i = 0; i < items.length; i++) {
          _cache[startIdx + i] = items[i];
        }
      });
    } finally {
      _loadingDbPages.remove(dbPage);
    }
  }

  Future<void> _toggleFavorite(int id) async {
    HapticFeedback.lightImpact();
    final isNow = await HadithFavoritesService.instance.toggle(id);
    if (!mounted) return;
    setState(() {
      if (isNow) {
        _favorites.add(id);
      } else {
        _favorites.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = widget.totalCount;
    final currentHadith = _cache[_currentIndex];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── PageView ──────────────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _HadithPage(
                key: ValueKey(index),
                hadith: _cache[index],
                isFavorite: _cache[index] != null &&
                    _favorites.contains(_cache[index]!.id),
                isDark: isDark,
                gold: _gold,
                onTapBackground: _toggleControls,
              );
            },
          ),

          // ── Top controls ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        _OverlayButton(
                          isDark: isDark,
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              key: ValueKey(currentHadith?.categoryName ?? ''),
                              currentHadith?.categoryName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Container(
                            key: ValueKey(_currentIndex),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / $total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentHadith != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _OverlayButton(
                                isDark: isDark,
                                onTap: () {
                                  final h = currentHadith;
                                  Share.share(
                                    '${h.arabic}\n\n${h.translation}\n\n— Hadith N°${h.id}',
                                  );
                                },
                                child: Icon(
                                  Icons.share_rounded,
                                  size: 19,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _FavoriteButton(
                                isFavorite: _favorites.contains(currentHadith.id),
                                gold: _gold,
                                isDark: isDark,
                                onTap: () =>
                                    _toggleFavorite(currentHadith.id),
                              ),
                            ],
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        child: LinearProgressIndicator(
                          value: total > 0 ? (_currentIndex + 1) / total : 0,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_gold),
                          minHeight: 3,
                        ),
                      ),
                    ],
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

// ── Individual hadith page ─────────────────────────────────────────────────────

class _HadithPage extends StatefulWidget {
  final Hadith? hadith;
  final bool isFavorite;
  final bool isDark;
  final Color gold;
  final VoidCallback onTapBackground;

  const _HadithPage({
    super.key,
    required this.hadith,
    required this.isFavorite,
    required this.isDark,
    required this.gold,
    required this.onTapBackground,
  });

  @override
  State<_HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<_HadithPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _explanationExpanded = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    if (widget.hadith != null) {
      _explanationExpanded = widget.hadith!.explanation.length < 300;
      _animCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_HadithPage old) {
    super.didUpdateWidget(old);
    if (old.hadith == null && widget.hadith != null) {
      _explanationExpanded = widget.hadith!.explanation.length < 300;
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = widget.hadith;

    if (h == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8A165)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: widget.onTapBackground,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 64,
              20,
              MediaQuery.of(context).padding.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Badges
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: widget.gold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Hadith N° ${h.id}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: widget.gold,
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
                            color: widget.gold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: widget.gold.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            h.categoryName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.isDark
                                  ? Colors.white60
                                  : const Color(0xFF6B5A45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (h.title.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    h.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? const Color(0xFFE8D5B0)
                          : const Color(0xFF4A3F30),
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Arabic text
                ValueListenableBuilder<double>(
                  valueListenable: HadithSettings.arabicFontSizeNotifier,
                  builder: (context, fontSize, _) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 20),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: widget.gold.withValues(alpha: 0.2)),
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
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.92)
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(
                        child:
                            Divider(color: widget.gold.withValues(alpha: 0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Traduction',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.gold,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                        child:
                            Divider(color: widget.gold.withValues(alpha: 0.3))),
                  ],
                ),

                const SizedBox(height: 16),

                // Translation
                Text(
                  h.translation.isNotEmpty ? h.translation : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.8,
                    fontSize: 15,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF2D2D2D),
                  ),
                ),

                // Explanation
                if (h.explanation.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => setState(
                        () => _explanationExpanded = !_explanationExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                            left: BorderSide(color: widget.gold, width: 3)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Explication',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: widget.gold,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _explanationExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: widget.gold,
                            size: 20,
                          ),
                        ],
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
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF5F0E8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                h.explanation,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.7,
                                  fontSize: 13,
                                  color: widget.isDark
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
      ),
    );
  }
}

// ── Reusable overlay button ────────────────────────────────────────────────────

class _OverlayButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;

  const _OverlayButton({
    required this.isDark,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

// ── Favorite button with scale animation ──────────────────────────────────────

class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final Color gold;
  final bool isDark;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.gold,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.72), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.25), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 20),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: widget.isFavorite
                ? widget.gold.withValues(alpha: 0.2)
                : widget.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              widget.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              key: ValueKey(widget.isFavorite),
              size: 19,
              color: widget.isFavorite
                  ? widget.gold
                  : widget.isDark
                      ? Colors.white70
                      : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
