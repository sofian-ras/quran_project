import 'package:flutter/material.dart';
import '../data/surah_name.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import 'widgets/surah_card.dart' show SurahCard, openPageWithPrecache;
import '../data/hizb_juzz.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'translated_quran_screen.dart';

class SurahListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> surahList;
  final ValueNotifier<Set<int>> favoriteIdsNotifier;
  final void Function(int page) onOpenReader;
  final void Function(Map<String, dynamic> s) onPlaySurah;
  final Widget? titleWidget;

  const SurahListScreen({
    super.key,
    required this.surahList,
    required this.favoriteIdsNotifier,
    required this.onOpenReader,
    required this.onPlaySurah,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarFg = isDark
        ? (Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFFF6E9D7))
        : const Color(0xFF5B3F12);

    final surahsByPage = List<Map<String, dynamic>>.from(surahList)
      ..sort((a, b) => (a['page'] as int).compareTo(b['page'] as int));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: appBarFg,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: titleWidget ?? Text(
            'Coran',
            style: TextStyle(color: appBarFg),
          ),
          centerTitle: true,

          // ✅ AJOUT : bouton pour ouvrir l’écran Traduction
          actions: [
            IconButton(
              tooltip: 'Traduction',
              icon: const Icon(Icons.translate_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TranslatedQuranScreen(preferOffline: true),
                  ),
                );
              },
            ),
          ],

          bottom: TabBar(
            labelColor: isDark ? Colors.white : const Color(0xFF1a0033),
            unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
            indicatorColor: gold,
            tabs: const [
              Tab(text: 'Sourates'),
              Tab(text: 'Juz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // =========================
            // Onglet 1 : Sourates
            // =========================
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF020617),
                          Color(0xFF0B1025),
                          Color(0xFF1A0033),
                          Color(0xFF2D1B4E),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFEFB),
                          Color(0xFFF7F2E8),
                          Color(0xFFF1E6D0),
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? gold.withOpacity(0.15) : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: FutureBuilder<Map<int, dynamic>>(
                        future: loadJuzMetadata(),
                        builder: (context, snap) {
                          final data = snap.data ?? _juzMetadataCache;
                          final Map<int, List<(int, int)>> juzBySurah =
                              data != null ? _buildJuzBySurah(data) : {};

                          return ListView.builder(
                            key: const PageStorageKey('surah_list_full'),
                            itemCount: surahList.length,
                            itemBuilder: (context, index) {
                              final s = surahList[index];
                              final int surahId = s['id'] as int;
                              final List<(int, int)> juzItems = juzBySurah[surahId] ?? [];

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SurahPlayingTileWidget(
                                    surahId: surahId,
                                    childBuilder: (isPlaying) => ValueListenableBuilder<Set<int>>(
                                      valueListenable: favoriteIdsNotifier,
                                      builder: (context, favoriteIds, _) {
                                        return SurahCard(
                                          id: surahId,
                                          page: s['page'] as int,
                                          nameAr: s['nameAr'] as String,
                                          nameFr: s['nameFr'] as String,
                                          ayahCount: (s['ayahCount'] as int?) ?? 0,
                                          isFavorite: favoriteIds.contains(surahId),
                                          isPlaying: isPlaying,
                                          onTap: () => onOpenReader(s['page'] as int),
                                          onPlay: () => onPlaySurah(s),
                                          onToggleFavorite: () async {
                                            await FavoritesService.instance.toggleFavorite(surahId);
                                            favoriteIdsNotifier.value =
                                                await FavoritesService.instance.getFavorites();
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  ...juzItems.map((item) => _JuzSubItemTile(
                                    juzNumber: item.$1,
                                    startPage: item.$2,
                                    isDark: isDark,
                                    onOpenReader: onOpenReader,
                                  )),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // =========================
            // Onglet 2 : Juz
            // =========================
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF020617),
                          Color(0xFF0B1025),
                          Color(0xFF1A0033),
                          Color(0xFF2D1B4E),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFEFB),
                          Color(0xFFF7F2E8),
                          Color(0xFFF1E6D0),
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
              ),
              child: SafeArea(
                child: FutureBuilder<Map<int, dynamic>>(
                  future: loadJuzMetadata(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final juzData = snap.data!;

                    final Map<int, Map<String, dynamic>> surahById = {
                      for (final s in surahList) (s['id'] as int): s,
                    };

                    return ListView.builder(
                      key: const PageStorageKey('juz_list_full'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: 30,
                      itemBuilder: (context, i) {
                        final juzNumber = i + 1;
                        final meta = juzData[juzNumber] as Map<String, dynamic>;

                        final String firstVerseKey = meta['first_verse_key'] as String;
                        final Map<String, dynamic> verseMapping =
                            meta['verse_mapping'] as Map<String, dynamic>;

                        final startPage = juzzMap[juzNumber - 1]['start_page']!;
                        final surahIds = verseMapping.keys.map(int.parse).toList()..sort();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? gold.withOpacity(0.15) : Colors.black12,
                                  width: 1,
                                ),
                                color: Theme.of(context).cardColor.withOpacity(isDark ? 0.06 : 0.85),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _JuzHeaderTile(
                                    juzNumber: juzNumber,
                                    firstVerseKey: firstVerseKey,
                                    startPage: startPage,
                                    isDark: isDark,
                                    onOpenReader: onOpenReader,
                                  ),
                                  ...surahIds.map((sid) {
                                    final s = surahById[sid];
                                    final String rangeStr = (verseMapping['$sid'] as String);
                                    final r = parseRange(rangeStr);
                                    final int from = r[0], to = r[1];

                                    final nameFr = (s?['nameFr'] ?? 'Sourate $sid').toString();
                                    final nameAr = (s?['nameAr'] ?? '').toString();

                                    final int openPage = startPage;

                                    return _JuzSurahTile(
                                      nameFr: nameFr,
                                      nameAr: nameAr,
                                      from: from,
                                      to: to,
                                      openPage: openPage,
                                      isDark: isDark,
                                      onOpenReader: onOpenReader,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      ), // DefaultTabController
    ); // AnnotatedRegion
  }
}

class _SurahPlayingTileWidget extends StatefulWidget {
  final int surahId;
  final Widget Function(bool isPlaying) childBuilder;

  const _SurahPlayingTileWidget({
    required this.surahId,
    required this.childBuilder,
  });

  @override
  State<_SurahPlayingTileWidget> createState() => _SurahPlayingTileWidgetState();
}

class _SurahPlayingTileWidgetState extends State<_SurahPlayingTileWidget> {
  late final AudioService _audio;
  late bool _isPlaying;

  void _handlePlayingChanged() {
    final current = _audio.currentPlayingSurahIdNotifier.value;
    final shouldBePlaying = current == widget.surahId;
    if (_isPlaying != shouldBePlaying) {
      setState(() => _isPlaying = shouldBePlaying);
    }
  }

  @override
  void initState() {
    super.initState();
    _audio = AudioService.instance;
    _isPlaying = _audio.currentPlayingSurahIdNotifier.value == widget.surahId;
    _audio.currentPlayingSurahIdNotifier.addListener(_handlePlayingChanged);
  }

  @override
  void dispose() {
    _audio.currentPlayingSurahIdNotifier.removeListener(_handlePlayingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.childBuilder(_isPlaying);
  }
}

// ── Cache global liste des sourates ──────────────────────────────────────────
List<Map<String, dynamic>>? _surahListCache;

/// Charge et parse quran_data.json une seule fois, puis retourne le cache.
/// Utilisé par home_screen, quran_tab_screen et reader_screen.
Future<List<Map<String, dynamic>>> loadSurahList() async {
  if (_surahListCache != null) return _surahListCache!;

  final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
  final quranData = json.decode(jsonStr) as List<dynamic>;

  final Map<int, int> ayahCounts = {};
  final Map<int, int> startPage = {};
  final Map<int, String> araNames = {};

  for (final v in quranData) {
    final int? id = (v['surah'] is int) ? v['surah'] as int : int.tryParse('${v['surah']}');
    if (id == null) continue;
    final int page = (v['page'] is int) ? v['page'] as int : (int.tryParse('${v['page']}') ?? 1);
    ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
    if (startPage[id] == null) {
      startPage[id] = page;
      araNames[id] = (v['sura_name'] ?? '').toString();
    }
  }

  final list = <Map<String, dynamic>>[];
  for (int id = 1; id <= 114; id++) {
    list.add({
      'id': id,
      'nameAr': araNames[id] ?? 'سورة $id',
      'nameFr': surahFr[id] ?? 'Sourate $id',
      'page': startPage[id] ?? 1,
      'ayahCount': ayahCounts[id] ?? 0,
    });
  }

  return _surahListCache = list;
}

Map<int, dynamic>? _juzMetadataCache;

Future<Map<int, dynamic>> loadJuzMetadata() async {
  if (_juzMetadataCache != null) return _juzMetadataCache!;
  final raw = await rootBundle.loadString('assets/data/quran-metadata-juz.json');
  final Map<String, dynamic> decoded = jsonDecode(raw);
  _juzMetadataCache = decoded.map((k, v) => MapEntry(int.parse(k), v));
  return _juzMetadataCache!;
}

Map<int, List<(int, int)>>? _juzBySurahCache;

Map<int, List<(int, int)>> _buildJuzBySurah(Map<int, dynamic> juzData) {
  if (_juzBySurahCache != null) return _juzBySurahCache!;
  final result = <int, List<(int, int)>>{};
  for (int n = 1; n <= 30; n++) {
    final meta = juzData[n] as Map<String, dynamic>;
    final firstVerseKey = meta['first_verse_key'] as String;
    final sid = int.parse(firstVerseKey.split(':')[0]);
    final startPage = juzzMap[n - 1]['start_page']!;
    result.putIfAbsent(sid, () => []).add((n, startPage));
  }
  return _juzBySurahCache = result;
}

List<int> parseRange(String range) {
  final parts = range.split('-');
  return [int.parse(parts[0]), int.parse(parts[1])];
}

// ─────────────────────────────────────────────────────────────────────────────
// Juz header tile avec animation de téléchargement
// ─────────────────────────────────────────────────────────────────────────────

class _JuzHeaderTile extends StatefulWidget {
  final int juzNumber;
  final String firstVerseKey;
  final int startPage;
  final bool isDark;
  final void Function(int page) onOpenReader;

  const _JuzHeaderTile({
    required this.juzNumber,
    required this.firstVerseKey,
    required this.startPage,
    required this.isDark,
    required this.onOpenReader,
  });

  @override
  State<_JuzHeaderTile> createState() => _JuzHeaderTileState();
}

class _JuzHeaderTileState extends State<_JuzHeaderTile> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    debugPrint('>>> JuzHeaderTile tapped juz=${widget.juzNumber} startPage=${widget.startPage}');
    await openPageWithPrecache(
      context, widget.startPage, () => widget.onOpenReader(widget.startPage),
      (v) { if (mounted) setState(() => _loading = v); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading ? null : _handleTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Juz ${widget.juzNumber}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : const Color(0xFF1a0033),
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Débute: ${widget.firstVerseKey} • Page ${widget.startPage}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: widget.isDark ? Colors.white70 : Colors.black54),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sourate dans un Juz avec animation de téléchargement
// ─────────────────────────────────────────────────────────────────────────────

class _JuzSurahTile extends StatefulWidget {
  final String nameFr;
  final String nameAr;
  final int from;
  final int to;
  final int openPage;
  final bool isDark;
  final void Function(int page) onOpenReader;

  const _JuzSurahTile({
    required this.nameFr,
    required this.nameAr,
    required this.from,
    required this.to,
    required this.openPage,
    required this.isDark,
    required this.onOpenReader,
  });

  @override
  State<_JuzSurahTile> createState() => _JuzSurahTileState();
}

class _JuzSurahTileState extends State<_JuzSurahTile> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    debugPrint('>>> JuzSurahTile tapped "${widget.nameFr}" openPage=${widget.openPage}');
    await openPageWithPrecache(
      context, widget.openPage, () => widget.onOpenReader(widget.openPage),
      (v) { if (mounted) setState(() => _loading = v); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        widget.nameFr,
        style: TextStyle(
          color: widget.isDark ? Colors.white : const Color(0xFF1a0033),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${widget.nameAr} • Versets ${widget.from}-${widget.to}',
        style: TextStyle(
          color: widget.isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _loading ? null : _handleTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-item Juz dans l'onglet Sourates
// ─────────────────────────────────────────────────────────────────────────────

class _JuzSubItemTile extends StatefulWidget {
  final int juzNumber;
  final int startPage;
  final bool isDark;
  final void Function(int page) onOpenReader;

  const _JuzSubItemTile({
    required this.juzNumber,
    required this.startPage,
    required this.isDark,
    required this.onOpenReader,
  });

  @override
  State<_JuzSubItemTile> createState() => _JuzSubItemTileState();
}

class _JuzSubItemTileState extends State<_JuzSubItemTile> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    debugPrint('>>> JuzSubItemTile tapped juz=${widget.juzNumber} startPage=${widget.startPage}');
    await openPageWithPrecache(
      context, widget.startPage, () => widget.onOpenReader(widget.startPage),
      (v) { if (mounted) setState(() => _loading = v); },
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final Color bg = widget.isDark
        ? gold.withValues(alpha: 0.06)
        : gold.withValues(alpha: 0.07);
    final Color textColor = widget.isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      onTap: _loading ? null : _handleTap,
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(28, 8, 14, 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Juz ${widget.juzNumber}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              'Page ${widget.startPage}',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: textColor, size: 18),
          ],
        ),
      ),
    );
  }
}
