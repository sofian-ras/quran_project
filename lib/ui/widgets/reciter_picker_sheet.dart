// lib/ui/widgets/reciter_picker_sheet.dart
//
// Sélecteur de récitateur pour le mini-player.
//   - Épinglés en haut (favoris + téléchargés)
//   - Sections alphabétiques
//   - Barre de recherche (icône → champ)
//   - Cœur pour marquer en favori

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/mini_player_service.dart';
import '../../services/mp3quran/timed_surah_downloader.dart';
import '../../services/qul_audio/qul_catalog_service.dart';
import '../../services/qul_audio/models/qul_reciter.dart';

const _kFavKey = 'reciter_favorites_qul';
const _gold    = Color(0xFFC8A165);

class ReciterPickerSheet extends StatefulWidget {
  final MiniPlayerService svc;
  final bool isDark;

  const ReciterPickerSheet({super.key, required this.svc, required this.isDark});

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  final _searchCtrl = TextEditingController();
  bool   _showSearch      = false;
  String _query           = '';
  Set<int> _favorites     = {};
  Set<int> _downloadedIds = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Chargement favoris + téléchargés ─────────────────────────────────────

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final favs  = (prefs.getStringList(_kFavKey) ?? [])
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id >= 0)
        .toSet();

    final downloaded = <int>{};
    for (final r in QulCatalogService.reciters) {
      if (r.timedSource != null) {
        if (await TimedSurahDownloader.instance.hasAnyDownloaded(r.timedSource!)) {
          downloaded.add(r.qulId);
        }
      }
    }
    if (mounted) setState(() { _favorites = favs; _downloadedIds = downloaded; });
  }

  Future<void> _toggleFav(int qulId) async {
    final next = Set<int>.from(_favorites);
    next.contains(qulId) ? next.remove(qulId) : next.add(qulId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavKey, next.map((e) => e.toString()).toList());
    if (mounted) setState(() => _favorites = next);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isPinned(QulReciter r) =>
      _favorites.contains(r.qulId) || _downloadedIds.contains(r.qulId);

  int _currentQulId() =>
      int.tryParse(widget.svc.currentReciter.value.folder) ?? -1;

  void _select(QulReciter r) {
    final mr = kMiniReciters.firstWhere(
      (m) => m.folder == r.qulId.toString(),
      orElse: () => kMiniReciters.first,
    );
    widget.svc.setReciter(mr);
    Navigator.pop(context);
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Color get _bg   => widget.isDark ? const Color(0xFF110822) : Colors.white;
  Color get _text => widget.isDark ? Colors.white : Colors.black87;
  Color get _sub  => widget.isDark ? Colors.white38 : Colors.black38;
  Color get _div  => widget.isDark ? Colors.white10 : Colors.black12;

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: _gold.withValues(alpha: 0.8),
      ),
    ),
  );

  Widget _divider() => Divider(height: 1, thickness: 0.5, color: _div, indent: 56);

  Widget _tile(QulReciter r, int currentQulId) {
    final selected  = r.qulId == currentQulId;
    final isFav     = _favorites.contains(r.qulId);
    final isDl      = _downloadedIds.contains(r.qulId);
    final initial   = r.name.isNotEmpty ? r.name[0].toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: selected
                ? _gold.withValues(alpha: 0.25)
                : widget.isDark ? const Color(0xFF2A1045) : const Color(0xFFF0EBF8),
            child: Text(
              initial,
              style: TextStyle(
                color: selected ? _gold : _sub,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          if (isDl)
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _bg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.download_done_rounded, size: 11, color: Color(0xFF4CAF50)),
              ),
            ),
        ],
      ),
      title: Text(
        r.name,
        style: TextStyle(
          color: _text,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _toggleFav(r.qulId),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: isFav ? Colors.redAccent : _sub,
              ),
            ),
          ),
        ],
      ),
      onTap: () => _select(r),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final all        = QulCatalogService.reciters;
    final currentId  = _currentQulId();
    final query      = _query.toLowerCase().trim();

    // Liste de widgets à afficher
    final items = <Widget>[];

    if (query.isNotEmpty) {
      // Recherche : liste plate filtrée
      final filtered = all.where((r) => r.name.toLowerCase().contains(query)).toList();
      if (filtered.isEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('Aucun résultat', style: TextStyle(color: _sub)),
          ),
        ));
      } else {
        for (int i = 0; i < filtered.length; i++) {
          items.add(_tile(filtered[i], currentId));
          if (i < filtered.length - 1) items.add(_divider());
        }
      }
    } else {
      // Section épinglés
      final pinned = all.where(_isPinned).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (pinned.isNotEmpty) {
        items.add(_sectionHeader('ÉPINGLÉS'));
        for (int i = 0; i < pinned.length; i++) {
          items.add(_tile(pinned[i], currentId));
          if (i < pinned.length - 1) items.add(_divider());
        }
      }

      // Sections alphabétiques
      final sorted = List<QulReciter>.from(all)
        ..sort((a, b) => a.name.compareTo(b.name));
      String? lastLetter;
      for (int i = 0; i < sorted.length; i++) {
        final r      = sorted[i];
        final letter = r.name[0].toUpperCase();
        if (letter != lastLetter) {
          lastLetter = letter;
          items.add(_sectionHeader(letter));
        }
        items.add(_tile(r, currentId));
        if (i < sorted.length - 1 &&
            sorted[i + 1].name[0].toUpperCase() == letter) {
          items.add(_divider());
        }
      }
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
      height: MediaQuery.of(context).size.height * 0.82,
      color: _bg,
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _div,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header ──────────────────────────────────────────────────────
          if (!_showSearch) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  // Icône micro dorée
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mic_rounded, color: _gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Récitateurs',
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Hafs An Assem · ${QulCatalogService.reciters.length} récitateurs',
                          style: TextStyle(color: _sub, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: _sub, size: 22),
                    onPressed: () => setState(() => _showSearch = true),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Barre de recherche ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Theme(
                        data: ThemeData(
                          brightness: widget.isDark ? Brightness.dark : Brightness.light,
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: _gold,
                            selectionColor: _gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          cursorColor: _gold,
                          style: TextStyle(color: _text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un récitateur…',
                            hintStyle: TextStyle(color: _sub, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 18),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _sub, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _showSearch = false);
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Divider(height: 1, thickness: 0.5, color: _div),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              itemBuilder: (_, i) => items[i],
            ),
          ),
        ],
      ),
    ));
  }
}
