// lib/ui/translated_quran_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_translation_pack_service.dart';
import '../services/verse_favorites_service.dart';
import '../services/audio_service.dart';
import '../services/reading_history_service.dart';
import '../services/qul_audio/qul_audio_resolver.dart';
import '../surah_name.dart';
import '../services/tafsir_service.dart' show TafsirService;
import '../services/quran_ayah_metadata_db.dart';
import 'reader_screen.dart';
import 'screens/quran_loader.dart';

// Notifier partagé entre la liste et l'en-tête (0=blanc, 1=papier, 2=sombre)
final _tqsThemeNotifier = ValueNotifier<int>(1);
// Progression du scroll de la liste des sourates (0.0 = visible, 1.0 = caché)
final _surahListScrollProgress = ValueNotifier<double>(0.0);

class TranslatedQuranScreen extends StatefulWidget {
  final bool preferOffline;

  const TranslatedQuranScreen({super.key, required this.preferOffline});

  @override
  State<TranslatedQuranScreen> createState() => _TranslatedQuranScreenState();
}

class _TranslatedQuranScreenState extends State<TranslatedQuranScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SharedPreferences.getInstance().then((p) {
      _tqsThemeNotifier.value = p.getInt('tqs_theme') ?? 1;
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tqsThemeNotifier,
      builder: (context, tqsTheme, _) {
        final isDark = tqsTheme == 2;
        final bg = isDark
            ? const Color(0xFF0B1025)
            : (tqsTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));
        final fg = isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.90);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        body: ValueListenableBuilder<double>(
          valueListenable: _surahListScrollProgress,
          builder: (context, progress, child) {
            final topPad = MediaQuery.of(context).padding.top;
            const titleH = 56.0;
            const tabH   = 46.0;
            final fixedH = topPad + titleH;
            final tabSlide = tabH * progress;

            return Stack(
              children: [
                // ── Contenu : remonte au fur et à mesure que les onglets disparaissent ──
                Positioned(
                  top: fixedH + tabH - tabSlide,
                  left: 0, right: 0, bottom: 0,
                  child: child!,
                ),
                // ── Onglets : glissent vers le haut et se cachent derrière le titre ──
                Positioned(
                  top: fixedH - tabSlide,
                  left: 0, right: 0,
                  height: tabH,
                  child: Container(
                    color: bg,
                    child: TabBar(
                      labelColor: fg,
                      unselectedLabelColor: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.50),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sourates'),
                        Tab(text: 'Favoris'),
                      ],
                    ),
                  ),
                ),
                // ── Titre fixe (toujours visible, au-dessus des onglets) ──────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: fixedH,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: tqsTheme == 2
                            ? [const Color(0xFF1C2E52), const Color(0xFF0B1025)]
                            : tqsTheme == 0
                                ? [const Color(0xFFE8E2D8), Colors.white]
                                : [const Color(0xFFBF8E48), const Color(0xFFF3E8C0)],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: topPad),
                        SizedBox(
                          height: titleH,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Coran',
                                    style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  SvgPicture.asset(
                                    'assets/images/navbar/Quran_Kareem.svg',
                                    height: 20,
                                    colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                                  ),
                                ],
                              ),
                              Positioned(
                                right: 4,
                                child: IconButton(
                                  icon: Icon(Icons.settings_outlined, color: fg, size: 22),
                                  onPressed: () => _showThemeSheet(context, tqsTheme, bg, fg),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          child: TabBarView(
            children: [
              _SurahTab(preferOffline: widget.preferOffline),
              const _FavoritesTab(),
            ],
          ),
        ),
      ),
    );
    },  // fin builder
  );    // fin ValueListenableBuilder
  }

  void _showThemeSheet(BuildContext context, int currentTheme, Color bg, Color fg) {
    final themes = [
      (label: 'Blanc',  icon: 'بِسْمِ', bg: Colors.white,              border: const Color(0xFFDDDDDD)),
      (label: 'Papier', icon: 'بِسْمِ', bg: const Color(0xFFF3E8C0),   border: const Color(0xFFC8A97E)),
      (label: 'Sombre', icon: 'بِسْمِ', bg: const Color(0xFF12192E),   border: const Color(0xFF3A4A6A)),
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setS) => Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thème', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(3, (idx) {
                        final t = themes[idx];
                        final selected = _tqsThemeNotifier.value == idx;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              _tqsThemeNotifier.value = idx;
                              setS(() {});
                              final p = await SharedPreferences.getInstance();
                              await p.setInt('tqs_theme', idx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              height: 72,
                              decoration: BoxDecoration(
                                color: t.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? const Color(0xFFC8A97E) : t.border,
                                  width: selected ? 2.0 : 1.0,
                                ),
                                boxShadow: selected ? [BoxShadow(color: const Color(0xFFC8A97E).withValues(alpha: 0.35), blurRadius: 6)] : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(t.icon, style: TextStyle(
                                    fontFamily: 'ScheherazadeNew',
                                    fontSize: 18,
                                    color: idx == 2 ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF4A3F30),
                                  )),
                                  const SizedBox(height: 4),
                                  Text(t.label, style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: idx == 2 ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF4A3F30),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab();

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  bool _loading = true;
  List<String> _keys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await VerseFavoritesService.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _keys = favs.toList()
        ..sort((a, b) {
          int sa(String k) => int.tryParse(k.split(':').first) ?? 0;
          int aa(String k) => int.tryParse(k.split(':').last) ?? 0;
          final ds = sa(a).compareTo(sa(b));
          if (ds != 0) return ds;
          return aa(a).compareTo(aa(b));
        });
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tqsThemeNotifier,
      builder: (context, tqsTheme, _) {
        final isDark = tqsTheme == 2;
        final bg     = isDark ? const Color(0xFF0B1025) : (tqsTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));
        final fg     = isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.90);
        final subtle = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55);
        final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
        final cardBg = isDark ? const Color(0xFF111827) : Colors.white.withValues(alpha: 0.6);

        if (_loading) {
          return Container(color: bg, child: const Center(child: CircularProgressIndicator()));
        }

        if (_keys.isEmpty) {
          return Container(
            color: bg,
            child: Center(child: Text('Aucun favori', style: TextStyle(color: subtle, fontWeight: FontWeight.w700))),
          );
        }

        return Container(
          color: bg,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _keys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final key = _keys[i];
              final parts = key.split(':');
              final s = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
              final a = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;
              final nameTr = surahFr[s] ?? 'Sourate $s';

              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: ListTile(
                  title: Text(nameTr, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                  subtitle: Text('Verset $a', style: TextStyle(color: subtle, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right_rounded, color: subtle),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranslatedSurahScreen(
                        surahNumber: s,
                        surahNameFr: nameTr,
                        surahNameAr: 'سورة $s',
                        preferOffline: true,
                        initialAyah: a <= 0 ? 1 : a,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

List<dynamic> _extractQuranEncList(dynamic data) {
  if (data is List) return data;
  if (data is Map<String, dynamic>) {
    final result = data['result'];
    if (result is List) return result;
  }
  return const [];
}

String _stripHtml(String input) => input.replaceAll(RegExp(r'<[^>]+>'), '');

class _SurahTab extends StatefulWidget {
  final bool preferOffline;
  const _SurahTab({required this.preferOffline});

  @override
  State<_SurahTab> createState() => _SurahTabState();
}


class _SurahTabState extends State<_SurahTab> {
  /// Liste aplatie : chaque item est soit {'type':'juz','juz':N} soit {'type':'surah',...}
  List<Map<String, dynamic>> _items = [];
  Set<int> _visitedSurahIds = {};
  bool _loading = true;
  final _scrollCtrl = ScrollController();
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    _loadTheme();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (offset <= 0) {
      _surahListScrollProgress.value = 0.0;
      return;
    }
    _surahListScrollProgress.value =
        (_surahListScrollProgress.value + delta / 80.0).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final t = p.getInt('tqs_theme') ?? 1;
    _tqsThemeNotifier.value = t;
  }

  // Page de début de chaque sourate dans le mushaf (index 0 = sourate 1).
  static const List<int> _surahStartPages = [
    1,   2,   50,  77,  106, 128, 151, 177, 187, 208,
    221, 235, 249, 255, 262, 267, 282, 293, 305, 312,
    322, 332, 342, 350, 359, 367, 377, 385, 396, 404,
    411, 415, 418, 428, 434, 440, 446, 453, 458, 467,
    477, 483, 489, 496, 499, 502, 507, 511, 515, 518,
    520, 523, 526, 528, 531, 534, 537, 542, 545, 549,
    551, 553, 554, 556, 558, 560, 562, 564, 566, 568,
    570, 572, 574, 575, 577, 578, 580, 582, 583, 585,
    586, 587, 587, 589, 590, 591, 591, 592, 593, 594,
    595, 595, 596, 596, 597, 597, 598, 598, 599, 599,
    600, 600, 601, 601, 601, 602, 602, 602, 603, 603,
    603, 604, 604, 604,
  ];

  // juz N → (surahId du début, ayah du début)
  static const _juzStarts = <int, (int, int)>{
    1:  (1,   1),   2:  (2,   142), 3:  (2,   253),
    4:  (3,   92),  5:  (4,   24),  6:  (4,   148),
    7:  (5,   82),  8:  (6,   111), 9:  (7,   87),
    10: (8,   41),  11: (9,   93),  12: (11,  5),
    13: (12,  52),  14: (15,  1),   15: (17,  1),
    16: (18,  75),  17: (21,  1),   18: (23,  1),
    19: (25,  20),  20: (27,  55),  21: (29,  45),
    22: (33,  31),  23: (36,  22),  24: (39,  32),
    25: (41,  47),  26: (46,  1),   27: (51,  31),
    28: (58,  1),   29: (67,  1),   30: (78,  1),
  };

  Future<void> _loadSurahs() async {
    final List<Map<String, dynamic>> flat = [];

    // Grouper les juz par surah d'insertion
    final Map<int, List<int>> juzBefore = {}; // surahId → liste de juz
    for (final entry in _juzStarts.entries) {
      final surahId = entry.value.$1;
      juzBefore.putIfAbsent(surahId, () => []).add(entry.key);
    }

    for (int i = 0; i < 114; i++) {
      final id   = i + 1;
      final page = _surahStartPages[i];

      // Insérer les juz qui commencent dans (ou avant) cette sourate
      if (juzBefore.containsKey(id)) {
        for (final juz in juzBefore[id]!) {
          final (s, a) = _juzStarts[juz]!;
          flat.add({'type': 'juz', 'juz': juz, 'surah': s, 'ayah': a});
        }
      }

      flat.add({
        'type': 'surah',
        'id': id,
        'nameAr': TafsirService.surahNames[i],
        'page': page,
        'ayahCount': TafsirService.surahAyahCounts[i],
      });
    }

    // Sourates visitées via l'historique de lecture
    final history = await ReadingHistoryService.instance.getHistory(limit: 500);
    final visited = <int>{};
    for (final h in history) {
      final sid = h['surahId'];
      if (sid is int) visited.add(sid);
    }

    if (!mounted) return;
    setState(() {
      _items = flat;
      _visitedSurahIds = visited;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');

    return ValueListenableBuilder<int>(
      valueListenable: _tqsThemeNotifier,
      builder: (context, tqsTheme, _) {
        final isDark = tqsTheme == 2;
        final bg = isDark
            ? const Color(0xFF0B1025)
            : (tqsTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));
        final titleColor = isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.90);
        final subColor = isDark ? Colors.white.withValues(alpha: 0.50) : Colors.black.withValues(alpha: 0.45);
        final dividerColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06);
        final accentColor = isDark ? const Color(0xFF7986CB) : const Color(0xFF3949AB);
        final arColor = isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF3D2B0E);

    return Container(
      color: bg,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];

          // ── Juz banner ───────────────────────────────────────────
          if (item['type'] == 'juz') {
            final juz   = item['juz']   as int;
            final surah = item['surah'] as int;
            final ayah  = item['ayah']  as int;
            final nameAr = TafsirService.surahNames[surah - 1];
            final nameFr = isEn ? (surahEn[surah] ?? 'Surah $surah') : (surahFr[surah] ?? 'Sourate $surah');
            return _JuzBanner(
              juz: juz,
              surah: surah,
              ayah: ayah,
              tqsTheme: tqsTheme,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TranslatedSurahScreen(
                    surahNumber: surah,
                    surahNameFr: nameFr,
                    surahNameAr: nameAr,
                    preferOffline: widget.preferOffline,
                    initialAyah: ayah,
                  ),
                ),
              ).then((_) => _loadTheme()),
            );
          }

          // ── Surah item ───────────────────────────────────────────
          final surahId = item['id'] as int;
          final nameAr = (item['nameAr'] ?? '').toString();
          final nameTr = isEn ? (surahEn[surahId] ?? 'Surah $surahId') : (surahFr[surahId] ?? 'Sourate $surahId');
          final ayahCount = item['ayahCount'] as int;

          final meaning = surahMeaning[surahId];
          final isVisited = _visitedSurahIds.contains(surahId);


          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16, color: dividerColor),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TranslatedSurahScreen(
                      surahNumber: surahId,
                      surahNameFr: nameTr,
                      surahNameAr: nameAr,
                      preferOffline: widget.preferOffline,
                    ),
                  ),
                ).then((_) => _loadTheme()),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$surahId',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isVisited ? accentColor : subColor,
                                fontSize: surahId > 99 ? 11 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ── Nom fr + infos ─────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(nameTr, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                if (meaning != null) ...[
                                  Text('"$meaning"', style: TextStyle(color: subColor.withValues(alpha: 0.75), fontSize: 11, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 1),
                                ],
                                Text('$ayahCount ${isEn ? 'verses' : 'versets'}',
                                    style: TextStyle(color: subColor, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ── Nom arabe à droite ──────────────────
                          Text(
                            nameAr,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF4A3820),
                              fontSize: 20,
                              fontFamily: 'ScheherazadeNew',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
      },
    );
  }
}


// ── Mushaf ornamental frame ────────────────────────────────────────────────

class _BasmalaTitle extends StatelessWidget {
  final Color color;
  final double fontSize;
  const _BasmalaTitle({required this.color, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'ScheherazadeNew',
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 0.8, color: color.withValues(alpha: 0.45)),
            const SizedBox(width: 5),
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.55), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Container(width: 40, height: 0.8, color: color.withValues(alpha: 0.45)),
          ],
        ),
      ],
    );
  }
}

