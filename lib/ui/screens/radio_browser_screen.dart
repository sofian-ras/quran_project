import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/radio_station.dart';
import '../../services/audio_service.dart';
import '../../services/radio_service.dart';

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
      // Interprétation / résumé
      n.contains('interpré') || n.contains('interpret') ||
      n.contains('résumé') || n.contains('resume') || n.contains('mukhtasar') ||
      // Sira / biographie du Prophète
      n.contains('biographie') || n.contains('sira') || n.contains('sirat') ||
      n.contains('nabawi') || n.contains('سيرة') || n.contains('نبوي') ||
      // Hadith (Sahih Bukhari / Sahih Muslim)
      n.contains('sahih') || n.contains('bukhari') || n.contains('bukhary') ||
      // Histoires des prophètes / compagnons
      n.contains('histoir') || n.contains('قصص') ||
      n.contains('compagnon') || n.contains('sahaba') || n.contains('صحابة') ||
      // Fatwas
      n.contains('fatwa') || n.contains('فتوى') || n.contains('فتاوى') ||
      // Mérites / vertus
      n.contains('mérite') || n.contains('merite') || n.contains('فضائل') ||
      // Fiqh / juridique / royauté
      n.contains('juridique') || n.contains('fiqh') || n.contains('فقه') ||
      n.contains('royaut')) { return '📚 Tafsir'; }
  if (n.contains('adhkar') || n.contains('azkar') || n.contains('doua') ||
      n.contains('dua') || n.contains('ruqya') || n.contains('dhikr') ||
      n.contains('zikr') || n.contains('أذكار')) { return '🤲 Adhkar & Doua'; }
  if (n.contains('khutba') || n.contains('khotba') || n.contains('khoutba') ||
      n.contains('conférence') || n.contains('conference') ||
      n.contains('dars') || n.contains('lecture') ||
      n.contains('محاضر')) { return '🕌 Conférences'; }
  if (n.contains('الدعاء') || n.contains('أدعية') || n.contains('supplication') ||
      n.contains('relax') || n.contains('sleep') || n.contains('calm')) {
    return '🙏 Du\'a';
  }
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

// ── Display-name helper (smart labels for Traductions) ────────────────────────

String _stationLabel(RadioStation s) {
  if (categorizeStation(s) != '🌍 Traductions') return s.displayName;
  final n = s.name.toLowerCase();
  if (n.contains('français') || n.contains('french') || n.contains('france')) {
    return 'Traduction française';
  }
  if (n.contains('anglais') || n.contains('english')) return 'Traduction anglaise';
  if (n.contains('urdu')) return 'Traduction ourdou';
  if (n.contains('türk') || n.contains('turc')) return 'Traduction turque';
  if (n.contains('indonesia') || n.contains('malay') || n.contains('melayu')) {
    return 'Traduction indonésienne';
  }
  if (n.contains('bangla') || n.contains('bengali')) return 'Traduction bengalie';
  if (n.contains('swahili')) return 'Traduction swahili';
  if (n.contains('farsi') || n.contains('persan') || n.contains('persian')) {
    return 'Traduction persane';
  }
  if (n.contains('bosni')) return 'Traduction bosniaque';
  // Option D fallback: find "traduct/translat" and right-truncate so the
  // language (always at the end) is always visible
  final match = RegExp(r'traduct|translat', caseSensitive: false)
      .firstMatch(s.name);
  if (match != null) {
    final fromHere = s.name.substring(match.start).trim();
    final label = fromHere[0].toUpperCase() + fromHere.substring(1);
    // Right-truncate: keep the end (= language name)
    return label.length > 26 ? '…${label.substring(label.length - 24)}' : label;
  }
  // Final fallback: right-truncate on displayName
  final dn = s.displayName;
  return dn.length > 26 ? '…${dn.substring(dn.length - 24)}' : dn;
}

/// Deterministic bar fill: values 0.4 – 0.9, unique per station.
double _barFill(RadioStation s) => ((s.id * 7 % 6) + 4) / 10.0;

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

