import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../services/quran_image_service.dart';
import 'widgets/surah_card.dart';
import '../hizb_juzz.dart';
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
                      child: ListView.builder(
                        key: const PageStorageKey('surah_list_full'),
                        itemCount: surahList.length,
                        itemBuilder: (context, index) {
                          final s = surahList[index];
                          final int surahId = s['id'] as int;

                          return _SurahPlayingTileWidget(
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

                                    final int openPage =
                                        (from == 1 && s != null) ? (s['page'] as int) : startPage;

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

Map<int, dynamic>? _juzMetadataCache;

Future<Map<int, dynamic>> loadJuzMetadata() async {
  if (_juzMetadataCache != null) return _juzMetadataCache!;
  final raw = await rootBundle.loadString('assets/data/quran-metadata-juz.json');
  final Map<String, dynamic> decoded = jsonDecode(raw);
  _juzMetadataCache = decoded.map((k, v) => MapEntry(int.parse(k), v));
  return _juzMetadataCache!;
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
  double _fillProgress = 0.0;
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    if (!mounted) return;

    final bool isCached =
        QuranImageService.getSyncCached(widget.startPage) != null ||
        await QuranImageService.isPageCached(widget.startPage);

    if (isCached) {
      setState(() => _fillProgress = 1.0);
      if (QuranImageService.getSyncCached(widget.startPage) == null) {
        await QuranImageService.getPageFile('hafs', widget.startPage);
      }
      final file = QuranImageService.getSyncCached(widget.startPage);
      if (file != null && mounted) await precacheImage(FileImage(file), context);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 80));
      widget.onOpenReader(widget.startPage);
      if (mounted) setState(() => _fillProgress = 0.0);
      return;
    }

    setState(() { _loading = true; _fillProgress = 0.0; });
    try {
      await QuranImageService.getPageFile('hafs', widget.startPage,
          onProgress: (p) { if (mounted) setState(() => _fillProgress = p); });
    } catch (_) {}
    if (!mounted) return;

    final file = QuranImageService.getSyncCached(widget.startPage);
    if (file == null) {
      setState(() { _fillProgress = 0.0; _loading = false; });
      return;
    }

    setState(() { _fillProgress = 1.0; _loading = false; });
    await precacheImage(FileImage(file), context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    widget.onOpenReader(widget.startPage);
    if (mounted) setState(() => _fillProgress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return ClipRect(
      child: Stack(
        children: [
          InkWell(
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
          ),
          if (_fillProgress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _JuzFillPainter(
                    progress: _fillProgress,
                    color: gold.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
        ],
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
  double _fillProgress = 0.0;
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    if (!mounted) return;

    final bool isCached =
        QuranImageService.getSyncCached(widget.openPage) != null ||
        await QuranImageService.isPageCached(widget.openPage);

    if (isCached) {
      setState(() => _fillProgress = 1.0);
      if (QuranImageService.getSyncCached(widget.openPage) == null) {
        await QuranImageService.getPageFile('hafs', widget.openPage);
      }
      final file = QuranImageService.getSyncCached(widget.openPage);
      if (file != null && mounted) await precacheImage(FileImage(file), context);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 80));
      widget.onOpenReader(widget.openPage);
      if (mounted) setState(() => _fillProgress = 0.0);
      return;
    }

    setState(() { _loading = true; _fillProgress = 0.0; });
    try {
      await QuranImageService.getPageFile('hafs', widget.openPage,
          onProgress: (p) { if (mounted) setState(() => _fillProgress = p); });
    } catch (_) {}
    if (!mounted) return;

    final file = QuranImageService.getSyncCached(widget.openPage);
    if (file == null) {
      setState(() { _fillProgress = 0.0; _loading = false; });
      return;
    }

    setState(() { _fillProgress = 1.0; _loading = false; });
    await precacheImage(FileImage(file), context);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    widget.onOpenReader(widget.openPage);
    if (mounted) setState(() => _fillProgress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return ClipRect(
      child: Stack(
        children: [
          ListTile(
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
          ),
          if (_fillProgress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _JuzFillPainter(
                    progress: _fillProgress,
                    color: gold.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter — cercle qui s'étend depuis le centre (identique à SurahCard)
// ─────────────────────────────────────────────────────────────────────────────

class _JuzFillPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _JuzFillPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;
    canvas.drawCircle(center, maxRadius * progress, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_JuzFillPainter old) => old.progress != progress;
}
