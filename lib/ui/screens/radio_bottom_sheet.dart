import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/radio_station.dart';
import '../../services/audio_service.dart';
import '../../services/radio_service.dart';
import 'radio_browser_screen.dart';

// ── Widget principal ──────────────────────────────────────────────────────────

class RadioBottomSheet extends StatefulWidget {
  const RadioBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RadioBottomSheet(),
    );
  }

  @override
  State<RadioBottomSheet> createState() => _RadioBottomSheetState();
}

class _RadioBottomSheetState extends State<RadioBottomSheet> {
  List<RadioStation> _stations = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Tous';
  final TextEditingController _searchCtrl = TextEditingController();

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
      final stations = await RadioService.instance.getStations();
      if (mounted) { setState(() { _stations = stations; _loading = false; }); }
    } catch (e) {
      if (mounted) { setState(() {
        _error   = 'Impossible de charger les stations.\nVérifiez votre connexion.';
        _loading = false;
      }); }
    }
  }

  // ── Filtrage ────────────────────────────────────────────────────────────────

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  List<RadioStation> get _searchFiltered {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _stations;
    return _stations.where((s) =>
        s.displayName.toLowerCase().contains(q) ||
        s.domain.toLowerCase().contains(q)).toList();
  }

  /// Catégories qui ont au moins une station dans la liste actuelle.
  List<String> get _activeCategories {
    final present = _stations.map(categorizeStation).toSet();
    return kRadioCategories.where((c) => c == 'Tous' || present.contains(c)).toList();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bg          = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final surface     = isDark ? const Color(0xFF252542) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final textMuted   = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    const accent      = Color(0xFF38C172);
    final chipBg      = isDark ? const Color(0xFF252542) : const Color(0xFFEEF2F7);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.radio, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Radio Quran',
                      style: TextStyle(color: textPrimary, fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // ── Barre de recherche ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher une station…',
                  hintStyle: TextStyle(color: textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                          padding: EdgeInsets.zero,
                        )
                      : null,
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── Chips catégories (masqués pendant la recherche) ──────────
            if (!_isSearching && _stations.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _activeCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _activeCategories[i];
                    final selected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? accent : chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const SizedBox(height: 8),

            // ── Corps ────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: accent))
                  : _error != null
                      ? _ErrorView(
                          message: _error!,
                          onRetry: () {
                            setState(() { _loading = true; _error = null; });
                            _load();
                          },
                          textMuted: textMuted,
                          accent: accent,
                        )
                      : _buildList(scrollCtrl, textPrimary, textMuted, accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollCtrl, Color textPrimary,
      Color textMuted, Color accent) {
    // Recherche active → liste plate cross-catégories
    if (_isSearching) {
      final results = _searchFiltered;
      if (results.isEmpty) {
        return Center(child: Text('Aucune station trouvée',
            style: TextStyle(color: textMuted)));
      }
      return ListView.builder(
        controller: scrollCtrl,
        itemCount: results.length,
        itemBuilder: (_, i) => _StationTile(
          station: results[i],
          textPrimary: textPrimary,
          textMuted: textMuted,
          accent: accent,
          onTap: () => _play(results[i]),
        ),
      );
    }

    // Catégorie spécifique → liste plate filtrée
    if (_selectedCategory != 'Tous') {
      final filtered = _stations
          .where((s) => categorizeStation(s) == _selectedCategory)
          .toList();
      if (filtered.isEmpty) {
        return Center(child: Text('Aucune station dans cette catégorie',
            style: TextStyle(color: textMuted)));
      }
      return ListView.builder(
        controller: scrollCtrl,
        itemCount: filtered.length,
        itemBuilder: (_, i) => _StationTile(
          station: filtered[i],
          textPrimary: textPrimary,
          textMuted: textMuted,
          accent: accent,
          onTap: () => _play(filtered[i]),
        ),
      );
    }

    // Tous → liste avec en-têtes de sections
    final items = _buildSectionedItems(_stations);
    if (items.isEmpty) {
      return Center(child: Text('Aucune station disponible',
          style: TextStyle(color: textMuted)));
    }
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is String) {
          return _SectionHeader(label: item, textMuted: textMuted);
        }
        final station = item as RadioStation;
        return _StationTile(
          station: station,
          textPrimary: textPrimary,
          textMuted: textMuted,
          accent: accent,
          onTap: () => _play(station),
        );
      },
    );
  }

  void _play(RadioStation station) {
    AudioService.instance.playRadio(station);
    RadioService.instance.currentStationNotifier.value = station;
    Navigator.of(context).pop();
  }

  /// Construit une liste plate [String header, RadioStation, RadioStation, …]
  List<dynamic> _buildSectionedItems(List<RadioStation> stations) {
    final grouped = <String, List<RadioStation>>{
      for (final c in kRadioCategories.skip(1)) c: [],
    };
    for (final s in stations) { grouped[categorizeStation(s)]!.add(s); }

    final items = <dynamic>[];
    for (final cat in kRadioCategories.skip(1)) {
      final list = grouped[cat]!;
      if (list.isEmpty) continue;
      items.add(cat);
      items.addAll(list);
    }
    return items;
  }
}

// ── En-tête de section ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color textMuted;

  const _SectionHeader({required this.label, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Tuile station ─────────────────────────────────────────────────────────────

class _StationTile extends StatelessWidget {
  final RadioStation station;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final VoidCallback onTap;

  const _StationTile({
    required this.station,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, current, __) {
        final isActive = current?.id == station.id;
        return ListTile(
          leading: _LeadingIcon(isActive: isActive, accent: accent, textMuted: textMuted),
          title: Text(
            station.displayName,
            style: TextStyle(
              color: isActive ? accent : textPrimary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
          subtitle: Text(station.domain,
              style: TextStyle(color: textMuted, fontSize: 12)),
          trailing: isActive
              ? Icon(Icons.graphic_eq_rounded, color: accent, size: 20)
              : null,
          onTap: onTap,
        );
      },
    );
  }
}

// ── Icône leading : dot animé si actif ───────────────────────────────────────

class _LeadingIcon extends StatefulWidget {
  final bool isActive;
  final Color accent;
  final Color textMuted;

  const _LeadingIcon({
    required this.isActive,
    required this.accent,
    required this.textMuted,
  });

  @override
  State<_LeadingIcon> createState() => _LeadingIconState();
}

class _LeadingIconState extends State<_LeadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(Icons.radio_outlined, color: widget.textMuted, size: 22);
    }
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10, height: 10,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.5),
              blurRadius: 6, spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue erreur ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color textMuted;
  final Color accent;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.textMuted,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: textMuted, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: accent),
              label: Text('Réessayer', style: TextStyle(color: accent)),
            ),
          ],
        ),
      ),
    );
  }
}
