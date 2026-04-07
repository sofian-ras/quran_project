import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/radio_station.dart';
import '../../services/audio_service.dart';
import '../../services/radio_service.dart';
import 'radio_player_screen.dart';

// ── Public: categories + categorize ──────────────────────────────────────────

const kRadioCategories = <String>[
  'Tous',
  '📖 Coran',
  '👤 Récitateurs',
  '📚 Tafsir',
  '🕌 Conférences',
  '🤲 Adhkar & Doua',
  '🙏 Du\'a',
  '🎓 Apprentissage',
  '🌍 Traductions',
];

const _kCatGradients = <String, List<Color>>{
  '📖 Coran':         [Color(0xFF0E7B70), Color(0xFF054940)],
  '👤 Récitateurs':   [Color(0xFF1E4494), Color(0xFF0D2560)],
  '📚 Tafsir':        [Color(0xFF6B35A8), Color(0xFF3D1472)],
  '🕌 Conférences':   [Color(0xFF9B3232), Color(0xFF601515)],
  '🤲 Adhkar & Doua': [Color(0xFF1A8A68), Color(0xFF0D5240)],
  '🙏 Du\'a':         [Color(0xFF6B3580), Color(0xFF35104A)],
  '🎓 Apprentissage': [Color(0xFF9A7020), Color(0xFF60430D)],
  '🌍 Traductions':   [Color(0xFF1A7A6B), Color(0xFF0D4A40)],
};

List<Color> radioCategoryGradient(String cat) =>
    _kCatGradients[cat] ?? [const Color(0xFF0E7B70), const Color(0xFF054940)];

String categorizeStation(RadioStation s) {
  final n = s.name.toLowerCase();
  if (n.contains('translat') || n.contains('traduct') ||
      n.contains('english') || n.contains('french') ||
      n.contains('français') || n.contains('urdu') ||
      n.contains('türk') || n.contains('indonesia') ||
      n.contains('swahili') || n.contains('bangla')) { return '🌍 Traductions'; }
  if (n.contains('tafsir') || n.contains('تفسير') ||
      n.contains('interpré') || n.contains('interpret') ||
      n.contains('résumé') || n.contains('resume') || n.contains('mukhtasar') ||
      n.contains('biographie') || n.contains('sira') || n.contains('sirat') ||
      n.contains('nabawi') || n.contains('سيرة') || n.contains('نبوي') ||
      n.contains('sahih') || n.contains('bukhari') || n.contains('bukhary') ||
      n.contains('histoir') || n.contains('قصص') ||
      n.contains('compagnon') || n.contains('sahaba') || n.contains('صحابة') ||
      n.contains('fatwa') || n.contains('فتوى') || n.contains('فتاوى') ||
      n.contains('muslim') || n.contains('مسلم')) { return '📚 Tafsir'; }
  if (n.contains('dua') || n.contains('du\'a') || n.contains('دعاء') ||
      n.contains('أدعية') || n.contains('supplication') ||
      n.contains('روحاني') || n.contains('روقية') || n.contains('ruqyah') ||
      n.contains('ruqia')) { return '🙏 Du\'a'; }
  if (n.contains('adhkar') || n.contains('أذكار') || n.contains('dhikr') ||
      n.contains('ذكر') || n.contains('wird') || n.contains('ورد')) {
    return '🤲 Adhkar & Doua';
  }
  if (n.contains('conférence') || n.contains('conference') ||
      n.contains('khutba') || n.contains('خطبة') ||
      n.contains('dars') || n.contains('درس') ||
      n.contains('cours') || n.contains('leçon') ||
      n.contains('lecture') || n.contains('محاضرة')) { return '🕌 Conférences'; }
  if (n.contains('learn') || n.contains('kids') || n.contains('enfant') ||
      n.contains('tajwid') || n.contains('tajweed') || n.contains('تجويد') ||
      n.contains('hifz') || n.contains('حفظ') || n.contains('mémoris')) {
    return '🎓 Apprentissage';
  }
  if (n.contains('récitat') || n.contains('recit') || n.contains('tilawa') ||
      n.contains('تلاوة') || n.contains('qari') || n.contains('قارئ') ||
      n.contains('mujawwad') || n.contains('murattal')) { return '👤 Récitateurs'; }
  return '📖 Coran';
}

