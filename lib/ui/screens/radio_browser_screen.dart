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
  '🌙 Ambiance',
  '🎓 Apprentissage',
  '🌍 Traductions',
];

const _kCatGradients = <String, List<Color>>{
  '📖 Coran':         [Color(0xFF0E7B70), Color(0xFF054940)],
  '👤 Récitateurs':   [Color(0xFF1E4494), Color(0xFF0D2560)],
  '📚 Tafsir':        [Color(0xFF6B35A8), Color(0xFF3D1472)],
  '🕌 Conférences':   [Color(0xFF9B3232), Color(0xFF601515)],
  '🤲 Adhkar & Doua': [Color(0xFF1A8A68), Color(0xFF0D5240)],
  '🌙 Ambiance':      [Color(0xFF252585), Color(0xFF100F55)],
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
  if (n.contains('tafsir') || n.contains('تفسير')) { return '📚 Tafsir'; }
  if (n.contains('adhkar') || n.contains('azkar') || n.contains('doua') ||
      n.contains('dua') || n.contains('ruqya') || n.contains('dhikr') ||
      n.contains('zikr') || n.contains('أذكار')) { return '🤲 Adhkar & Doua'; }
  if (n.contains('khutba') || n.contains('khotba') || n.contains('khoutba') ||
      n.contains('conférence') || n.contains('conference') ||
      n.contains('dars') || n.contains('lecture') ||
      n.contains('محاضر')) { return '🕌 Conférences'; }
  if (n.contains('relax') || n.contains('sleep') || n.contains('nuit') ||
      n.contains('soir') || n.contains('calm') || n.contains('meditat') ||
      n.contains('douce') || n.contains('lente')) { return '🌙 Ambiance'; }
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
      return _buildFilteredGrid(filtered, isDark);
    }

    return _buildTousView(isDark);
  }

  // ── Search results list ────────────────────────────────────────────────────

  Widget _buildSearchList(List<RadioStation> stations, bool isDark) {
    final textPrimary =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final textMuted =
        isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final tileBg =
        isDark ? const Color(0xFF141C30) : const Color(0xFFEEEAE2);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: stations.length,
      itemBuilder: (_, i) {
        final s   = stations[i];
        final cat = categorizeStation(s);
        final emojiEnd = cat.contains(' ') ? cat.indexOf(' ') : cat.length;

        return ValueListenableBuilder<RadioStation?>(
          valueListenable: RadioService.instance.currentStationNotifier,
          builder: (_, current, __) {
            final isActive = current?.id == s.id;
            return GestureDetector(
              onTap: () => _play(s),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: tileBg,
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFF38C172), width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: radioCategoryGradient(cat)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          cat.substring(0, emojiEnd),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.displayName,
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF38C172)
                                  : textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            cat.contains(' ')
                                ? cat.substring(cat.indexOf(' ') + 1)
                                : cat,
                            style:
                                TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const _EqualizerBars(color: Color(0xFF38C172))
                    else
                      Icon(Icons.play_circle_outline_rounded,
                          color: textMuted, size: 22),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Single-category grid ───────────────────────────────────────────────────

  Widget _buildFilteredGrid(List<RadioStation> stations, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridCard(
                station: stations[i],
                category: _selectedCategory,
                onTap: () => _play(stations[i]),
              ),
              childCount: stations.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 92,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
          ),
        ),
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
        ..add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridCard(
                station: list[i],
                category: cat,
                onTap: () => _play(list[i]),
              ),
              childCount: list.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 92,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
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

// ── Horizontal scrollable cards ───────────────────────────────────────────────

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
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s    = stations[i];
          final cat  = categorizeStation(s);
          final grad = radioCategoryGradient(cat);
          final spaceIdx = cat.indexOf(' ');
          final catLabel = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;

          return ValueListenableBuilder<RadioStation?>(
            valueListenable: RadioService.instance.currentStationNotifier,
            builder: (_, current, __) {
              final isActive = current?.id == s.id;
              return GestureDetector(
                onTap: () => onTap(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 145,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: grad,
                    ),
                    border: isActive
                        ? Border.all(
                            color: const Color(0xFF38C172), width: 2)
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      if (isActive)
                        BoxShadow(
                          color: const Color(0xFF38C172)
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isActive
                            ? const _EqualizerBars(color: Colors.white)
                            : const Icon(Icons.radio_rounded,
                                color: Colors.white54, size: 20),
                        const Spacer(),
                        Text(
                          s.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black54)
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          catLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 10,
                          ),
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

// ── Grid card ─────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final RadioStation station;
  final String category;
  final VoidCallback onTap;

  const _GridCard({
    required this.station,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grad = radioCategoryGradient(category);
    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: grad,
              ),
              border: isActive
                  ? Border.all(color: const Color(0xFF38C172), width: 2)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: const Color(0xFF38C172).withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: isActive
                        ? const _EqualizerBars(color: Colors.white)
                        : const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  Text(
                    station.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54)
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