// ── Badge verset (médaillon islamique octogonal) ──────────────────────────
class _VerseBadge extends StatelessWidget {
  final int number;
  final Color color;

  const _VerseBadge({required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _VerseBadgePainter(color),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: color,
              fontSize: number > 99 ? 7.5 : (number > 9 ? 8.5 : 9.5),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerseBadgePainter extends CustomPainter {
  final Color color;
  const _VerseBadgePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1.5;

    final stroke = Paint()
      ..color = color
      ..strokeWidth = 0.65
      ..style = PaintingStyle.stroke;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, stroke);
    // Inner circle
    canvas.drawCircle(Offset(cx, cy), r * 0.68, stroke);

    // 8 tiny filled diamonds around the outer circle
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8 - math.pi / 2;
      final tx = cx + r * math.cos(angle);
      final ty = cy + r * math.sin(angle);
      const d = 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(tx, ty - d)
          ..lineTo(tx + d, ty)
          ..lineTo(tx, ty + d)
          ..lineTo(tx - d, ty)
          ..close(),
        Paint()..color = color..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_VerseBadgePainter old) => old.color != color;
}

// ── Bandeau de séparation de Juz ─────────────────────────────────────────
class _JuzBanner extends StatelessWidget {
  final int juz;
  final int surah;
  final int ayah;
  final int tqsTheme;
  final VoidCallback onTap;