String _stationLabel(RadioStation s) {
  final dn = s.displayName;
  if (dn.length <= 26) return dn;
  // right-truncate → keeps the language at the end visible
  final lower = dn.toLowerCase();
  final idx = lower.indexOf('traduct');
  final idx2 = lower.indexOf('translat');
  final cut = (idx >= 0) ? idx : (idx2 >= 0 ? idx2 : -1);
  if (cut >= 0) {
    final tail = dn.substring(cut);
    return tail.length > 24 ? '…${tail.substring(tail.length - 24)}' : tail;
  }
  return '…${dn.substring(dn.length - 24)}';
}

// ── Screen ────────────────────────────────────────────────────────────────────

class RadioBrowserScreen extends StatefulWidget {
  const RadioBrowserScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => const RadioBrowserScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  State<RadioBrowserScreen> createState() => _RadioBrowserScreenState();
}

class _RadioBrowserScreenState extends State<RadioBrowserScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabCtrl;
  int _tabIndex = 0;

  final _homeScroll      = ScrollController();
  final _parcourirScroll = ScrollController();
  final _favorisScroll   = ScrollController();

  List<RadioStation> _stations  = [];
  List<RadioStation> _recents   = [];
  List<RadioStation> _popular   = [];
  List<RadioStation> _favorites = [];
  bool    _loading = true;
  String? _error;
  String  _selectedCategory = 'Tous';
  final   _searchCtrl  = TextEditingController();
  final   _searchFocus = FocusNode();
  Timer?  _searchDebounce;
  bool    _navigating = false;

  Map<String, List<RadioStation>> _grouped          = {};
  List<String>                    _activeCategories = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        if (mounted) setState(() => _tabIndex = _tabCtrl.index);
      }
      if (_tabCtrl.index != 1) FocusScope.of(context).unfocus();
    });
    _searchCtrl.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() {});
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _homeScroll.dispose();
    _parcourirScroll.dispose();
    _favorisScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        RadioService.instance.getStations(),
        RadioService.instance.getRecents(),
        RadioService.instance.getPopular(limit: 12),
        RadioService.instance.getFavorites(),
      ]);
      if (!mounted) return;
      setState(() {
        _stations  = results[0];
        _recents   = results[1];
        _popular   = results[2];
        _favorites = results[3];
        _loading   = false;
        _rebuildGrouped();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = 'Impossible de charger les stations.\nVérifiez votre connexion.';
        _loading = false;
      });
    }
  }

  Future<void> _reloadFavorites() async {
    final favs = await RadioService.instance.getFavorites();
    if (mounted) setState(() => _favorites = favs);
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  List<RadioStation> get _searchFiltered {
    final q = _searchCtrl.text.toLowerCase().trim();
    return _stations
        .where((s) => s.displayName.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q))
        .toList();
  }

  void _rebuildGrouped() {
    _grouped = { for (final c in kRadioCategories.skip(1)) c: [] };
    for (final s in _stations) { _grouped[categorizeStation(s)]!.add(s); }
    final present = _stations.map(categorizeStation).toSet();
    _activeCategories = kRadioCategories
        .where((c) => c == 'Tous' || present.contains(c))
        .toList();
  }

  void _play(RadioStation station) {
    if (_navigating) return;
    HapticFeedback.mediumImpact();
    final alreadyPlaying =
        RadioService.instance.currentStationNotifier.value?.id == station.id;
    if (!alreadyPlaying) {
      AudioService.instance.playRadio(station);
      RadioService.instance.currentStationNotifier.value = station;
      RadioService.instance.trackPlay(station);
    }
    _searchFocus.unfocus();
    _navigating = true;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => RadioPlayerScreen(station: station),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    ).then((_) {
      _navigating = false;
      _reloadFavorites();
    });
  }

  Future<void> _toggleFavFromList(RadioStation s) async {
    await RadioService.instance.toggleFavorite(s);
    await _reloadFavorites();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF080D1A) : const Color(0xFFF5F0E8);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Immersive radial glow (dark mode only)
          if (isDark) ...[
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 300, height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color(0x1238C172),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: 40, left: -100,
              child: Container(
                width: 240, height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color(0x0A1E4494),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
          Column(
            children: [
              _buildHeader(isDark),
              _buildTabBar(isDark),
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: Color(0xFF38C172), strokeWidth: 2),
                            const SizedBox(height: 14),
                            Text('Chargement…',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF8899BB)
                                      : const Color(0xFF9CA3AF),
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      )
                    : _error != null
                        ? _buildError(isDark)
                        : TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _buildHomeTab(isDark),
                              _buildParcourirTab(isDark),
                              _buildFavorisTab(isDark),
                            ],
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textColor, size: 20),
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                'Radio Quran',
                style: TextStyle(
                  color: textColor, fontSize: 20,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3,
                ),
              ),
            ),
            // Now-playing pill
            ValueListenableBuilder<RadioStation?>(
              valueListenable: RadioService.instance.currentStationNotifier,
              builder: (_, station, __) {
                if (station == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    if (_navigating) return;
                    _navigating = true;
                    _searchFocus.unfocus();
                    Navigator.of(context, rootNavigator: true).push(
                    PageRouteBuilder<void>(
                      opaque: true,
                      pageBuilder: (_, __, ___) =>
                          RadioPlayerScreen(station: station),
                      transitionsBuilder: (_, anim, __, child) =>
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: anim, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  ).then((_) {
                    _navigating = false;
                    _reloadFavorites();
                  });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38C172).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF38C172).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF38C172),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            station.displayName,
                            style: const TextStyle(
                              color: Color(0xFF38C172), fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Pill tab bar ───────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    final bg      = isDark ? const Color(0xFF0E1530) : const Color(0xFFECE7DF);
    final pillBg  = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final unsel   = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: LayoutBuilder(builder: (_, constraints) {
        final pillW = constraints.maxWidth / 3;
        return AnimatedBuilder(
          animation: _tabCtrl.animation!,
          builder: (_, __) {
            final pos = _tabCtrl.animation!.value;
            return SizedBox(
              height: 40,
              child: Stack(
                children: [
                  // Track
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  // Sliding pill — suit le doigt en temps réel
                  Positioned(
                    left: pillW * pos,
                    top: 0,
                    width: pillW,
                    height: 40,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38C172), Color(0xFF1DA355)],
                        ),
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38C172).withValues(alpha: 0.35),
                            blurRadius: 10, offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Labels
                  Row(
                    children: List.generate(3, (i) {
                      final sel  = _tabIndex == i;
                      final icon = i == 2 ? Icons.favorite_rounded : null;
                      final label = ['Accueil', 'Parcourir', 'Favoris'][i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _tabIndex = i);
                          _tabCtrl.animateTo(i);
                          if (i != 1) FocusScope.of(context).unfocus();
                        },
                        child: SizedBox(
                          width: pillW,
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 13,
                                    color: sel ? Colors.white : unsel),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? Colors.white : unsel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: mutedColor, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor, fontSize: 14)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38C172)),
              label: const Text('Réessayer',
                  style: TextStyle(color: Color(0xFF38C172))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onglet Accueil ─────────────────────────────────────────────────────────

  Widget _buildHomeTab(bool isDark) {
    final grouped   = _grouped;
    final recentIds = _recents.map((s) => s.id).toSet();
    final discover  = _stations
        .where((s) => !recentIds.contains(s.id))
        .take(12).toList();

    final slivers = <Widget>[];

    // Hero "En cours de lecture"
    slivers.add(SliverToBoxAdapter(
      child: _NowPlayingHero(isDark: isDark, onTap: _play),
    ));

    if (_recents.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(emoji: '🕐', title: 'Récents', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(stations: _recents, onTap: _play)));
    }

    if (_popular.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(emoji: '🔥', title: 'Populaires', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(stations: _popular, onTap: _play)));
    }

    if (discover.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(emoji: '✨', title: 'Découvrir', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(stations: discover, onTap: _play)));
    }

    // Catégories si rien de personnalisé
    if (_recents.isEmpty && _popular.isEmpty) {
      for (final cat in kRadioCategories.skip(1)) {
        final list = grouped[cat] ?? [];
        if (list.isEmpty) continue;
        final spaceIdx = cat.indexOf(' ');
        slivers
          ..add(SliverToBoxAdapter(
              child: _SectionTitle(
                  emoji: spaceIdx > 0 ? cat.substring(0, spaceIdx) : '',
                  title: spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat,
                  isDark: isDark,
                  accentColor: radioCategoryGradient(cat).first)))
          ..add(SliverToBoxAdapter(
              child: _HomeCardRow(
                  stations: list.take(6).toList(), onTap: _play)));
      }
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

    if (slivers.length == 2) {
      // Only hero + padding → no stations
      return Center(
        child: Text('Aucune station disponible',
            style: TextStyle(
                color: isDark
                    ? const Color(0xFF8899BB)
                    : const Color(0xFF9CA3AF))),
      );
    }

    return CustomScrollView(controller: _homeScroll, slivers: slivers);
  }

  // ── Onglet Parcourir ───────────────────────────────────────────────────────

  Widget _buildParcourirTab(bool isDark) {
    final fillColor = isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);
    final hintColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher une station…',
              hintStyle: TextStyle(color: hintColor, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: hintColor, size: 20),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: hintColor, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                      padding: EdgeInsets.zero,
                    )
                  : null,
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Content
        Expanded(
          child: _isSearching
              ? _buildSearchResults(isDark)
              : _selectedCategory == 'Tous'
                  ? _CategoryGrid(
                      isDark: isDark,
                      categories: _activeCategories
                          .where((c) => c != 'Tous')
                          .toList(),
                      grouped: _grouped,
                      onSelect: (cat) =>
                          setState(() => _selectedCategory = cat),
                    )
                  : _buildCategoryList(isDark),
        ),
      ],
    );
  }

  Widget _buildSearchResults(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    final results = _searchFiltered;
    if (results.isEmpty) {
      return Center(
          child: Text('Aucune station trouvée',
              style: TextStyle(color: mutedColor)));
    }
    return ListView.builder(
      controller: _parcourirScroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      itemBuilder: (_, i) => _StationTile(
        station: results[i],
        isDark: isDark,
        onTap: () => _play(results[i]),
        onFavTap: () => _toggleFavFromList(results[i]),
        isFav: _favorites.any((f) => f.id == results[i].id),
        index: i,
      ),
    );
  }

  Widget _buildCategoryList(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    final textColor =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final cat  = _selectedCategory;
    final list = _grouped[cat] ?? [];
    final grad = radioCategoryGradient(cat);
    final spaceIdx = cat.indexOf(' ');
    final catLabel = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;
    final catEmoji = spaceIdx > 0 ? cat.substring(0, spaceIdx) : '';

    if (list.isEmpty) {
      return Center(
          child: Text('Aucune station dans cette catégorie',
              style: TextStyle(color: mutedColor)));
    }

    return Column(
      children: [
        // Back + category header
        GestureDetector(
          onTap: () => setState(() => _selectedCategory = 'Tous'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  grad[0].withValues(alpha: 0.18),
                  grad[1].withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: grad[0].withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: grad[0]),
                const SizedBox(width: 8),
                if (catEmoji.isNotEmpty) ...[
                  Text(catEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                ],
                Text(
                  catLabel,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${list.length} stations',
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _parcourirScroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) => _StationTile(
              station: list[i],
              isDark: isDark,
              onTap: () => _play(list[i]),
              onFavTap: () => _toggleFavFromList(list[i]),
              isFav: _favorites.any((f) => f.id == list[i].id),
              index: i,
            ),
          ),
        ),
      ],
    );
  }

  // ── Onglet Favoris ─────────────────────────────────────────────────────────

  Widget _buildFavorisTab(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);

    if (_favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, color: mutedColor, size: 52),
              const SizedBox(height: 16),
              Text(
                'Aucun favori pour l\'instant',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFFEAF2FF)
                        : const Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Touchez le cœur sur une station\npour l\'ajouter ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _favorisScroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _favorites.length,
      itemBuilder: (_, i) {
        final s = _favorites[i];
        return _StationTile(
          station: s,
          isDark: isDark,
          onTap: () => _play(s),
          onFavTap: () => _toggleFavFromList(s),
          isFav: true,
          index: i,
        );
      },
    );
  }
}

