// lib/ui/translated_quran_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../hizb_juzz.dart';
import '../services/quran_translation_pack_service.dart';
import '../services/verse_favorites_service.dart';
import '../services/audio_service.dart';
import '../services/quran_image_service.dart';
import '../services/reading_history_service.dart';
import '../services/qul_audio/qul_audio_resolver.dart';
import '../surah_name.dart';
import 'reader_screen.dart';
import 'screens/quran_loader.dart';

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
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _showPackDialog() async {
    final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool frReady = await QuranTranslationPackService.isPackReady(AppLang.fr);
    bool enReady = await QuranTranslationPackService.isPackReady(AppLang.en);

    CancelToken? cancelToken;
    bool downloading = false;
    double progress = 0.0;
    AppLang? downloadingLang;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !downloading,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> startDownload(AppLang lang) async {
              if (downloading) return;

              setStateDialog(() {
                downloading = true;
                downloadingLang = lang;
                progress = 0.0;
                cancelToken = CancelToken();
              });

              try {
                await QuranTranslationPackService.downloadPack(
                  lang,
                  cancelToken: cancelToken,
                  onProgress: (p) => setStateDialog(() => progress = p),
                );

                frReady = await QuranTranslationPackService.isPackReady(AppLang.fr);
                enReady = await QuranTranslationPackService.isPackReady(AppLang.en);

                setStateDialog(() {
                  downloading = false;
                  downloadingLang = null;
                  cancelToken = null;
                  progress = 1.0;
                });
              } catch (e) {
                final cancelled = cancelToken?.isCancelled == true;

                setStateDialog(() {
                  downloading = false;
                  downloadingLang = null;
                  cancelToken = null;
                });

                if (!cancelled && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(isEn ? 'Download failed: $e' : 'Téléchargement échoué : $e')),
                  );
                }
              }
            }

            void cancelDownload() => cancelToken?.cancel('cancelled');

            Widget packRow({
              required String title,
              required bool ready,
              required AppLang lang,
            }) {
              final status = ready ? (isEn ? 'Installed' : 'Installé') : (isEn ? 'Not installed' : 'Non installé');
              final canDownload = !ready && !downloading;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1734) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: canDownload ? () => startDownload(lang) : null,
                      child: Text(isEn ? 'Download' : 'Télécharger'),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
              title: Text(isEn ? 'Offline translation packs' : 'Packs de traduction offline'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    packRow(
                      title: isEn ? 'French translation (SQLite)' : 'Traduction Français (SQLite)',
                      ready: frReady,
                      lang: AppLang.fr,
                    ),
                    const SizedBox(height: 10),
                    packRow(
                      title: isEn ? 'English translation (SQLite)' : 'Traduction Anglais (SQLite)',
                      ready: enReady,
                      lang: AppLang.en,
                    ),
                    if (downloading) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(progress * 100).toStringAsFixed(0)}%  '
                              '${(downloadingLang == AppLang.fr) ? "FR" : "EN"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: cancelDownload,
                            child: Text(isEn ? 'Cancel' : 'Annuler'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: downloading ? null : () => Navigator.pop(ctx),
                  child: Text(isEn ? 'Close' : 'Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEn ? 'Translated Quran' : 'Coran Français',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90),
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
          foregroundColor: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: isEn ? 'Offline packs' : 'Packs offline',
              icon: const Icon(Icons.cloud_download_rounded),
              onPressed: _showPackDialog,
            ),
          ],
          bottom: TabBar(
            labelColor: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90),
            unselectedLabelColor: isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.50),
            tabs: const [
              Tab(text: 'Sourates'),
              Tab(text: 'Juz'),
              Tab(text: 'Favoris'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SurahTab(preferOffline: widget.preferOffline),
            _JuzTab(preferOffline: widget.preferOffline),
            const _FavoritesTab(),
          ],
        ),
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

  Color _bg(bool isDark) => isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
  Color _text(bool isDark) => isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90);
  Color _muted(bool isDark) => isDark ? Colors.white.withOpacity(0.62) : Colors.black.withOpacity(0.58);
  Color _border(bool isDark) => isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _text(isDark);
    final subtle = _muted(isDark);
    final border = _border(isDark);

    if (_loading) {
      return Container(color: _bg(isDark), child: const Center(child: CircularProgressIndicator()));
    }

    if (_keys.isEmpty) {
      return Container(
        color: _bg(isDark),
        child: Center(
          child: Text('Aucun favori', style: TextStyle(color: subtle, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Container(
      color: _bg(isDark),
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
              color: isDark ? const Color(0xFF0F1734) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: ListTile(
              title: Text('$nameTr', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
              subtitle: Text('Verset $a', style: TextStyle(color: subtle, fontWeight: FontWeight.w600)),
              trailing: Icon(Icons.chevron_right_rounded, color: subtle),
              onTap: () {
                Navigator.push(
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
                );
              },
            ),
          );
        },
      ),
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

// Les 27 sourates médinoises (toutes les autres sont mecquoises)
const _medinanSurahs = <int>{
  2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48,
  49, 55, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 76, 98, 110,
};

class _SurahTabState extends State<_SurahTab> {
  /// Liste aplatie : chaque item est soit {'type':'juz','juz':N} soit {'type':'surah',...}
  List<Map<String, dynamic>> _items = [];
  Set<int> _visitedSurahIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  static int _pageToJuz(int page) {
    for (int i = juzzMap.length - 1; i >= 0; i--) {
      if (juzzMap[i]['start_page']! <= page) return juzzMap[i]['juz']!;
    }
    return 1;
  }

  Future<void> _loadSurahs() async {
    final raw = await rootBundle.loadString('assets/data/quran_data.json');
    final decoded = jsonDecode(raw);

    final List<dynamic> quranData;
    if (decoded is List) {
      quranData = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        quranData = decoded['data'] as List;
      } else if (decoded['quran'] is List) {
        quranData = decoded['quran'] as List;
      } else if (decoded['verses'] is List) {
        quranData = decoded['verses'] as List;
      } else {
        quranData = decoded.values.toList();
      }
    } else {
      quranData = const [];
    }

    final Map<int, int> ayahCounts = {};
    final Map<int, int> startPage = {};
    final Map<int, String> arName = {};

    for (final v in quranData) {
      if (v is! Map) continue;

      final surahRaw = v['surah'];
      final pageRaw = v['page'];

      final int? id = (surahRaw is int) ? surahRaw : int.tryParse('$surahRaw');
      if (id == null) continue;

      final int page = (pageRaw is int) ? pageRaw : (int.tryParse('$pageRaw') ?? 1);

      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
      startPage[id] ??= page;

      final name = v['sura_name'];
      if (name != null && arName[id] == null) {
        arName[id] = name.toString();
      }
    }

    final ids = ayahCounts.keys.toList()..sort();

    final List<Map<String, dynamic>> flat = [];
    int lastJuz = 0;

    for (final id in ids) {
      final page = startPage[id] ?? 1;
      final juz = _pageToJuz(page);
      if (juz != lastJuz) {
        flat.add({'type': 'juz', 'juz': juz});
        lastJuz = juz;
      }
      flat.add({
        'type': 'surah',
        'id': id,
        'nameAr': arName[id] ?? 'سورة $id',
        'page': page,
        'ayahCount': ayahCounts[id] ?? 0,
        'juz': juz,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');

    final bg = isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
    final titleColor = isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90);
    final subColor = isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.60);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);
    final juzHeaderBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final juzHeaderColor = isDark ? Colors.white.withOpacity(0.50) : Colors.black.withOpacity(0.45);
    final accentColor = isDark ? const Color(0xFF7986CB) : const Color(0xFF3949AB);
    final badgeFill = isDark ? const Color(0xFF2A3A6A) : const Color(0xFFE8EAF6);
    final badgeText = isDark ? Colors.white.withOpacity(0.90) : const Color(0xFF3949AB);

    const totalSurahs = 114;
    final visitedCount = _visitedSurahIds.length;
    final progress = visitedCount / totalSurahs;

    return Container(
      color: bg,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        // +1 pour la barre de progression en en-tête
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          // ─── En-tête : barre de progression ───
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isEn ? 'Progress' : 'Progression',
                        style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      Text(
                        '$visitedCount / $totalSurahs ${isEn ? 'surahs' : 'sourates'}',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ],
              ),
            );
          }

          final item = _items[index - 1]; // décalage de 1 à cause de l'en-tête

          if (item['type'] == 'juz') {
            final juzNum = item['juz'] as int;
            final juzPage = juzzMap.firstWhere((j) => j['juz'] == juzNum)['start_page']!;
            return InkWell(
              onTap: () async {
                try {
                  final file = await QuranImageService.getPageFile('hafs', juzPage);
                  if (!context.mounted) return;
                  await precacheImage(FileImage(file), context);
                } catch (_) {}
                if (!context.mounted) return;
                try {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(initialPage: juzPage, reading: 'hafs'),
                    ),
                  );
                } catch (_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuranLoader()),
                  );
                }
              },
              child: Container(
                color: juzHeaderBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    Text(
                      'Juz $juzNum',
                      style: TextStyle(
                        color: juzHeaderColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '—  p. $juzPage',
                      style: TextStyle(
                        color: juzHeaderColor.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 14, color: juzHeaderColor.withOpacity(0.5)),
                  ],
                ),
              ),
            );
          }

          // Surah item
          final surahId = item['id'] as int;
          final nameAr = (item['nameAr'] ?? '').toString();
          final nameTr = isEn ? (surahEn[surahId] ?? 'Surah $surahId') : (surahFr[surahId] ?? 'Sourate $surahId');
          final ayahCount = item['ayahCount'] as int;
          final page = item['page'] as int;
          final isMadinan = _medinanSurahs.contains(surahId);
          final revLabel = isEn
              ? (isMadinan ? 'Medinan' : 'Meccan')
              : (isMadinan ? 'Médinoise' : 'Mecquoise');
          final meaning = surahMeaning[surahId];
          final isVisited = _visitedSurahIds.contains(surahId);

          // Séparateur fin sauf juste après un header de Juz (décalage +1 d'index)
          final prevItem = index > 1 ? _items[index - 2] : null;
          final prevIsJuz = index == 1 || (prevItem != null && prevItem['type'] == 'juz');
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!prevIsJuz)
                Divider(height: 1, thickness: 0.5, indent: 68, endIndent: 16, color: dividerColor),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: _OctagonBadge(
                  number: surahId,
                  fillColor: isVisited ? accentColor.withOpacity(0.15) : badgeFill,
                  textColor: isVisited ? accentColor : badgeText,
                  borderColor: isVisited ? accentColor.withOpacity(0.50) : Colors.transparent,
                ),
                title: Text(
                  nameTr,
                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (meaning != null)
                        Text(
                          '"$meaning"',
                          style: TextStyle(
                            color: subColor.withOpacity(0.75),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 1),
                      Text(
                        '$ayahCount ${isEn ? 'verses' : 'versets'}  ·  $revLabel  ·  p. $page',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nameAr,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: titleColor.withOpacity(0.85),
                        fontSize: 15,
                        fontFamily: 'UthmanTahaNaskh',
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranslatedSurahScreen(
                        surahNumber: surahId,
                        surahNameFr: nameTr,
                        surahNameAr: nameAr,
                        preferOffline: widget.preferOffline,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Badge octogonal pour le numéro de sourate ────────────────────────────
class _OctagonBadge extends StatelessWidget {
  final int number;
  final Color fillColor;
  final Color textColor;
  final Color borderColor;

  const _OctagonBadge({
    required this.number,
    required this.fillColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: CustomPaint(
        painter: _OctagonPainter(fill: fillColor, border: borderColor),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: textColor,
              fontSize: number > 99 ? 9.5 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  final Color fill;
  final Color border;
  const _OctagonPainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = w * 0.26;
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    if (border != Colors.transparent) {
      canvas.drawPath(
        path,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OctagonPainter old) =>
      old.fill != fill || old.border != border;
}

class _JuzTab extends StatelessWidget {
  final bool preferOffline;
  const _JuzTab({required this.preferOffline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
    final titleColor = isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90);
    final subColor = isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.60);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

    return Container(
      color: bg,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: juzzMap.length,
        separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: dividerColor),
        itemBuilder: (context, i) {
          final juz = juzzMap[i]['juz']!;
          final startPage = juzzMap[i]['start_page']!;
          final endPage = i + 1 < juzzMap.length ? juzzMap[i + 1]['start_page']! - 1 : 604;
          final pageCount = endPage - startPage + 1;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Text(
                '$juz',
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            title: Text(
              'Juz $juz',
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Pages $startPage – $endPage  •  $pageCount pages',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TranslatedJuzScreen(
                    juzNumber: juz,
                    preferOffline: preferOffline,
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

class _TranslatedSurahScreenState extends State<TranslatedSurahScreen> {
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
  String? _error;

  List<String> _arabic = [];
  List<String> _translation = [];
  List<String> _tafsir = [];

  bool _showArabic = true;
  bool _showTranslation = true;
  double _fontArabic = 20;
  double _fontTranslation = 16;
  double _fontTafsir = 14;

  Set<String> _favoriteKeys = <String>{};
  String? _openTafsirKey;

  // --- Auto-center precise (no more "approxItem") ---
  final Map<int, GlobalKey> _ayahItemKeys = <int, GlobalKey>{};

  GlobalKey _keyForAyah(int ayah) {
    return _ayahItemKeys.putIfAbsent(ayah, () => GlobalKey());
  }

  void _ensureAyahCentered(int ayah) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final key = _ayahItemKeys[ayah];
      final ctx = key?.currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5, // center
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }
  final ScrollController _scrollController = ScrollController();
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
    _playbackSpeed = AudioService.instance.ayahSpeedNotifier.value;
    AudioService.instance.ayahPlayModeNotifier.value = AyahPlayMode.continuous;
    _repeatTimes = 1;

    Future.microtask(() async {
      await _loadFavorites();
      await _load();
      _attachAyahListener();
    });
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
    super.dispose();
  }

  Color _bg(bool isDark) => isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
  Color _text(bool isDark) => isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90);
  Color _muted(bool isDark) => isDark ? Colors.white.withOpacity(0.62) : Colors.black.withOpacity(0.58);
  Color _border(bool isDark) => isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
  Color _accent(bool isDark) => isDark ? const Color(0xFFE3C880) : const Color(0xFFB37A2A);

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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final accent = _accent(isDark);
              final fg = _text(isDark);
              final subtle = _muted(isDark);
              final border = _border(isDark);

              InputDecoration deco(String label) => InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(color: subtle, fontWeight: FontWeight.w700),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.7))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  );

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Arabe', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                            value: _showArabic,
                            onChanged: (v) {
                              setStateSheet(() => _showArabic = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Traduction', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                            value: _showTranslation,
                            onChanged: (v) {
                              setStateSheet(() => _showTranslation = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _translationKey,
                      dropdownColor: isDark ? const Color(0xFF0F1734) : Colors.white,
                      decoration: deco('Traduction (API)'),
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                      items: _translationOptions.entries
                          .map((e) => DropdownMenuItem<String>(value: e.value, child: Text(e.key, style: TextStyle(color: fg))))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setStateSheet(() => _translationKey = v);
                        setState(() => _translationKey = v);
                        await _load();
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _tafsirKey,
                      dropdownColor: isDark ? const Color(0xFF0F1734) : Colors.white,
                      decoration: deco('Tafsir (API)'),
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                      items: _tafsirOptions.entries
                          .map((e) => DropdownMenuItem<String>(value: e.value, child: Text(e.key, style: TextStyle(color: fg))))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setStateSheet(() => _tafsirKey = v);
                        setState(() => _tafsirKey = v);
                        await _load();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Taille arabe'),
                        Expanded(
                          child: Slider(
                            min: 10,
                            max: 56,
                            value: _fontArabic,
                            activeColor: accent,
                            inactiveColor: accent.withOpacity(0.2),
                            onChanged: (v) {
                              setStateSheet(() => _fontArabic = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Taille traduction'),
                        Expanded(
                          child: Slider(
                            min: 12,
                            max: 22,
                            value: _fontTranslation,
                            activeColor: accent,
                            inactiveColor: accent.withOpacity(0.2),
                            onChanged: (v) {
                              setStateSheet(() => _fontTranslation = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Taille tafsir'),
                        Expanded(
                          child: Slider(
                            min: 12,
                            max: 20,
                            value: _fontTafsir,
                            activeColor: accent,
                            inactiveColor: accent.withOpacity(0.2),
                            onChanged: (v) {
                              setStateSheet(() => _fontTafsir = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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

  void _toggleTafsir(int ayah) {
    final key = _verseKey(ayah);
    setState(() => _openTafsirKey = (_openTafsirKey == key) ? null : key);
  }

  void _showVerseActions({
    required int ayah,
    required String ar,
    required String tr,
  }) {
    final key = _verseKey(ayah);
    final isFav = _favoriteKeys.contains(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Lire ce verset'),
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
                title: const Text('Lire en continu (de ce verset à la fin)'),
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
              ListTile(
                leading: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                title: Text(isFav ? 'Retirer des favoris' : 'Ajouter aux favoris'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(ayah);
                },
              ),
            ],
          ),
        );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final merged = Listenable.merge([
      AudioService.instance.currentAyahKeyNotifier,
      AudioService.instance.ayahPlayModeNotifier,
      AudioService.instance.isAyahPlayingNotifier,
      AudioService.instance.currentAyahReciterNotifier,
      AudioService.instance.ayahSpeedNotifier,
    ]);

    final fg = _text(isDark);
    final subtle = _muted(isDark);
    final border = _border(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.surahNumber}. ${widget.surahNameFr}', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
        backgroundColor: _bg(isDark),
        foregroundColor: fg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Affichage',
            onPressed: _showSettingsSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Container(
        color: _bg(isDark),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_arabic.isEmpty)
                ? Center(child: Text(_error ?? 'Aucun verset', style: TextStyle(color: subtle)))
                : Stack(
                    children: [
                      AnimatedBuilder(
                        animation: merged,
                        builder: (_, __) {
                          final currentKey = AudioService.instance.currentAyahKeyNotifier.value;
                          final mode = AudioService.instance.ayahPlayModeNotifier.value;
                          final isPlaying = AudioService.instance.isAyahPlayingNotifier.value;

                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 140),
                        itemCount: _arabic.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.surahNameAr,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontFamily: 'ScheherazadeNew',
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(widget.surahNameFr, style: TextStyle(color: subtle, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 10),
                                  Divider(height: 1, thickness: 1, color: border),
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
                              _toggleTafsir(ayaNum);
                            },
                            onLongPress: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                            child: Container(
                              color: highlight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Text('$ayaNum', style: TextStyle(color: subtle, fontWeight: FontWeight.w900)),
                                      if (isPlayingThis) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          mode == AyahPlayMode.repeatOne
                                              ? 'RÉPÉTITION'
                                              : mode == AyahPlayMode.continuous
                                                  ? 'CONTINU'
                                                  : 'LECTURE',
                                          style: TextStyle(color: subtle, fontWeight: FontWeight.w900, fontSize: 11),
                                        ),
                                      ],
                                      const Spacer(),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        iconSize: 18,
                                        onPressed: () => _toggleFavorite(ayaNum),
                                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : subtle),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        iconSize: 18,
                                        onPressed: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                                        icon: Icon(Icons.more_horiz_rounded, color: subtle),
                                      ),
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

                                        final showBasmala = (ayaNum == 1 && _shouldShowBasmalaForThisSurah());

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (showBasmala) ...[
                                              const SizedBox(height: 6),
                                              Center(
                                                child: Text(
                                                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                                  textDirection: TextDirection.rtl,
                                                  style: TextStyle(
                                                    fontSize: _fontArabic,
                                                    height: 2.2,
                                                    fontFamily: 'ScheherazadeNew',
                                                    fontWeight: FontWeight.w600,
                                                    color: fg,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            RichText(
                                              textDirection: TextDirection.rtl,
                                              text: TextSpan(style: style, children: spans),
                                            ),
                                          ],
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        _openTafsirKey == key ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                        size: 18,
                                        color: subtle,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Tafsir', style: TextStyle(color: subtle, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ],
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    child: (_openTafsirKey == key)
                                        ? Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: Text(
                                              taf.trim().isEmpty ? 'Tafsir indisponible.' : taf,
                                              style: TextStyle(
                                                fontSize: _fontTafsir,
                                                height: 1.45,
                                                fontFamily: 'serif',
                                                fontWeight: FontWeight.w500,
                                                color: fg.withValues(alpha: isDark ? 0.78 : 0.74),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
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
                  // ── Lecteur flottant ──────────────────────────────────
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 14,
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
                ],
              ),
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