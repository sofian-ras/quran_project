import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/radio_station.dart';
import '../../services/audio_service.dart';
import '../../services/radio_service.dart';
import 'radio_player_screen.dart';

// ── Public: categories + categorize (imported by radio_bottom_sheet too) ──────

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
      n.contains('mérite') || n.contains('merite') || n.contains('فضائل') ||
      n.contains('juridique') || n.contains('fiqh') || n.contains('فقه') ||
      n.contains('royaut')) { return '📚 Tafsir'; }
  if (n.contains('adhkar') || n.contains('azkar') || n.contains('ruqya') ||
      n.contains('dhikr') || n.contains('zikr') ||
      n.contains('أذكار')) { return '🤲 Adhkar & Doua'; }
  if (n.contains('الدعاء') || n.contains('أدعية') || n.contains('supplication') ||
      n.contains('doua') || n.contains('dua')) { return '🙏 Du\'a'; }
  if (n.contains('khutba') || n.contains('khotba') || n.contains('khoutba') ||
      n.contains('conférence') || n.contains('conference') ||
      n.contains('dars') || n.contains('lecture') ||
      n.contains('محاضر')) { return '🕌 Conférences'; }
  if (n.contains('hifz') || n.contains('memoriz') || n.contains('tajwid') ||
      n.contains('tajweed') || n.contains('تجويد') || n.contains('حفظ') ||
      n.contains('repeat') || n.contains('تكرار') || n.contains('talim') ||
      n.contains('apprentis')) { return '🎓 Apprentissage'; }
  if (n.contains('mishary') || n.contains('alafasy') ||
      n.contains('sudais') || n.contains('shuraim') ||
      n.contains('minshawi') || n.contains('husary') || n.contains('husari') ||
      n.contains('abdulbasit') || n.contains('abdul basit') ||
      n.contains('basit') || n.contains('ghamdi') || n.contains('ajmi') ||
      n.contains('shatri') || n.contains('baleela') || n.contains('arrifai') ||
      n.contains('muaiqly') || n.contains('jabir') || n.contains('soufi') ||
      n.contains('qatami') || n.contains('hudhaify') ||
      n.contains('tablawi') || n.contains('menshawi') ||
      n.contains('basfar') || n.contains('maher') ||
      n.contains('peshawa')) { return '👤 Récitateurs'; }
  return '📖 Coran';
}