// ── Hero "En cours de lecture" ────────────────────────────────────────────────

class _NowPlayingHero extends StatelessWidget {
  final bool isDark;
  final void Function(RadioStation) onTap;

  const _NowPlayingHero({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, station, __) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          ),
          child: station == null
              ? const SizedBox.shrink()
              : _HeroCard(
                  key: ValueKey(station.id),
                  station: station,
                  isDark: isDark,
                  onTap: () => onTap(station),
                ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final RadioStation station;
  final bool isDark;
  final VoidCallback onTap;

  const _HeroCard({
    super.key,
    required this.station,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat  = categorizeStation(station);
    final grad = radioCategoryGradient(cat);
    final spaceIdx = cat.indexOf(' ');
    final catLabel = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              grad[0].withValues(alpha: 0.9),
              grad[1].withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: grad[0].withValues(alpha: 0.4),
              blurRadius: 20, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            // Thumbnail
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: StationThumbnail(station: station, size: 62, circular: true),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LIVE badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EN DIRECT',
                      style: TextStyle(
                        color: Colors.white, fontSize: 8,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _stationLabel(station),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    catLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Play/pause + arrow
            const _EqualizerBars(color: Colors.white),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 22),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final bool   isDark;
  final Color? accentColor;

  const _SectionTitle({
    required this.emoji,
    required this.title,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final lineColor = accentColor ??
        (isDark ? const Color(0xFF38C172) : const Color(0xFF6EE7B7));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
          ],
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal home cards (16:9) ──────────────────────────────────────────────

class _HomeCardRow extends StatelessWidget {
  final List<RadioStation>          stations;
  final void Function(RadioStation) onTap;

  const _HomeCardRow({required this.stations, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _HomeCard(
          station: stations[i],
          onTap: () => onTap(stations[i]),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final RadioStation station;
  final VoidCallback onTap;

  const _HomeCard({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        final cat  = categorizeStation(station);
        final grad = radioCategoryGradient(cat);

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: grad[0].withValues(alpha: 0.5),
                    blurRadius: 16, spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full image
                  Hero(
                    tag: 'radio_thumb_${station.id}',
                    child: StationThumbnail(station: station, size: 128, circular: false),
                  ),
                  // Gradient overlay bottom
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 68,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.82),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Active border glow
                  if (isActive)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF38C172), width: 2.5),
                        ),
                      ),
                    ),
                  // Name + equalizer
                  Positioned(
                    left: 9, right: 9, bottom: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            _stationLabel(station),
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF38C172)
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 4),
                          const _EqualizerBars(color: Color(0xFF38C172)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Category grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final bool                              isDark;
  final List<String>                      categories;
  final Map<String, List<RadioStation>>   grouped;
  final void Function(String)             onSelect;

  const _CategoryGrid({
    required this.isDark,
    required this.categories,
    required this.grouped,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) => _CategoryCard(
        cat: categories[i],
        count: grouped[categories[i]]?.length ?? 0,
        onTap: () => onSelect(categories[i]),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String cat;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.cat,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grad = radioCategoryGradient(cat);
    final spaceIdx = cat.indexOf(' ');
    final emoji = spaceIdx > 0 ? cat.substring(0, spaceIdx) : '';
    final label = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;

    final catAsset = kCatAssets[cat] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: grad[0].withValues(alpha: 0.35),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de catégorie en fond
              if (catAsset.isNotEmpty)
                Image.asset(catAsset, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                    ))
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: grad,
                    ),
                  ),
                ),
              // Overlay gradient pour lisibilité
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      grad[0].withValues(alpha: 0.60),
                      grad[1].withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count stations',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
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

// ── Station tile (list row) ───────────────────────────────────────────────────

class _StationTile extends StatelessWidget {
  final RadioStation station;
  final bool         isDark;
  final VoidCallback onTap;
  final VoidCallback onFavTap;
  final bool         isFav;
  final int          index;

  const _StationTile({
    required this.station,
    required this.isDark,
    required this.onTap,
    required this.onFavTap,
    required this.isFav,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final textMuted =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final cat = categorizeStation(station);
    final spaceIdx = cat.indexOf(' ');
    final catLabel = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;
    final grad = radioCategoryGradient(cat);

    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 280 + index * 40),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  // Thumbnail with category glow when active
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: grad[0].withValues(alpha: 0.55),
                                blurRadius: 14, spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Hero(
                      tag: 'radio_thumb_${station.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: StationThumbnail(
                            station: station, size: 62, circular: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  // Name + category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MarqueeText(
                          key: ValueKey(station.displayName),
                          text: station.displayName,
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFF38C172)
                                : textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(catLabel,
                            style: TextStyle(color: textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Playing indicator
                  if (isActive)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: _EqualizerBars(color: Color(0xFF38C172)),
                    ),
                  // Heart button
                  IconButton(
                    onPressed: onFavTap,
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav
                          ? const Color(0xFFDC2626)
                          : textMuted,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Station thumbnail (public — réutilisé par RadioPlayerScreen) ──────────────

// Catégorie → image (un fichier par catégorie)
const kCatAssets = <String, String>{
  '📖 Coran':         'assets/radio/cat_coran.webp',
  '👤 Récitateurs':   'assets/radio/cat_recitateurs.webp',
  '📚 Tafsir':        'assets/radio/cat_tafsir.webp',
  '🕌 Conférences':   'assets/radio/cat_conferences.webp',
  '🤲 Adhkar & Doua': 'assets/radio/cat_adhkar.webp',
  '🙏 Du\'a':         'assets/radio/cat_dua.webp',
  '🎓 Apprentissage': 'assets/radio/cat_apprentissage.webp',
  '🌍 Traductions':   'assets/radio/cat_traductions.webp',
};

/// Retourne l'image de profil du récitateur en utilisant le slug de l'URL
/// (ex. "abdulrasheed_soufi_assosi" → Abdurashid Sufi.webp).
String? reciterAssetForStation(RadioStation station) {
  final slug = station.url.split('/').last.toLowerCase();
  if (slug.contains('alsudaes') || slug.contains('sudais'))        return 'assets/images/reciters/Sudais.webp';
  if (slug.contains('abdulrasheed_soufi'))                         return 'assets/images/reciters/Abdurashid Sufi.webp';
  if (slug.contains('abdulbasit') || slug.contains('abdulbaset'))  return 'assets/images/reciters/Abdulbaset.webp';
  if (slug.contains('alajmy'))                                     return 'assets/images/reciters/Al Ajmy.webp';
  if (slug.contains('alqatami'))                                   return 'assets/images/reciters/Al Qatami.webp';
  if (slug.contains('alhussary') || slug.contains('alhusary'))     return 'assets/images/reciters/Alhusary.webp';
  if (slug.contains('ali_jaber') || slug.contains('ali_jabir'))    return 'assets/images/reciters/Ali Jabir.webp';
  if (slug.contains('shatri'))                                     return 'assets/images/reciters/As-shatri.webp';
  if (slug.contains('balilah') || slug.contains('baleela'))        return 'assets/images/reciters/Bandar Baleela.webp';
  if (slug.contains('hani_arrifai'))                               return 'assets/images/reciters/Hani Arrifai.webp';
  if (slug == 'maher')                                             return 'assets/images/reciters/Maher Almuaiqly.webp';
  if (slug.contains('mishary') || slug.contains('alafasi'))        return 'assets/images/reciters/Mishari Alafasy.webp';
  if (slug.contains('saad_alghamdi'))                              return 'assets/images/reciters/Saad Alghamdi.webp';
  if (slug.contains('shuraim') || slug.contains('shuraym'))        return 'assets/images/reciters/Shuraym.webp';
  return null;
}

class StationThumbnail extends StatelessWidget {
  final RadioStation station;
  final double       size;
  final bool         circular;

  const StationThumbnail({
    super.key,
    required this.station,
    required this.size,
    required this.circular,
  });

  @override
  Widget build(BuildContext context) {
    final cat  = categorizeStation(station);
    final grad = radioCategoryGradient(cat);
    // Image récitateur en priorité, sinon image catégorie
    final asset = reciterAssetForStation(station) ?? kCatAssets[cat];

    // Fallback gradient widget
    Widget fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.radio_rounded,
          color: Colors.white.withValues(alpha: 0.6),
          size: size * 0.42,
        ),
      ),
    );

    Widget img = asset != null
        ? Image.asset(
            asset,
            width: size, height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : fallback;

    return circular
        ? ClipOval(child: img)
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: img,
          );
  }
}

// ── Marquee (auto-scroll) text ────────────────────────────────────────────────

class _MarqueeText extends StatefulWidget {
  final String    text;
  final TextStyle style;

  const _MarqueeText({super.key, required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6000));
    _startTimer = Timer(const Duration(milliseconds: 1800), _startIfMounted);
  }

  void _startIfMounted() {
    if (mounted) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _ctrl.reset();
      _startTimer?.cancel();
      _startTimer = Timer(const Duration(milliseconds: 1800), _startIfMounted);
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);

      final textW = tp.width;
      final boxW  = constraints.maxWidth;

      if (textW <= boxW) {
        return Text(widget.text, style: widget.style);
      }

      final overflow = textW - boxW;

      return ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            // 0…0.12  pause at start
            // 0.12…0.8  scroll left
            // 0.8…0.92  pause at end
            // 0.92…1.0  snap back (invisible reset)
            final double offset;
            if (t < 0.12) {
              offset = 0;
            } else if (t < 0.80) {
              offset = overflow * (t - 0.12) / 0.68;
            } else if (t < 0.92) {
              offset = overflow;
            } else {
              offset = 0;
            }
            return SizedBox(
              width: boxW,
              child: Transform.translate(
                offset: Offset(-offset, 0),
                child: SizedBox(
                  width: textW,
                  child: Text(
                    widget.text,
                    style: widget.style,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// ── Animated equalizer bars ───────────────────────────────────────────────────

class _EqualizerBars extends StatefulWidget {
  final Color color;
  const _EqualizerBars({required this.color});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 480 + i * 140),
      )..repeat(reverse: true);
      c.value = i * 0.33;
      return c;
    });
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0.2, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_ctrls),
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          3,
          (i) => Container(
            width: 3,
            height: 14 * _anims[i].value,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