class _RadioBrowserScreenState extends State<RadioBrowserScreen> {
  List<RadioStation> _stations = [];
  List<RadioStation> _recents  = [];
  List<RadioStation> _popular  = [];
  bool    _loading = true;
  String? _error;
  String  _selectedCategory = 'Tous';
  final   _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        RadioService.instance.getStations(),
        RadioService.instance.getRecents(),
        RadioService.instance.getPopular(limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _stations = results[0];
        _recents  = results[1];
        _popular  = results[2];
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = 'Impossible de charger les stations.\nVérifiez votre connexion.';
        _loading = false;
      });
    }
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  List<RadioStation> get _searchFiltered {
    final q = _searchCtrl.text.toLowerCase().trim();
    return _stations
        .where((s) =>
            s.displayName.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<RadioStation>> get _grouped {
    final map = <String, List<RadioStation>>{
      for (final c in kRadioCategories.skip(1)) c: [],
    };
    for (final s in _stations) {
      map[categorizeStation(s)]!.add(s);
    }
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
    Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF080D1A) : const Color(0xFFF5F0E8),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildSearchBar(isDark),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: (!_isSearching && _stations.isNotEmpty)
                ? _buildChips(isDark)
                : const SizedBox.shrink(),
          ),
          Expanded(child: _buildContent(isDark)),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Container(
      decoration: isDark
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E1530), Color(0xFF0A0D1A)],
              ),
            )
          : null,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radio Quran',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Chaînes en direct',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Now-playing pill
              ValueListenableBuilder<RadioStation?>(
                valueListenable: RadioService.instance.currentStationNotifier,
                builder: (_, station, __) {
                  if (station == null) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            station.displayName,
                            style: const TextStyle(
                              color: Color(0xFF38C172),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark) {
    final fillColor = isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);
    final hintColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  icon: Icon(Icons.clear_rounded, color: hintColor, size: 18),
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
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildChips(bool isDark) {
    final unselBg   = isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);
    final unselText = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _activeCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = _activeCategories[i];
          final selected = cat == _selectedCategory;
          final gradColors = cat == 'Tous'
              ? [const Color(0xFF38C172), const Color(0xFF1DA355)]
              : radioCategoryGradient(cat);

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : unselText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Content router ─────────────────────────────────────────────────────────

  Widget _buildContent(bool isDark) {
    final mutedColor =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF9CA3AF);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: Color(0xFF38C172), strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Chargement des stations…',
                style: TextStyle(color: mutedColor, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
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
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF38C172)),
                label: const Text('Réessayer',
                    style: TextStyle(color: Color(0xFF38C172))),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching) {
      final results = _searchFiltered;
      if (results.isEmpty) {
        return Center(
          child: Text('Aucune station trouvée',
              style: TextStyle(color: mutedColor, fontSize: 14)),
        );
      }
      return _buildSearchList(results, isDark);
    }

    if (_selectedCategory != 'Tous') {
      final filtered = _grouped[_selectedCategory] ?? [];
      if (filtered.isEmpty) {
        return Center(
          child: Text('Aucune station dans cette catégorie',
              style: TextStyle(color: mutedColor, fontSize: 14)),
        );
      }
      return _buildFilteredList(filtered, isDark);
    }

    return _buildTousView(isDark);
  }

  // ── Search results list ────────────────────────────────────────────────────

  Widget _buildSearchList(List<RadioStation> stations, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: stations.length,
      separatorBuilder: (_, __) => _RowDivider(isDark: isDark),
      itemBuilder: (_, i) => _StationRow(
        station: stations[i],
        isDark: isDark,
        showCategory: true,
        onTap: () => _play(stations[i]),
      ),
    );
  }

  // ── Single-category list ───────────────────────────────────────────────────

  Widget _buildFilteredList(List<RadioStation> stations, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StationRow(
                  station: stations[i],
                  isDark: isDark,
                  onTap: () => _play(stations[i]),
                ),
                if (i < stations.length - 1) _RowDivider(isDark: isDark),
              ],
            ),
            childCount: stations.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── "Tous" full view ───────────────────────────────────────────────────────

  Widget _buildTousView(bool isDark) {
    final grouped = _grouped;
    final slivers = <Widget>[];

    if (_recents.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(
                emoji: '🕐', title: 'Récents', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HorizontalCards(
                stations: _recents, onTap: _play, isDark: isDark)));
    }

    if (_popular.isNotEmpty) {
      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(
                emoji: '🔥', title: 'Populaires', isDark: isDark)))
        ..add(SliverToBoxAdapter(
            child: _HorizontalCards(
                stations: _popular, onTap: _play, isDark: isDark)));
    }

    for (final cat in kRadioCategories.skip(1)) {
      final list = grouped[cat] ?? [];
      if (list.isEmpty) continue;
      final spaceIdx = cat.indexOf(' ');
      final emoji = spaceIdx > 0 ? cat.substring(0, spaceIdx) : '';
      final label = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;

      slivers
        ..add(SliverToBoxAdapter(
            child: _SectionTitle(
                emoji: emoji,
                title: label,
                isDark: isDark,
                accentColor: radioCategoryGradient(cat).first)))
        ..add(SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StationRow(
                  station: list[i],
                  isDark: isDark,
                  onTap: () => _play(list[i]),
                ),
                if (i < list.length - 1) _RowDivider(isDark: isDark),
              ],
            ),
            childCount: list.length,
          ),
        ))
        ..add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));
    return CustomScrollView(slivers: slivers);
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final bool isDark;
  final Color? accentColor;

  const _SectionTitle({
    required this.emoji,
    required this.title,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final lineColor = accentColor ??
        (isDark ? const Color(0xFF38C172) : const Color(0xFF6EE7B7));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
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
                    lineColor.withValues(alpha: 0.55),
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

// ── Horizontal scrollable cards (Récents / Populaires) ───────────────────────

class _HorizontalCards extends StatelessWidget {
  final List<RadioStation> stations;
  final void Function(RadioStation) onTap;
  final bool isDark;

  const _HorizontalCards({
    required this.stations,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s          = stations[i];
          final cat        = categorizeStation(s);
          final accentClr  = radioCategoryGradient(cat).first;
          final fill       = _barFill(s);
          final cardBg     = isDark ? const Color(0xFF141C30) : const Color(0xFFE8E4DC);
          final trackColor = isDark ? const Color(0xFF1E2A42) : const Color(0xFFD0CAC0);

          return ValueListenableBuilder<RadioStation?>(
            valueListenable: RadioService.instance.currentStationNotifier,
            builder: (_, current, __) {
              final isActive = current?.id == s.id;
              final barColor = isActive ? const Color(0xFF38C172) : accentClr;

              return GestureDetector(
                onTap: () => onTap(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: cardBg,
                    border: Border(
                      left: BorderSide(color: accentClr, width: 3),
                      top: isActive
                          ? const BorderSide(color: Color(0xFF38C172), width: 1)
                          : BorderSide.none,
                      right: isActive
                          ? const BorderSide(color: Color(0xFF38C172), width: 1)
                          : BorderSide.none,
                      bottom: isActive
                          ? const BorderSide(color: Color(0xFF38C172), width: 1)
                          : BorderSide.none,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF38C172).withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + equalizer
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _stationLabel(s),
                                style: TextStyle(
                                  color: isActive
                                      ? const Color(0xFF38C172)
                                      : (isDark
                                          ? const Color(0xFFEAF2FF)
                                          : const Color(0xFF111827)),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: _EqualizerBars(color: Color(0xFF38C172)),
                              ),
                          ],
                        ),
                        const Spacer(),
                        // Frequency bar
                        LayoutBuilder(
                          builder: (_, c) {
                            final maxW = c.maxWidth;
                            final barW = isActive ? maxW : maxW * fill;
                            return Stack(children: [
                              Container(
                                width: maxW, height: 3,
                                decoration: BoxDecoration(
                                  color: trackColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                width: barW, height: 3,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: isActive
                                      ? [BoxShadow(
                                          color: const Color(0xFF38C172)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        )]
                                      : null,
                                ),
                              ),
                            ]);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Station row (list item with horizontal frequency bar) ─────────────────────

class _StationRow extends StatelessWidget {
  final RadioStation station;
  final bool isDark;
  final bool showCategory;
  final VoidCallback onTap;

  const _StationRow({
    required this.station,
    required this.isDark,
    this.showCategory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat        = categorizeStation(station);
    final fill       = _barFill(station);
    final accentClr  = radioCategoryGradient(cat).first;
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final trackColor = isDark ? const Color(0xFF1E2A42) : const Color(0xFFE0DAD0);
    final activeBg   = isDark ? const Color(0xFF0A1A28) : const Color(0xFFE8F5EE);

    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        final barColor = isActive ? const Color(0xFF38C172) : accentClr;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            color: isActive ? activeBg : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name + trailing
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _stationLabel(station),
                        style: TextStyle(
                          color: isActive ? const Color(0xFF38C172) : textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (showCategory && !isActive) ...[
                      const SizedBox(width: 8),
                      Text(
                        cat.contains(' ')
                            ? cat.substring(cat.indexOf(' ') + 1)
                            : cat,
                        style: TextStyle(color: mutedColor, fontSize: 11),
                      ),
                    ],
                    if (isActive)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: _EqualizerBars(color: Color(0xFF38C172)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Horizontal frequency bar
                LayoutBuilder(
                  builder: (_, c) {
                    final maxW = c.maxWidth;
                    final barW = isActive ? maxW : maxW * fill;
                    return Stack(children: [
                      Container(
                        width: maxW, height: 3,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: barW, height: 3,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: isActive
                              ? [BoxShadow(
                                  color: const Color(0xFF38C172)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 6,
                                )]
                              : null,
                        ),
                      ),
                    ]);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Row divider ───────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  final bool isDark;
  const _RowDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark
          ? const Color(0xFF1E2A42)
          : const Color(0xFFDDD8D0),
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
            height: 12 * _anims[i].value,
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