  const _JuzBanner({required this.juz, required this.surah, required this.ayah, required this.tqsTheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = tqsTheme == 2;
    final bg = isDark ? const Color(0xFF0B1025) : (tqsTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));
    final textColor = isDark ? const Color(0xFFD4A855) : const Color(0xFF7A5420);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Text(
              'Juz $juz',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              'S.$surah · v.$ayah',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class TranslatedSurahScreen extends StatefulWidget {
  final int surahNumber;
  final String surahNameFr;
  final String surahNameAr;
  final bool preferOffline;
  final int initialAyah;

  const TranslatedSurahScreen({
    super.key,
    required this.surahNumber,
    required this.surahNameFr,
    required this.surahNameAr,
    required this.preferOffline,
    this.initialAyah = 1,
  });

  @override
  State<TranslatedSurahScreen> createState() => _TranslatedSurahScreenState();
}

class _TranslatedSurahScreenState extends State<TranslatedSurahScreen>
    with SingleTickerProviderStateMixin {
  bool _surahDownloaded = false;
  bool _checkingSurahDownloaded = false;
  bool _downloadingSurah = false;
  double _downloadProgress = 0.0;
  CancelToken? _downloadCancel;
  bool _shouldShowBasmalaForThisSurah() {
    return widget.surahNumber != 1 && widget.surahNumber != 9;
  }

  String _pad3(int v) => v.toString().padLeft(3, '0');

  String _ayahFileName(int surah, int ayah) => '${_pad3(surah)}${_pad3(ayah)}.mp3';

  /// Résout l'URL QUL pour un verset donné (async, peut être null si indisponible).
  Future<String?> _ayahUrlForCurrentReciter(int surah, int ayah) {
    final reciter = AudioService.instance.currentAyahReciterNotifier.value;
    return QulAudioResolver.instance.resolveAyah(reciter, surah, ayah);
  }

  Future<bool> _isCurrentSurahDownloaded() async {
    if (_arabic.isEmpty) return false;

    try {
      final outDir = await _ensureSurahAudioDir();
      final total = _arabic.length;

      for (int ayah = 1; ayah <= total; ayah++) {
        final file = File('${outDir.path}/${_ayahFileName(widget.surahNumber, ayah)}');
        if (!await file.exists()) return false;
        if ((await file.length()) <= 0) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshSurahDownloadedFlag() async {
    if (_checkingSurahDownloaded) return;

    setState(() => _checkingSurahDownloaded = true);
    final ok = await _isCurrentSurahDownloaded();
    if (!mounted) return;

    setState(() {
      _surahDownloaded = ok;
      _checkingSurahDownloaded = false;
    });
  }

  Future<Directory> _ensureSurahAudioDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reciter = AudioService.instance.currentAyahReciterNotifier.value;
    final folderId = reciter.quranComId?.toString() ?? 'qul_${reciter.qulId}';
    final path = '${dir.path}/ayah_cache/$folderId/${_pad3(widget.surahNumber)}';
    final out = Directory(path);
    if (!await out.exists()) {
      await out.create(recursive: true);
    }
    return out;
  }

  Future<void> _downloadCurrentSurahAudioFromBar() async {
    if (_downloadingSurah) return;
    if (_arabic.isEmpty) return;

    setState(() {
      _downloadingSurah = true;
      _downloadProgress = 0.0;
      _downloadCancel = CancelToken();
    });

    try {
      final outDir = await _ensureSurahAudioDir();
      final total = _arabic.length;

      for (int ayah = 1; ayah <= total; ayah++) {
        if (_downloadCancel?.isCancelled == true) break;

        final file = File('${outDir.path}/${_ayahFileName(widget.surahNumber, ayah)}');

        // si déjà téléchargé, on saute
        if (await file.exists() && (await file.length()) > 0) {
          setState(() => _downloadProgress = ayah / total);
          continue;
        }

        final url = await _ayahUrlForCurrentReciter(widget.surahNumber, ayah);
        if (url == null) continue; // récitateur indisponible sur QUL

        final res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes, followRedirects: true),
          cancelToken: _downloadCancel,
        );

        final bytes = res.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Fichier vide: $url');
        }

        await file.writeAsBytes(bytes, flush: true);

        if (!mounted) return;
        setState(() => _downloadProgress = ayah / total);
      }
    } catch (_) {
      // silence (ou SnackBar si tu veux)
    } finally {
      if (!mounted) return;
        setState(() {
          _downloadingSurah = false;
          _downloadCancel = null;
          _downloadProgress = 0.0;
        });

        await _refreshSurahDownloadedFlag();
    }
  }

  void _cancelSurahDownload() {
    _downloadCancel?.cancel('cancel');
  }


  String _removeLeadingBasmalaIfPresent(String input) {
    final s = input.trimLeft();

    // On ne touche que si ça commence bien par "بسم"
    if (!s.startsWith('ب') && !s.contains('بِسْمِ')) return input;

    // Cherche la fin de la basmala avec plusieurs variantes possibles
    const candidates = <String>[
      'ٱلرَّحِيمِ',
      'ٱلرَّحِيم',
      'الرَّحِيمِ',
      'الرَّحِيم',
      'الرحيم',
    ];

    int endIndex = -1;
    String? matched;

    for (final c in candidates) {
      final i = s.indexOf(c);
      if (i != -1 && (endIndex == -1 || i < endIndex)) {
        endIndex = i;
        matched = c;
      }
    }

    if (endIndex == -1 || matched == null) return input;

    final cut = endIndex + matched.length;

    // Sécurité : on coupe seulement si la basmala est vraiment au début (sinon on risque de casser un verset)
    // La basmala est courte, donc si la fin trouvée est trop loin, on ne coupe pas.
    if (cut > 90) return input;

    return s.substring(cut).trimLeft();
  }


  // Option 1: enlever "(128kbps)" etc
  String _cleanReciterName(String s) {
    return s.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();
  }

  bool _loading = true;
  bool _contentReady = false;
  String? _error;

  List<String> _arabic = [];
  List<String> _translation = [];
  List<String> _tafsir = [];

  bool _showArabic = true;
  bool _showTranslation = true;
  bool _showTajweed = true;
  // 0 = blanc · 1 = papier · 2 = sombre
  int _localTheme = 1;
  double _fontArabic = 22;
  double _fontTranslation = 16;
  double _fontTafsir = 14;

  Set<String> _favoriteKeys = <String>{};

  // --- Auto-center precise (no more "approxItem") ---
  final Map<int, GlobalKey> _ayahItemKeys = <int, GlobalKey>{};

  GlobalKey _keyForAyah(int ayah) {
    return _ayahItemKeys.putIfAbsent(ayah, () => GlobalKey());
  }

  // Calcule l'offset initial à partir des longueurs réelles des textes arabes chargés
  double _computeInitialOffset(int ayah) {
    if (ayah <= 1 || _arabic.isEmpty) return 0;
    double offset = 120.0; // header (SVG sourate + basmala)
    final limit = (ayah - 1).clamp(0, _arabic.length);
    for (int i = 0; i < limit; i++) {
      // Le texte coranique UTF-16 inclut les harakats (diacritiques),
      // ~3 code units par caractère visuel → diviser par 30 pour les lignes visuelles
      final lines = (_arabic[i].length / 30.0).ceil().clamp(1, 30);
      offset += 28.0 + lines * 38.0 + 70.0;
    }
    return offset;
  }

  void _ensureAyahCentered(int ayah) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _ayahItemKeys[ayah]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.1, duration: Duration.zero);
    });
  }

  late ScrollController _scrollController;
  // 0.0 = barres visibles · 1.0 = barres cachées
  final ValueNotifier<double> _barProgress = ValueNotifier(0.0);
  double _lastScrollOffset = 0.0;
  late AnimationController _snapController;
  late Animation<double> _snapAnim;
  late final Listenable _audioListenable;
  int _selectedAyah = 1;

  int _repeatTimes = 1;
  bool _loopRangeEnabled = false;
  int? _loopStartAyah;
  int? _loopEndAyah;

  int _rangeRepeatTimes = 1;
  int _eachAyahRepeatTimes = 1;

  double _playbackSpeed = 1.0;

  String _translationKey = 'french_hameedullah';
  String _tafsirKey = 'french_mokhtasar';

  static const Map<String, String> _translationOptions = {
    'FR • Hamidullah': 'french_hameedullah',
    'EN • Saheeh International': 'english_saheeh',
  };

  static const Map<String, String> _tafsirOptions = {
    'FR • Mokhtasar': 'french_mokhtasar',
  };

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  static const _quranEncBase = 'https://quranenc.com/api/v1';
  static const _alquranBase = 'https://api.alquran.cloud/v1';

  @override
  void initState() {
    super.initState();
    _selectedAyah = widget.initialAyah <= 0 ? 1 : widget.initialAyah;
    _scrollController = ScrollController();
    _playbackSpeed = AudioService.instance.ayahSpeedNotifier.value;
    AudioService.instance.ayahPlayModeNotifier.value = AyahPlayMode.continuous;
    _repeatTimes = 1;
    _audioListenable = Listenable.merge([
      AudioService.instance.currentAyahKeyNotifier,
      AudioService.instance.ayahPlayModeNotifier,
      AudioService.instance.isAyahPlayingNotifier,
      AudioService.instance.currentAyahReciterNotifier,
      AudioService.instance.ayahSpeedNotifier,
    ]);

    Future.microtask(() async {
      await Future.wait([_loadSettings(), _loadFavorites(), _loadArabicImmediate()]);
      _attachAyahListener();
      _loadTranslationsBackground();
    });

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() => _barProgress.value = _snapAnim.value);

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _snapController.stop();
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (offset <= 0) {
      _barProgress.value = 0.0;
      return;
    }
    _barProgress.value = (_barProgress.value + delta / 90.0).clamp(0.0, 1.0);
  }

  void _snapBars(bool hide) {
    _snapAnim = Tween<double>(begin: _barProgress.value, end: hide ? 1.0 : 0.0)
        .animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    _snapController.forward(from: 0);
  }

  static const _kTheme       = 'tqs_theme';
  static const _kFontArabic  = 'tqs_font_arabic';
  static const _kTajweed     = 'tqs_tajweed';
  static const _kTranslation = 'tqs_translation';
  static const _kArabic      = 'tqs_arabic';

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _localTheme      = p.getInt(_kTheme)        ?? 1;
      _fontArabic      = p.getDouble(_kFontArabic) ?? 22;
      _fontTranslation = (_fontArabic * 0.76).clamp(12, 26);
      _fontTafsir      = (_fontArabic * 0.68).clamp(11, 24);
      _showTajweed     = p.getBool(_kTajweed)      ?? true;
      _showTranslation = p.getBool(_kTranslation)  ?? true;
      _showArabic      = p.getBool(_kArabic)       ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTheme, _localTheme);
    await p.setDouble(_kFontArabic, _fontArabic);
    await p.setBool(_kTajweed, _showTajweed);
    await p.setBool(_kTranslation, _showTranslation);
    await p.setBool(_kArabic, _showArabic);
  }

  void _attachAyahListener() {
    AudioService.instance.currentAyahKeyNotifier.removeListener(_onCurrentAyahChanged);
    AudioService.instance.currentAyahKeyNotifier.addListener(_onCurrentAyahChanged);
  }

  void _onCurrentAyahChanged() {
    if (!mounted) return;

    final key = AudioService.instance.currentAyahKeyNotifier.value;
    if (key == null) return;

    final parts = key.split(':');
    if (parts.length != 2) return;

    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1]);
    if (s == null || a == null) return;

    if (s != widget.surahNumber) return;
    if (_arabic.isEmpty) return;

    final targetAyah = a.clamp(1, _arabic.length);
    _setSelectedAyah(targetAyah, scroll: true, center: true);
  }

  @override
  void dispose() {
    AudioService.instance.currentAyahKeyNotifier.removeListener(_onCurrentAyahChanged);
    _scrollController.dispose();
    _snapController.dispose();
    _barProgress.dispose();
    super.dispose();
  }

  // Couleurs pilotées par _localTheme (0=blanc, 1=papier, 2=sombre)
  bool get _isDark => _localTheme == 2;
  Color _bg(bool _) => _isDark ? const Color(0xFF0B1025) : (_localTheme == 0 ? Colors.white : const Color(0xFFF3E8C0));
  Color _text(bool _) => _isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.90);
  Color _muted(bool _) => _isDark ? Colors.white.withValues(alpha: 0.62) : Colors.black.withValues(alpha: 0.58);
  Color _border(bool _) => _isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
  Color _accent(bool _) => _isDark ? const Color(0xFFE3C880) : const Color(0xFFB37A2A);

  Future<void> _loadFavorites() async {
    final favs = await VerseFavoritesService.instance.getFavorites();
    if (!mounted) return;
    setState(() => _favoriteKeys = favs);
  }

  Future<void> _loadTafsirOnlineFallback() async {
    try {
      final tafRes = await _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}');
      final tafAyahs = _extractQuranEncList(tafRes.data);
      final list = tafAyahs.map((e) => _stripHtml((e['translation'] ?? '').toString())).toList();
      if (list.isNotEmpty) _tafsir = list;
    } catch (_) {}
  }

  void _normalizeLengths() {
    final n = _arabic.length;
    if (_translation.length < n) {
      _translation = [
        ..._translation,
        for (int i = _translation.length; i < n; i++) '',
      ];
    }
    if (_tafsir.length < n) {
      _tafsir = [
        ..._tafsir,
        for (int i = _tafsir.length; i < n; i++) '',
      ];
    }
    if (_translation.length > n) _translation = _translation.take(n).toList();
    if (_tafsir.length > n) _tafsir = _tafsir.take(n).toList();
  }

  bool _isTafsirMostlyEmpty() {
    if (_tafsir.isEmpty) return true;
    int empty = 0;
    for (final t in _tafsir) {
      if (t.trim().isEmpty) empty++;
    }
    return empty >= (_tafsir.length * 0.85);
  }

  // Phase 1 : charge l'arabe depuis la DB bundlée → affichage immédiat sans spinner
  Future<void> _loadArabicImmediate() async {
    try {
      final texts = await QuranAyahMetadataDb.instance.getSurahTexts(widget.surahNumber);
      final count = TafsirService.surahAyahCounts[widget.surahNumber - 1];
      _arabic = List.generate(count, (i) => texts['${widget.surahNumber}:${i + 1}'] ?? '');
      _translation = List.filled(_arabic.length, '');
      _tafsir      = List.filled(_arabic.length, '');
      _selectedAyah = _selectedAyah.clamp(1, _arabic.isEmpty ? 1 : _arabic.length);
      _loopStartAyah ??= _selectedAyah;
      _loopEndAyah   ??= (_selectedAyah + 1).clamp(1, _arabic.isEmpty ? 1 : _arabic.length);
    } catch (_) {}

    if (!mounted) return;

    // Recréer le contrôleur avec l'offset calculé depuis le texte arabe réel.
    // _loading est encore true → le ListView n'est pas encore attaché → dispose safe.
    if (_selectedAyah > 1 && _arabic.isNotEmpty) {
      _scrollController.removeListener(_onScroll);
      _scrollController.dispose();
      _scrollController = ScrollController(
        initialScrollOffset: _computeInitialOffset(_selectedAyah),
      );
      _scrollController.addListener(_onScroll);
    }

    setState(() {
      _loading = false;
      _contentReady = false;
      if (_arabic.isEmpty) _error = 'Erreur de chargement du texte arabe';
    });

    // Attendre que le ListView soit construit, corriger la position, puis révéler le contenu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_arabic.isNotEmpty && _selectedAyah > 1) {
        final ctx = _ayahItemKeys[_selectedAyah]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.1, duration: Duration.zero);
        }
      }
      setState(() => _contentReady = true);
    });
  }

  // Phase 2 : charge les traductions en arrière-plan (pas de spinner)
  Future<void> _loadTranslationsBackground() async {
    try {
      final lang = AppLang.fr;
      final packReady = await QuranTranslationPackService.isPackReady(lang);

      // Téléchargement automatique en arrière-plan (sans bloquer les traductions)
      if (!packReady) {
        QuranTranslationPackService.downloadPack(lang).catchError((_) {});
      }

      if (packReady) {
        final dbPath = await QuranTranslationPackService.getDbPath(lang);
        final db = await openDatabase(dbPath, readOnly: true);
        final rows = await db.query(
          'verses',
          columns: ['ayah', 'ar', 'fr', 'tafsir'],
          where: 'surah = ?',
          whereArgs: [widget.surahNumber],
          orderBy: 'ayah ASC',
        );
        await db.close();

        if (rows.isNotEmpty && mounted) {
          setState(() {
            _arabic      = rows.map((r) => (r['ar']     as String?) ?? '').toList();
            _translation = rows.map((r) => (r['fr']     as String?) ?? '').toList();
            _tafsir      = rows.map((r) => (r['tafsir'] as String?) ?? '').toList();
            _normalizeLengths();
          });
          await _refreshSurahDownloadedFlag();
          return;
        }
      }

      // Fallback réseau : traduction + tafsir en parallèle
      final results = await Future.wait([
        _dio.get('$_alquranBase/surah/${widget.surahNumber}/quran-uthmani'),
        _dio.get('$_quranEncBase/translation/sura/$_translationKey/${widget.surahNumber}'),
        _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}'),
      ]);

      if (!mounted) return;
      final arAyahs  = (results[0].data['data']['ayahs'] as List);
      final trAyahs  = _extractQuranEncList(results[1].data);
      final tafAyahs = _extractQuranEncList(results[2].data);

      setState(() {
        _arabic      = arAyahs.map((e)  => (e['text']        ?? '').toString()).toList();
        _translation = trAyahs.map((e)  => _stripHtml((e['translation'] ?? '').toString())).toList();
        _tafsir      = tafAyahs.map((e) => _stripHtml((e['translation'] ?? '').toString())).toList();
        _normalizeLengths();
      });

      await _refreshSurahDownloadedFlag();
      if (_isTafsirMostlyEmpty()) {
        await _loadTafsirOnlineFallback();
        if (mounted) setState(_normalizeLengths);
      }
    } catch (_) {} // silencieux : l'arabe est déjà affiché
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _contentReady = false;
      _error = null;
    });

    try {
      final lang = AppLang.fr;
      final packReady = await QuranTranslationPackService.isPackReady(lang);
      final tryOfflineFirst = widget.preferOffline && packReady;

      bool loaded = false;

      if (tryOfflineFirst) {
        try {
          final dbPath = await QuranTranslationPackService.getDbPath(lang);
          final db = await openDatabase(dbPath, readOnly: true);

          final rows = await db.query(
            'verses',
            columns: ['ayah', 'ar', 'fr', 'tafsir'],
            where: 'surah = ?',
            whereArgs: [widget.surahNumber],
            orderBy: 'ayah ASC',
          );

          await db.close();

          _arabic = rows.map((r) => (r['ar'] as String?) ?? '').toList();
          _translation = rows.map((r) => (r['fr'] as String?) ?? '').toList();
          _tafsir = rows.map((r) => (r['tafsir'] as String?) ?? '').toList();

          if (_arabic.isNotEmpty) loaded = true;
        } catch (_) {}
      }

      if (!loaded) {
        final results = await Future.wait([
          _dio.get('$_alquranBase/surah/${widget.surahNumber}/quran-uthmani'),
          _dio.get('$_quranEncBase/translation/sura/$_translationKey/${widget.surahNumber}'),
          _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}'),
        ]);

        final arRes = results[0] as Response;
        final trRes = results[1] as Response;
        final tafRes = results[2] as Response;

        final arAyahs = (arRes.data['data']['ayahs'] as List);
        _arabic = arAyahs.map((e) => (e['text'] ?? '').toString()).toList();

        final trAyahs = _extractQuranEncList(trRes.data);
        _translation = trAyahs.map((e) => _stripHtml((e['translation'] ?? '').toString())).toList();

        final tafAyahs = _extractQuranEncList(tafRes.data);
        _tafsir = tafAyahs.map((e) => _stripHtml((e['translation'] ?? '').toString())).toList();

        loaded = _arabic.isNotEmpty;
      }

      if (_arabic.isNotEmpty) {
        _normalizeLengths();
        await _refreshSurahDownloadedFlag();
        if (_isTafsirMostlyEmpty()) {
          await _loadTafsirOnlineFallback();
          _normalizeLengths();
        }

        _selectedAyah = _selectedAyah.clamp(1, _arabic.length);
        _loopStartAyah ??= _selectedAyah;
        _loopEndAyah ??= (_selectedAyah + 1).clamp(1, _arabic.length);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _setSelectedAyah(_selectedAyah, scroll: true, center: true);
        });
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!loaded && _arabic.isEmpty) {
          _error = 'Aucun verset chargé. Vérifie internet/offline pack.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _verseKey(int ayah) => '${widget.surahNumber}:$ayah';

  void _setSelectedAyah(int ayah, {bool scroll = true, bool center = false}) {
    if (_arabic.isEmpty) return;
    ayah = ayah.clamp(1, _arabic.length);

    setState(() => _selectedAyah = ayah);

    if (!scroll) return;

    // ✅ centre exactement le verset à l'écran
    _ensureAyahCentered(ayah);
  }

  void _cycleRepeatFromBar() {
    if (_loopRangeEnabled) {
      setState(() => _loopRangeEnabled = false);
    }

    int next;
    if (_repeatTimes == 1) {
      next = 3;
    } else if (_repeatTimes == 3) {
      next = 5;
    } else if (_repeatTimes == 5) {
      next = -1;
    } else {
      next = 1;
    }

    setState(() => _repeatTimes = next);

    final svc = AudioService.instance;
    if (next == -1) {
      svc.ayahPlayModeNotifier.value = AyahPlayMode.repeatOne;
    } else {
      svc.ayahPlayModeNotifier.value = AyahPlayMode.single;
    }
  }

  String _repeatLabel() => _repeatTimes == -1 ? '∞' : '×$_repeatTimes';

  Future<void> _playSelectedAyah() async {
    final svc = AudioService.instance;
    final ayah = _selectedAyah;

    try {
      if (_arabic.isEmpty) return;

      if (_loopRangeEnabled && _loopStartAyah != null && _loopEndAyah != null) {
        final start = _loopStartAyah!.clamp(1, _arabic.length);
        final end = _loopEndAyah!.clamp(1, _arabic.length);
        final a = start <= end ? start : end;
        final b = start <= end ? end : start;

        if (_eachAyahRepeatTimes > 1) {
          await svc.playAyahRangeEachAyahRepeatTimes(
            surah: widget.surahNumber,
            startAyah: a,
            endAyah: b,
            timesEach: _eachAyahRepeatTimes,
          );
          return;
        }

        if (_rangeRepeatTimes != 1) {
          await svc.playAyahRangeRepeatTimes(
            surah: widget.surahNumber,
            startAyah: a,
            endAyah: b,
            times: _rangeRepeatTimes,
          );
          return;
        }

        await svc.playAyahRangeLoop(surah: widget.surahNumber, startAyah: a, endAyah: b);
        return;
      }

      if (_repeatTimes == -1) {
        await svc.playAyahRepeatOne(widget.surahNumber, ayah);
        return;
      }

      if (_repeatTimes > 1) {
        await svc.playAyahRepeatTimes(widget.surahNumber, ayah, _repeatTimes);
        return;
      }

      final mode = svc.ayahPlayModeNotifier.value;
      if (mode == AyahPlayMode.continuous) {
        await svc.playAyahRange(surah: widget.surahNumber, startAyah: ayah, endAyah: _arabic.length);
      } else if (mode == AyahPlayMode.repeatOne) {
        await svc.playAyahRepeatOne(widget.surahNumber, ayah);
      } else {
        await svc.playAyah(widget.surahNumber, ayah);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur audio : $e')));
    }
  }

  Future<void> _togglePlayPauseFromBar() async {
    final svc = AudioService.instance;
    final key = svc.currentAyahKeyNotifier.value;
    final selectedKey = _verseKey(_selectedAyah);
    final isPlaying = svc.isAyahPlayingNotifier.value;

    if (isPlaying && key == selectedKey) {
      await svc.pauseAyah();
      return;
    }
    await _playSelectedAyah();
  }

  Future<void> _playPrevFromBar() async {
    if (_selectedAyah <= 1) return;
    _setSelectedAyah(_selectedAyah - 1, center: true);
    await _playSelectedAyah();
  }

  Future<void> _playNextFromBar() async {
    if (_arabic.isEmpty) return;
    if (_selectedAyah >= _arabic.length) return;
    _setSelectedAyah(_selectedAyah + 1, center: true);
    await _playSelectedAyah();
  }

  Future<void> _stopFromBar() async {
    await AudioService.instance.stopAyah();
    AudioService.instance.currentAyahKeyNotifier.value = null;
  }

  void _showSettingsSheet() {
    const green = Color(0xFF43A047);
    const sheetBg = Color(0xFFF8FAFB);
    const labelC = Color(0xFF1C1C1E);
    const sectionC = Color(0xFF8E8E93);
    const divC = Color(0xFFE5E7EB);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (_, setS) {

            // ── Thème card ────────────────────────────────────────────
            Widget themeCard({
              required int idx,
              required String label,
              required Color bg,
              required Color fgC,
            }) {
              final selected = _localTheme == idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setS(() => _localTheme = idx);
                    setState(() => _localTheme = idx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? green : divC,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: green.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بِسْمِ',
                          style: TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 18,
                            color: selected ? green : fgC.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? green : sectionC,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // ── Ligne toggle ──────────────────────────────────────────
            Widget toggleRow({
              required IconData icon,
              required String label,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: value
                            ? green.withValues(alpha: 0.10)
                            : const Color(0xFFEEF0F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18,
                          color: value ? green : sectionC),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  color: labelC,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          Text(subtitle,
                              style: const TextStyle(
                                  color: sectionC, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: value,
                      onChanged: (v) {
                        onChanged(v);
                        if (mounted) setState(() {});
                      },
                      activeTrackColor: green,
                      activeColor: green,
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: divC,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Affichage',
                        style: TextStyle(color: labelC, fontSize: 18, fontWeight: FontWeight.w700)),

                    // ── THÈME ────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 22, bottom: 10),
                      child: Text('THÈME', style: TextStyle(color: sectionC, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    ),
                    Row(
                      children: [
                        themeCard(idx: 0, label: 'Blanc', bg: Colors.white, fgC: Colors.black),
                        const SizedBox(width: 10),
                        themeCard(idx: 1, label: 'Papier', bg: const Color(0xFFF3E8C0), fgC: Colors.black),
                        const SizedBox(width: 10),
                        themeCard(idx: 2, label: 'Sombre', bg: const Color(0xFF0B1025), fgC: Colors.white),
                      ],
                    ),

                    // ── TAILLE DU TEXTE ──────────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 22, bottom: 4),
                      child: Text('TAILLE DU TEXTE', style: TextStyle(color: sectionC, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.text_fields_rounded, size: 15, color: sectionC),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(_).copyWith(
                              activeTrackColor: green,
                              thumbColor: green,
                              inactiveTrackColor: divC,
                              overlayColor: green.withValues(alpha: 0.12),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            ),
                            child: Slider(
                              min: 16,
                              max: 36,
                              value: _fontArabic.clamp(16, 36),
                              onChanged: (v) {
                                setS(() {
                                  _fontArabic = v;
                                  _fontTranslation = (v * 0.76).clamp(12, 26);
                                  _fontTafsir = (v * 0.68).clamp(11, 24);
                                });
                                if (mounted) { setState(() {
                                  _fontArabic = v;
                                  _fontTranslation = (v * 0.76).clamp(12, 26);
                                  _fontTafsir = (v * 0.68).clamp(11, 24);
                                }); }
                              },
                            ),
                          ),
                        ),
                        const Icon(Icons.text_fields_rounded, size: 22, color: sectionC),
                      ],
                    ),
                    // Aperçu live
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _localTheme == 2 ? const Color(0xFF12192E) : (_localTheme == 0 ? const Color(0xFFF5F5F5) : const Color(0xFFEDE0B8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _fontArabic,
                          fontFamily: 'ScheherazadeNew',
                          fontWeight: FontWeight.w600,
                          color: _localTheme == 2 ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.82),
                          height: 1.6,
                        ),
                      ),
                    ),

                    // ── OPTIONS ──────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 6),
                      child: Text('OPTIONS', style: TextStyle(color: sectionC, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: divC),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                            child: toggleRow(
                              icon: Icons.palette_outlined,
                              label: 'Couleurs tajwīd',
                              subtitle: 'Coloriser les règles de récitation',
                              value: _showTajweed,
                              onChanged: (v) => setS(() => _showTajweed = v),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, color: divC),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                            child: toggleRow(
                              icon: Icons.translate_rounded,
                              label: 'Traduction',
                              subtitle: 'Afficher la traduction française',
                              value: _showTranslation,
                              onChanged: (v) => setS(() => _showTranslation = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => _saveSettings());
  }

  // ── Reciter sheet ─────────────────────────────────────────────────────────

  void _showReciterSheet() {
    final svc = AudioService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF0090909),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            final selected = svc.currentAyahReciterNotifier.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Récitant',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: AudioService.ayahReciters.length,
                    itemBuilder: (_, i) {
                      final r = AudioService.ayahReciters[i];
                      final isSelected = r.qulId == selected.qulId;
                      return GestureDetector(
                        onTap: () {
                          svc.setAyahReciter(r);
                          Navigator.of(ctx).pop();
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.displayName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded,
                                    color: Color(0xFF4CAF50), size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Audio settings sheet ───────────────────────────────────────────────────

  void _showAudioSettingsSheet() {
    const rangeRepeatOptions  = <int>[1, 2, 3, 5, 10, 25, -1];
    const eachRepeatOptions   = <int>[1, 2, 3, 5, 10, 25];
    String rLabel(int v) => v == -1 ? '∞' : '×$v';

    // ── sous-feuille générique de sélection (style homogène) ──────────────
    void subPick<T>({
      required BuildContext ctx,
      required String title,
      required Map<String, T> options,
      required T current,
      required void Function(T) onPick,
    }) {
      showModalBottomSheet(
        context: ctx,
        backgroundColor: const Color(0xFF0D0D0D),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        showDragHandle: true,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                children: [
                  for (final e in options.entries)
                    GestureDetector(
                      onTap: () { onPick(e.value); Navigator.pop(ctx); },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: e.value == current
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(e.key,
                                style: TextStyle(
                                  color: e.value == current
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: e.value == current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                )),
                          ),
                          if (e.value == current)
                            const Icon(Icons.check_rounded,
                                color: Color(0xFF4CAF50), size: 18),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF2080808),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setS) {
          final maxAyah = _arabic.isEmpty ? 1 : _arabic.length;
          final start =
              (_loopStartAyah ?? _selectedAyah).clamp(1, maxAyah);
          final end =
              (_loopEndAyah ?? (_selectedAyah + 1).clamp(1, maxAyah))
                  .clamp(1, maxAyah);

          // ── étiquette de section ─────────────────────────────────────
          Widget sec(String t) => Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: Text(t,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
              );

          // ── ligne dans une "carte" sombre ────────────────────────────
          Widget card(Widget child, {BorderRadius? radius}) => Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius:
                      radius ?? BorderRadius.circular(12),
                ),
                child: child,
              );

          // ── valeur cliquable (→ sous-feuille) ────────────────────────
          Widget valueBtn(String label, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38, size: 15),
                ]),
              );

          // ── badge numérique (ayah start/end) ─────────────────────────
          Widget numBadge(int v, VoidCallback onTap) => GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$v',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white38, size: 13),
                  ]),
                ),
              );

          // ── pill repeat ──────────────────────────────────────────────
          Widget pill(String label, bool sel, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ),
              );

          // map ayahs pour subPick
          Map<String, int> ayahMap(int count) => {
                for (int i = 1; i <= count; i++) 'Ayah $i': i,
              };

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.60,
            maxChildSize: 0.92,
            minChildSize: 0.30,
            builder: (_, sc) => SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── titre ──────────────────────────────────────────
                  const Text('Paramètres audio',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),

                  // ═══ CONTENU ═══════════════════════════════════════
                  sec('CONTENU'),
                  card(Row(children: [
                    const Expanded(
                        child: Text('Traduction',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 13))),
                    valueBtn(
                      _translationOptions.entries
                          .firstWhere((e) => e.value == _translationKey,
                              orElse: () =>
                                  _translationOptions.entries.first)
                          .key,
                      () => subPick<String>(
                        ctx: ctx,
                        title: 'TRADUCTION',
                        options: _translationOptions,
                        current: _translationKey,
                        onPick: (v) async {
                          setS(() => _translationKey = v);
                          setState(() => _translationKey = v);
                          await _load();
                        },
                      ),
                    ),
                  ])),
                  card(Row(children: [
                    const Expanded(
                        child: Text('Tafsir',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 13))),
                    valueBtn(
                      _tafsirOptions.entries
                          .firstWhere((e) => e.value == _tafsirKey,
                              orElse: () =>
                                  _tafsirOptions.entries.first)
                          .key,
                      () => subPick<String>(
                        ctx: ctx,
                        title: 'TAFSIR',
                        options: _tafsirOptions,
                        current: _tafsirKey,
                        onPick: (v) async {
                          setS(() => _tafsirKey = v);
                          setState(() => _tafsirKey = v);
                          await _load();
                        },
                      ),
                    ),
                  ])),

                  // ═══ LECTURE ═══════════════════════════════════════
                  sec('LECTURE'),

                  // Boucle
                  card(Row(children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Boucle',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 2),
                          Text('Répéter une plage d\'ayahs',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _loopRangeEnabled,
                      onChanged: (v) {
                        setS(() => _loopRangeEnabled = v);
                        setState(() => _loopRangeEnabled = v);
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor:
                          Colors.white.withValues(alpha: 0.28),
                      inactiveThumbColor: Colors.white30,
                      inactiveTrackColor: Colors.white10,
                    ),
                  ])),

                  // Start / End (visible seulement si boucle activée)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _loopRangeEnabled
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: card(
                              Row(children: [
                                const Text('De',
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13)),
                                const SizedBox(width: 10),
                                numBadge(start, () {
                                  subPick<int>(
                                    ctx: ctx,
                                    title: 'AYAH DE DÉBUT',
                                    options: ayahMap(maxAyah),
                                    current: start,
                                    onPick: (v) {
                                      setS(() => _loopStartAyah = v);
                                      setState(
                                          () => _loopStartAyah = v);
                                    },
                                  );
                                }),
                                const SizedBox(width: 16),
                                const Text('à',
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13)),
                                const SizedBox(width: 10),
                                numBadge(end, () {
                                  subPick<int>(
                                    ctx: ctx,
                                    title: 'AYAH DE FIN',
                                    options: ayahMap(maxAyah),
                                    current: end,
                                    onPick: (v) {
                                      setS(() => _loopEndAyah = v);
                                      setState(
                                          () => _loopEndAyah = v);
                                    },
                                  );
                                }),
                              ]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ═══ RÉPÉTITIONS ═══════════════════════════════════
                  sec('RÉPÉTER LA PLAGE'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in rangeRepeatOptions)
                        pill(rLabel(v), _rangeRepeatTimes == v, () {
                          setS(() => _rangeRepeatTimes = v);
                          setState(() => _rangeRepeatTimes = v);
                        }),
                    ],
                  ),

                  sec('RÉPÉTER CHAQUE AYAH'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in eachRepeatOptions)
                        pill(rLabel(v), _eachAyahRepeatTimes == v, () {
                          setS(() => _eachAyahRepeatTimes = v);
                          setState(() => _eachAyahRepeatTimes = v);
                        }),
                    ],
                  ),

                  // ═══ TÉLÉCHARGEMENT ════════════════════════════════
                  sec('TÉLÉCHARGEMENT'),
                  GestureDetector(
                    onTap: (_surahDownloaded || _checkingSurahDownloaded)
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            _downloadCurrentSurahAudioFromBar();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _surahDownloaded
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _surahDownloaded
                              ? Colors.white10
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _surahDownloaded
                              ? Icons.check_circle_rounded
                              : Icons.download_rounded,
                          color: _surahDownloaded
                              ? const Color(0xFF4CAF50)
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _surahDownloaded
                              ? 'Sourate téléchargée'
                              : 'Télécharger la sourate',
                          style: TextStyle(
                              color: _surahDownloaded
                                  ? Colors.white30
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _toggleFavorite(int ayah) async {
    final key = _verseKey(ayah);
    final isNowFavorite = await VerseFavoritesService.instance.toggleFavorite(key);
    if (!mounted) return;
    setState(() {
      if (isNowFavorite) {
        _favoriteKeys.add(key);
      } else {
        _favoriteKeys.remove(key);
      }
    });
  }

  void _showVerseActions({
    required int ayah,
    required String ar,
    required String tr,
    String taf = '',
  }) {
    final key = _verseKey(ayah);
    final isFav = _favoriteKeys.contains(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _text(isDark);
    final subtle = _muted(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      showDragHandle: true,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // ── En-tête : numéro + sourate ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        '${widget.surahNameFr}  ·  verset $ayah',
                        style: TextStyle(color: subtle, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // ── Actions principales ─────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Écouter ce verset'),
                  onTap: () {
                    Navigator.pop(context);
                    _setSelectedAyah(ayah, center: true);
                    AudioService.instance.ayahPlayModeNotifier.value = AyahPlayMode.single;
                    setState(() => _repeatTimes = 1);
                    AudioService.instance.playAyah(widget.surahNumber, ayah);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: const Text('Écouter en continu'),
                  onTap: () {
                    Navigator.pop(context);
                    _setSelectedAyah(ayah, center: true);
                    setState(() => _repeatTimes = 1);
                    AudioService.instance.ayahPlayModeNotifier.value = AyahPlayMode.continuous;
                    AudioService.instance.playAyahRange(
                      surah: widget.surahNumber,
                      startAyah: ayah,
                      endAyah: _arabic.length,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.redAccent : null),
                  title: Text(isFav ? 'Retirer des favoris' : 'Ajouter aux favoris'),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleFavorite(ayah);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('Copier arabe + traduction'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: '$ar\n\n$tr'));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Partager'),
                  onTap: () {
                    Navigator.pop(context);
                    Share.share('$ar\n\n$tr');
                  },
                ),
                // ── Tafsir (expandable) ─────────────────────────────────
                if (taf.trim().isNotEmpty)
                  ExpansionTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: const Text('Tafsir'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [
                      Text(
                        taf.trim(),
                        style: TextStyle(
                          fontSize: _fontTafsir,
                          height: 1.55,
                          fontFamily: 'serif',
                          color: fg.withValues(alpha: isDark ? 0.78 : 0.74),
                        ),
                      ),
                    ],
                  ),
              ],
                ), // Column
              ), // Padding
            ), // SingleChildScrollView
          ), // ConstrainedBox
        ); // SafeArea
      },
    );
  }

  String _stripTrailingAyahNumber(String input) {
    return input
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u200B', '')
        .replaceAll('\u200F', '')
        .replaceAll('\u200E', '')
        .replaceAll(RegExp(r'[\s\u0660-\u0669\u06F0-\u06F9]+$'), '');
  }

  List<InlineSpan> _parseTajweedSpans(String input, Color fallback) {
    if (!_showTajweed) {
      final plain = input.replaceAll(RegExp(r'<[^>]+>'), '');
      return [TextSpan(text: plain, style: TextStyle(color: fallback))];
    }
    final spans = <InlineSpan>[];
    final regex = RegExp(
      "<rulee?\\s+class=['\\\"]?([^\\s>]+)['\\\"]?>(.*?)</rulee?>",
      dotAll: true,
    );

    int last = 0;
    for (final m in regex.allMatches(input)) {
      if (m.start > last) {
        spans.add(TextSpan(text: input.substring(last, m.start), style: TextStyle(color: fallback)));
      }
      final cls = m.group(1) ?? '';
      final txt = m.group(2) ?? '';
      spans.add(TextSpan(text: txt, style: TextStyle(color: _tajweedColors[cls] ?? fallback)));
      last = m.end;
    }
    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last), style: TextStyle(color: fallback)));
    }
    return spans;
  }

  String _toArabicIndic(int value) {
    const map = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };
    return value.toString().split('').map((d) => map[d] ?? d).join();
  }

  static const Map<String, Color> _tajweedColors = {
    'ham_wasl': Color(0xFF7E9CBF),
    'laam_shamsiyah': Color(0xFFD18B47),
    'madda_normal': Color(0xFF2E7D32),
    'madda_permissible': Color(0xFF7B1FA2),
    'madda_necessary': Color(0xFF6A1B9A),
    'madda_obligatory_monfasel': Color(0xFF5E35B1),
    'madda_obligatory_mottasel': Color(0xFF512DA8),
    'ghunnah': Color(0xFFE53935),
    'idgham_ghunnah': Color(0xFFEF6C00),
    'idgham_wo_ghunnah': Color(0xFF8E24AA),
    'ikhafa': Color(0xFF00796B),
    'ikhafa_shafawi': Color(0xFF00695C),
    'idgham_shafawi': Color(0xFF5D4037),
    'iqlab': Color(0xFFAD1457),
    'qalaqah': Color(0xFF1565C0),
    'slnt': Color(0xFF546E7A),
  };

  Widget _ayahBottomBar({
    required bool isDark,
    required AyahPlayMode mode,
    required bool isPlaying,
    required String? currentKey,
  }) {
    if (_arabic.isEmpty) return const SizedBox.shrink();

    final selectedKey = _verseKey(_selectedAyah);
    final playingThis = isPlaying && currentKey == selectedKey;
    final svc = AudioService.instance;
    final reciterName = svc.currentAyahReciterNotifier.value.displayName;
    final active = currentKey != null;
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    // ── chip style Hafs ───────────────────────────────────────────────────
    Widget chip({required Widget child, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      );
    }

    // ── icône de contrôle style Hafs ──────────────────────────────────────
    Widget ctrl(IconData icon, VoidCallback? onTap,
        {Color? color, double size = 28}) {
      return GestureDetector(
        onTap: onTap,
        child: Icon(
          icon,
          color: onTap != null ? (color ?? Colors.white) : Colors.white38,
          size: size,
        ),
      );
    }

    // ── row téléchargement ────────────────────────────────────────────────
    Widget downloadRow() {
      final pct =
          (_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);
      return Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  color: Colors.white70,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Téléchargement… $pct%',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _cancelSurahDownload,
            child: const Icon(Icons.close_rounded,
                color: Colors.white60, size: 20),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE2080808),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 24,
                spreadRadius: 2,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_downloadingSurah)
                  downloadRow()
                else ...[
                  // ── Row 1 : récitant · play · paramètres ─────────────
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        // Récitant (tap → feuille)
                        Expanded(
                          child: GestureDetector(
                            onTap: _showReciterSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _cleanReciterName(reciterName),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Play / Pause
                        GestureDetector(
                          onTap: _togglePlayPauseFromBar,
                          child: Icon(
                            playingThis
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Paramètres audio (chip ⚙)
                        chip(
                          onTap: _showAudioSettingsSheet,
                          child: const Icon(Icons.settings_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ),

                  // ── Row 2 : contrôles (seulement quand actif) ────────
                  if (active) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ctrl(Icons.skip_previous_rounded,
                            _selectedAyah <= 1 ? null : _playPrevFromBar),
                        ctrl(
                          playingThis
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          _togglePlayPauseFromBar,
                          size: 34,
                        ),
                        ctrl(Icons.stop_rounded, _stopFromBar,
                            color: Colors.redAccent.shade100),
                        ctrl(
                          Icons.skip_next_rounded,
                          _selectedAyah >= _arabic.length
                              ? null
                              : _playNextFromBar,
                        ),
                        chip(
                          onTap: _cycleRepeatFromBar,
                          child: Text(_repeatLabel()),
                        ),
                        PopupMenuButton<double>(
                          tooltip: 'Vitesse',
                          initialValue: _playbackSpeed,
                          onSelected: (v) {
                            setState(() => _playbackSpeed = v);
                            svc.setAyahSpeed(v);
                          },
                          itemBuilder: (_) => [
                            for (final v in speeds)
                              PopupMenuItem(
                                value: v,
                                child: Text(
                                    '${v.toStringAsFixed(v == 1.0 ? 0 : 2)}×'),
                              ),
                          ],
                          child: chip(
                            onTap: () {},
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed_rounded,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                    '${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.0 ? 0 : 2)}×'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;

    final merged = _audioListenable;

    final fg = _text(isDark);
    final subtle = _muted(isDark);
    final border = _border(isDark);

    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = topPad + 44;

    return Scaffold(
      body: Container(
        color: _bg(isDark),
        child: Stack(
          children: [
            if (!_loading && _arabic.isNotEmpty)
              AnimatedOpacity(
                opacity: _contentReady ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Stack(
                    children: [
                      NotificationListener<ScrollEndNotification>(
                        onNotification: (_) {
                          _snapBars(_barProgress.value > 0.35);
                          return false;
                        },
                        child: AnimatedBuilder(
                        animation: merged,
                        builder: (_, __) {
                          final currentKey = AudioService.instance.currentAyahKeyNotifier.value;
                          final mode = AudioService.instance.ayahPlayModeNotifier.value;
                          final isPlaying = AudioService.instance.isAyahPlayingNotifier.value;

                          return ListView.builder(
                            controller: _scrollController,
                            cacheExtent: 50000,
                            padding: EdgeInsets.fromLTRB(16, appBarH + 12, 16, MediaQuery.of(context).padding.bottom + 140),
                        itemCount: _arabic.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                              child: Column(
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final svgW = constraints.maxWidth;
                                      final svgH = svgW * 67 / 624;
                                      return SizedBox(
                                        width: svgW,
                                        height: svgH,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: SvgPicture.asset(
                                                  'assets/images/Translated_Quran/cadre_name_surah.svg',
                                                  fit: BoxFit.fill,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 24),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  widget.surahNameAr,
                                                  textDirection: TextDirection.rtl,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: 'ScheherazadeNew',
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2C1A0E),
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (_shouldShowBasmalaForThisSurah()) ...[
                                    const SizedBox(height: 20),
                                    _BasmalaTitle(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : const Color(0xFF7A5C30).withValues(alpha: 0.80),
                                      fontSize: _fontArabic,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }

                          final idx = i - 1;
                          final ayaNum = idx + 1;
                          final ar = _arabic[idx];
                          final tr = _translation[idx];
                          final taf = _tafsir[idx];

                          final key = _verseKey(ayaNum);
                          final isFav = _favoriteKeys.contains(key);

                          final isPlayingThis = (currentKey == key) && isPlaying;
                          final highlight = isPlayingThis ? _accent(isDark).withValues(alpha: isDark ? 0.16 : 0.12) : Colors.transparent;

                          return InkWell(
                            key: _keyForAyah(ayaNum),
                            onTap: () {
                              _setSelectedAyah(ayaNum, center: false);
                              _showVerseActions(ayah: ayaNum, ar: ar, tr: tr, taf: taf);
                            },
                            child: Container(
                              color: highlight,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      // Numéro de verset — médaillon islamique
                                      _VerseBadge(
                                        number: ayaNum,
                                        color: isPlayingThis
                                            ? _accent(isDark)
                                            : (isDark ? const Color(0xFFD4A855) : const Color(0xFF9A7230)).withValues(alpha: 0.75),
                                      ),
                                      if (isPlayingThis) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          mode == AyahPlayMode.repeatOne
                                              ? 'RÉPÉTITION'
                                              : mode == AyahPlayMode.continuous
                                                  ? 'CONTINU'
                                                  : 'LECTURE',
                                          style: TextStyle(color: _accent(isDark), fontWeight: FontWeight.w700, fontSize: 10),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (isFav)
                                        Icon(Icons.favorite, size: 15, color: Colors.redAccent.withValues(alpha: 0.8)),
                                    ],
                                  ),
                                  if (_showArabic) ...[
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (_) {
                                        final style = TextStyle(
                                          fontSize: _fontArabic,
                                          height: 2.4,
                                          fontFamily: 'ScheherazadeNew',
                                          fontWeight: FontWeight.w600,
                                          wordSpacing: 4.5,
                                          color: fg,
                                        );

                                        var clean = _stripTrailingAyahNumber(ar);

                                        if (ayaNum == 1 && _shouldShowBasmalaForThisSurah()) {
                                          clean = _removeLeadingBasmalaIfPresent(clean);
                                        }

                                        final spans = _parseTajweedSpans(clean, fg);
                                        spans.add(
                                          TextSpan(
                                            text: ' ﴿${_toArabicIndic(ayaNum)}﴾',
                                            style: TextStyle(color: subtle, fontWeight: FontWeight.w700),
                                          ),
                                        );

                                        return RichText(
                                          textDirection: TextDirection.rtl,
                                          text: TextSpan(style: style, children: spans),
                                        );
                                      },
                                    ),
                                  ],
                                  if (_showTranslation) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      tr,
                                      textAlign: TextAlign.justify,
                                      style: TextStyle(
                                        fontSize: _fontTranslation,
                                        height: 1.65,
                                        fontFamily: 'serif',
                                        fontWeight: FontWeight.w500,
                                        color: fg.withValues(alpha: isDark ? 0.86 : 0.82),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Divider(height: 1, thickness: 1, color: border),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ),
                  // ── Lecteur flottant ──────────────────────────────────
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 14,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _barProgress,
                      builder: (_, progress, child) => Transform.translate(
                        offset: Offset(0, 200 * progress),
                        child: child,
                      ),
                      child: AnimatedBuilder(
                        animation: merged,
                        builder: (_, __) {
                          final currentKey = AudioService.instance.currentAyahKeyNotifier.value;
                          final mode     = AudioService.instance.ayahPlayModeNotifier.value;
                          final isPlaying = AudioService.instance.isAyahPlayingNotifier.value;
                          _playbackSpeed = AudioService.instance.ayahSpeedNotifier.value;
                          return _ayahBottomBar(
                            isDark: isDark,
                            mode: mode,
                            isPlaying: isPlaying,
                            currentKey: currentKey,
                          );
                        },
                      ),
                    ),
                  ),
                  // ── Barre de navigation custom ────────────────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _barProgress,
                      builder: (_, progress, child) => Transform.translate(
                        offset: Offset(0, -appBarH * progress),
                        child: child,
                      ),
                      child: Container(
                        color: _bg(isDark),
                        padding: EdgeInsets.fromLTRB(4, topPad, 4, 0),
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fg),
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                              Expanded(
                                child: Text(
                                  '${widget.surahNumber}. ${widget.surahNameFr}',
                                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.settings_outlined, size: 20, color: fg),
                                onPressed: _showSettingsSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ), // AnimatedOpacity
            if (_loading || !_contentReady)
              const Center(child: CircularProgressIndicator()),
            if (!_loading && _arabic.isEmpty)
              Center(child: Text(_error ?? 'Aucun verset', style: TextStyle(color: subtle))),
          ],
        ), // outer Stack
      ),
    );
  }
}

class TranslatedJuzScreen extends StatefulWidget {
  final int juzNumber;
  final bool preferOffline;

  const TranslatedJuzScreen({
    super.key,
    required this.juzNumber,
    required this.preferOffline,
  });

  @override
  State<TranslatedJuzScreen> createState() => _TranslatedJuzScreenState();
}

class _TranslatedJuzScreenState extends State<TranslatedJuzScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Juz ${widget.juzNumber}')),
      body: const Center(
        child: Text(
          'Étape suivante: Juz (traduction + tafsir) avec verse_mapping.\n'
          'On va intégrer le JSON "Juz info" (QUL) pour découper exactement.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}