String _stationLabel(RadioStation s) {
  if (categorizeStation(s) != '🌍 Traductions') return s.displayName;
  final n = s.name.toLowerCase();
  if (n.contains('français') || n.contains('french')) return 'Traduction française';
  if (n.contains('anglais')  || n.contains('english')) return 'Traduction anglaise';
  if (n.contains('urdu'))    return 'Traduction ourdou';
  if (n.contains('türk')    || n.contains('turc'))    return 'Traduction turque';
  if (n.contains('indonesia') || n.contains('malay')) return 'Traduction indonésienne';
  if (n.contains('bangla')  || n.contains('bengali')) return 'Traduction bengalie';
  if (n.contains('swahili')) return 'Traduction swahili';
  if (n.contains('farsi')   || n.contains('persan'))  return 'Traduction persane';
  if (n.contains('bosni'))   return 'Traduction bosniaque';
  final match = RegExp(r'traduct|translat', caseSensitive: false).firstMatch(s.name);
  if (match != null) {
    final from  = s.name.substring(match.start).trim();
    final label = from[0].toUpperCase() + from.substring(1);
    return label.length > 26 ? '…${label.substring(label.length - 24)}' : label;
  }
  final dn = s.displayName;
  return dn.length > 26 ? '…${dn.substring(dn.length - 24)}' : dn;
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

  List<RadioStation> _stations  = [];
  List<RadioStation> _recents   = [];
  List<RadioStation> _popular   = [];
  List<RadioStation> _favorites = [];
  bool    _loading = true;
  String? _error;
  String  _selectedCategory = 'Tous';
  final   _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      // Fermer le clavier quand on quitte l'onglet Parcourir (index 1)
      if (_tabCtrl.index != 1) FocusScope.of(context).unfocus();
    });
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
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

  Map<String, List<RadioStation>> get _grouped {
    final map = <String, List<RadioStation>>{
      for (final c in kRadioCategories.skip(1)) c: [],
    };
    for (final s in _stations) { map[categorizeStation(s)]!.add(s); }
    return map;
  }

  List<String> get _activeCategories {
    final present = _stations.map(categorizeStation).toSet();
    return kRadioCategories
        .where((c) => c == 'Tous' || present.contains(c))
        .toList();
  }

  void _play(RadioStation station) {
    HapticFeedback.mediumImpact();
    AudioService.instance.playRadio(station);
    RadioService.instance.currentStationNotifier.value = station;
    RadioService.instance.trackPlay(station);
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
    ).then((_) => _reloadFavorites());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF080D1A) : const Color(0xFFF5F0E8);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
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
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

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
            // Now-playing indicator
            ValueListenableBuilder<RadioStation?>(
              valueListenable: RadioService.instance.currentStationNotifier,
              builder: (_, station, __) {
                if (station == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
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
                  ).then((_) => _reloadFavorites()),
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

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    final surfaceBg  = isDark ? const Color(0xFF0E1530) : const Color(0xFFECE7DF);
    final unselColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Container(
      color: surfaceBg,
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: const Color(0xFF38C172),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFF38C172),
        unselectedLabelColor: unselColor,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Accueil'),
          Tab(text: 'Parcourir'),
          Tab(icon: Icon(Icons.favorite_rounded, size: 16), text: 'Favoris'),
        ],
      ),
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
    final grouped = _grouped;
    // Stations "Découvrir" : premières stations de catégories pas dans les récents
    final recentIds = _recents.map((s) => s.id).toSet();
    final discover  = _stations
        .where((s) => !recentIds.contains(s.id))
        .take(12)
        .toList();

    final slivers = <Widget>[];

    if (_recents.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(emoji: '🕐', title: 'Récents', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(
                stations: _recents, onTap: _play, isDark: isDark)));
    }

    if (_popular.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(
                emoji: '🔥', title: 'Populaires', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(
                stations: _popular, onTap: _play, isDark: isDark)));
    }

    if (discover.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(
                emoji: '✨', title: 'Découvrir', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HomeCardRow(
                stations: discover, onTap: _play, isDark: isDark)));
    }

    // Catégories en tuiles compactes si rien à afficher
    if (_recents.isEmpty && _popular.isEmpty) {
      for (final cat in kRadioCategories.skip(1)) {
        final list = grouped[cat] ?? [];
        if (list.isEmpty) continue;
        final spaceIdx = cat.indexOf(' ');
        slivers
          ..add(SliverToBoxAdapter(
              child: _SectionTitle(
                  emoji: spaceIdx > 0 ? cat.substring(0, spaceIdx) : '',
                  title:
                      spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat,
                  isDark: isDark,
                  accentColor: radioCategoryGradient(cat).first)))
          ..add(SliverToBoxAdapter(
              child: _HomeCardRow(
                  stations: list.take(6).toList(),
                  onTap: _play,
                  isDark: isDark)));
      }
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

    if (slivers.isEmpty) {
      return Center(
        child: Text('Aucune station disponible',
            style: TextStyle(
                color: isDark
                    ? const Color(0xFF8899BB)
                    : const Color(0xFF9CA3AF))),
      );
    }

    return CustomScrollView(slivers: slivers);
  }

  // ── Onglet Parcourir ───────────────────────────────────────────────────────

  Widget _buildParcourirTab(bool isDark) {
    final fillColor  = isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);
    final hintColor  = isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final unselBg    = isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);
    final unselText  = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher une station…',
              hintStyle: TextStyle(color: hintColor, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: hintColor, size: 20),
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
        // Category chips
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: (!_isSearching)
              ? SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: _activeCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat      = _activeCategories[i];
                      final selected = cat == _selectedCategory;
                      final gradColors = cat == 'Tous'
                          ? [
                              const Color(0xFF38C172),
                              const Color(0xFF1DA355)
                            ]
                          : radioCategoryGradient(cat);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(colors: gradColors)
                                : null,
                            color: selected ? null : unselBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected ? Colors.white : unselText,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Station list
        Expanded(child: _buildBrowseContent(isDark)),
      ],
    );
  }

  Widget _buildBrowseContent(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);

    if (_isSearching) {
      final results = _searchFiltered;
      if (results.isEmpty) {
        return Center(
            child: Text('Aucune station trouvée',
                style: TextStyle(color: mutedColor)));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: results.length,
        itemBuilder: (_, i) => _StationTile(
          station: results[i],
          isDark: isDark,
          onTap: () => _play(results[i]),
          onFavTap: () => _toggleFavFromList(results[i]),
          isFav: _favorites.any((f) => f.id == results[i].id),
        ),
      );
    }

    final grouped = _grouped;

    if (_selectedCategory != 'Tous') {
      final list = grouped[_selectedCategory] ?? [];
      if (list.isEmpty) {
        return Center(
            child: Text('Aucune station dans cette catégorie',
                style: TextStyle(color: mutedColor)));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: list.length,
        itemBuilder: (_, i) => _StationTile(
          station: list[i],
          isDark: isDark,
          onTap: () => _play(list[i]),
          onFavTap: () => _toggleFavFromList(list[i]),
          isFav: _favorites.any((f) => f.id == list[i].id),
        ),
      );
    }

    // Tous : liste avec en-têtes de section
    final items = <dynamic>[];
    for (final cat in kRadioCategories.skip(1)) {
      final list = grouped[cat] ?? [];
      if (list.isEmpty) continue;
      items.add(cat);
      items.addAll(list);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is String) {
          final spaceIdx = item.indexOf(' ');
          return _SectionTitle(
            emoji: spaceIdx > 0 ? item.substring(0, spaceIdx) : '',
            title: spaceIdx > 0 ? item.substring(spaceIdx + 1) : item,
            isDark: isDark,
            accentColor: radioCategoryGradient(item).first,
            compact: true,
          );
        }
        final s = item as RadioStation;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StationTile(
            station: s,
            isDark: isDark,
            onTap: () => _play(s),
            onFavTap: () => _toggleFavFromList(s),
            isFav: _favorites.any((f) => f.id == s.id),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavFromList(RadioStation s) async {
    await RadioService.instance.toggleFavorite(s);
    await _reloadFavorites();
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
        );
      },
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final bool   isDark;
  final Color? accentColor;
  final bool   compact;

  const _SectionTitle({
    required this.emoji,
    required this.title,
    required this.isDark,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final lineColor = accentColor ??
        (isDark ? const Color(0xFF38C172) : const Color(0xFF6EE7B7));

    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 14 : 20, 16, compact ? 6 : 10),
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
              fontSize: compact ? 13 : 16,
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

// ── Horizontal home cards ─────────────────────────────────────────────────────

class _HomeCardRow extends StatelessWidget {
  final List<RadioStation>          stations;
  final void Function(RadioStation) onTap;
  final bool                        isDark;

  const _HomeCardRow({
    required this.stations,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
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
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF141C30),
              border: isActive
                  ? Border.all(color: const Color(0xFF38C172), width: 2)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: const Color(0xFF38C172).withValues(alpha: 0.3),
                    blurRadius: 12, spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 6, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Thumbnail top half
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                  child: SizedBox(
                    height: 78, width: double.infinity,
                    child: StationThumbnail(
                      station: station,
                      size: 78,
                      circular: false,
                    ),
                  ),
                ),
                // Name bottom half
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 5),
                    child: Text(
                      _stationLabel(station),
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF38C172)
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Station tile (list row with thumbnail + heart) ────────────────────────────

class _StationTile extends StatelessWidget {
  final RadioStation station;
  final bool         isDark;
  final VoidCallback onTap;
  final VoidCallback onFavTap;
  final bool         isFav;

  const _StationTile({
    required this.station,
    required this.isDark,
    required this.onTap,
    required this.onFavTap,
    required this.isFav,
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

    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54, height: 54,
                    child: StationThumbnail(
                      station: station, size: 54, circular: false),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stationLabel(station),
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF38C172)
                              : textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(catLabel,
                          style:
                              TextStyle(color: textMuted, fontSize: 11)),
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
        );
      },
    );
  }
}

// ── Station thumbnail (public — réutilisé par RadioPlayerScreen) ──────────────

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
    final grad = radioCategoryGradient(categorizeStation(station));

    Widget img = Image.asset(
      'assets/radio/${station.id}.jpg',
      width: size, height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
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
      ),
    );

    return circular
        ? ClipOval(child: img)
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: img,
          );
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
