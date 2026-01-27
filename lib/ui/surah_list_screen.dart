import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import 'widgets/surah_card.dart';
import '../hizb_juzz.dart';
import 'dart:convert';
import 'package:flutter/services.dart';


class SurahListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> surahList;
  final ValueNotifier<Set<int>> favoriteIdsNotifier;
  final void Function(int page) onOpenReader;
  final void Function(Map<String, dynamic> s) onPlaySurah;

  const SurahListScreen({
    super.key,
    required this.surahList,
    required this.favoriteIdsNotifier,
    required this.onOpenReader,
    required this.onPlaySurah,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surahsByPage = List<Map<String, dynamic>>.from(surahList)
      ..sort((a, b) => (a['page'] as int).compareTo(b['page'] as int));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coran'),
          centerTitle: true,
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
                      child: ListView.builder(
                        key: const PageStorageKey('surah_list_full'),
                        itemCount: surahList.length,
                        itemBuilder: (context, index) {
                          final s = surahList[index];
                          final int surahId = s['id'] as int;

                          return _SurahPlayingTileWidget(
                            surahId: surahId,
                            childBuilder: (isPlaying) =>
                                ValueListenableBuilder<Set<int>>(
                              valueListenable: favoriteIdsNotifier,
                              builder: (context, favoriteIds, _) {
                                return SurahCard(
                                  id: surahId,
                                  nameAr: s['nameAr'] as String,
                                  nameFr: s['nameFr'] as String,
                                  ayahCount: (s['ayahCount'] as int?) ?? 0,
                                  isFavorite: favoriteIds.contains(surahId),
                                  isPlaying: isPlaying,
                                  onTap: () => onOpenReader(s['page'] as int),
                                  onPlay: () => onPlaySurah(s),
                                  onToggleFavorite: () async {
                                    await FavoritesService.instance
                                        .toggleFavorite(surahId);
                                    favoriteIdsNotifier.value =
                                        await FavoritesService.instance
                                            .getFavorites();
                                  },
                                );
                              },
                            ),
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

                    // map id -> surah (pour récupérer nomFr/nomAr rapidement)
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
                        final Map<String, dynamic> verseMapping = meta['verse_mapping'] as Map<String, dynamic>;

                        // page de début (tu gardes ta logique existante)
                        final startPage = juzzMap[juzNumber - 1]['start_page']!;

                        // sourates présentes dans ce juz
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
                                  // Header Juz (tap => ouvre la page du juz)
                                  InkWell(
                                    onTap: () => onOpenReader(startPage),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Juz $juzNumber',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : const Color(0xFF1a0033),
                                                      ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Débute: $firstVerseKey • Page $startPage',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded,
                                              color: isDark ? Colors.white70 : Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Liste des sourates dans ce juz (tap => ouvre page)
                                  ...surahIds.map((sid) {
                                    final s = surahById[sid];
                                    final String rangeStr = (verseMapping['$sid'] as String);
                                    final r = parseRange(rangeStr);
                                    final int from = r[0], to = r[1];

                                    final nameFr = (s?['nameFr'] ?? 'Sourate $sid').toString();
                                    final nameAr = (s?['nameAr'] ?? '').toString();

                                    // IMPORTANT:
                                    // - si la plage commence à 1, on peut ouvrir la sourate à son début (page de la sourate)
                                    // - sinon on ouvre le début du juz (plus logique, car la sourate est “en cours”)
                                    final int openPage = (from == 1 && s != null) ? (s['page'] as int) : startPage;

                                    return ListTile(
                                      dense: true,
                                      title: Text(nameFr),
                                      subtitle: Text('$nameAr • Versets $from-$to'),
                                      trailing: const Icon(Icons.chevron_right_rounded),
                                      onTap: () => onOpenReader(openPage),
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
    );
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
Future<Map<int, dynamic>> loadJuzMetadata() async {
  final raw = await rootBundle.loadString('assets/data/quran-metadata-juz.json');
  final Map<String, dynamic> decoded = jsonDecode(raw);
  return decoded.map((k, v) => MapEntry(int.parse(k), v));
}

List<int> parseRange(String range) {
  final parts = range.split('-');
  return [int.parse(parts[0]), int.parse(parts[1])];
}
