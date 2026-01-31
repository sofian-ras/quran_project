import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../hizb_juzz.dart';
import '../services/quran_translation_pack_service.dart';
import '../services/verse_favorites_service.dart';
import '../surah_name.dart';

class TranslatedQuranScreen extends StatefulWidget {
  final bool preferOffline; // si true: on essaie le pack, sinon online

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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
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
                  onProgress: (p) {
                    setStateDialog(() => progress = p);
                  },
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

            void cancelDownload() {
              cancelToken?.cancel('cancelled');
            }

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
                  color: isDark ? const Color(0xFF0B1025).withOpacity(0.55) : Colors.white.withOpacity(0.85),
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
                              color: isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B),
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
              backgroundColor: isDark ? const Color(0xFF0F1734) : const Color(0xFFFFF7EA),
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEn ? 'Translated Quran' : 'Coran Français',
            style: TextStyle(
              color: isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B),
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF0D132F) : const Color(0xFFF7EEDB),
          foregroundColor: isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B),
          actions: [
            IconButton(
              tooltip: isEn ? 'Offline packs' : 'Packs offline',
              icon: const Icon(Icons.cloud_download_rounded),
              onPressed: _showPackDialog,
            ),
          ],
          bottom: TabBar(
            labelColor: isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B),
            unselectedLabelColor: isDark
                ? const Color(0xFFF6E7C5).withOpacity(0.6)
                : const Color(0xFF3B2A0B).withOpacity(0.6),
            tabs: const [
              Tab(text: 'Sourates'),
              Tab(text: 'Juz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SurahTab(preferOffline: widget.preferOffline),
            _JuzTab(preferOffline: widget.preferOffline),
          ],
        ),
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

String _stripHtml(String input) {
  return input.replaceAll(RegExp(r'<[^>]+>'), '');
}

class _SurahTab extends StatefulWidget {
  final bool preferOffline;
  const _SurahTab({required this.preferOffline});

  @override
  State<_SurahTab> createState() => _SurahTabState();
}

class _SurahTabState extends State<_SurahTab> {
  List<Map<String, dynamic>> _surahs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
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
        // dernier recours: si le JSON est un objet dont les valeurs sont les versets
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

    _surahs = [
      for (final id in ids)
        {
          'id': id,
          'nameAr': arName[id] ?? 'سورة $id',
          'page': startPage[id] ?? 1,
          'ayahCount': ayahCounts[id] ?? 0,
        }
    ];

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D132F) : const Color(0xFFFFF7EA);
    final tileBg = isDark ? const Color(0xFF141B3A) : Colors.white;

    return Container(
      color: bg,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _surahs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = _surahs[index];
          final surahId = (s['id'] is int) ? s['id'] as int : int.tryParse('${s['id']}') ?? 0;
          final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');

          final nameAr = (s['nameAr'] ?? '').toString();

          final nameTr = isEn ? (surahEn[surahId] ?? 'Surah $surahId') : (surahFr[surahId] ?? 'Sourate $surahId');

          final titleColor = isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B);
          final subColor = isDark ? const Color(0xFFD7C39B) : const Color(0xFF5B4630);

          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: tileBg,
            title: Text(
              '$surahId. $nameTr',
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              nameAr,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: subColor),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
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
          );
        },
      ),
    );
  }
}

class _JuzTab extends StatelessWidget {
  final bool preferOffline;
  const _JuzTab({required this.preferOffline});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: juzzMap.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final juz = juzzMap[i]['juz']!;
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: Theme.of(context).cardColor,
          title: Text('Juz $juz'),
          trailing: const Icon(Icons.chevron_right_rounded),
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
    );
  }
}

class TranslatedSurahScreen extends StatefulWidget {
  final int surahNumber;
  final String surahNameFr;
  final String surahNameAr;
  final bool preferOffline;

  const TranslatedSurahScreen({
    super.key,
    required this.surahNumber,
    required this.surahNameFr,
    required this.surahNameAr,
    required this.preferOffline,
  });

  @override
  State<TranslatedSurahScreen> createState() => _TranslatedSurahScreenState();
}

class _TranslatedSurahScreenState extends State<TranslatedSurahScreen> {
  bool _loading = true;
  String? _error;

  List<String> _arabic = [];
  List<String> _translation = [];
  List<String> _tafsir = [];
  bool _loadedOnce = false;
  bool _showArabic = true;
  bool _showTranslation = true;
  double _fontArabic = 36;
  double _fontTranslation = 16;
  double _fontTafsir = 14;
  Set<String> _favoriteKeys = <String>{};
  String? _openTafsirKey;

  final Dio _dio = Dio();

  static const _quranEncBase = 'https://quranenc.com/api/v1';
  static const _translationKey = 'french_hameedullah';
  static const _tafsirKey = 'french_mokhtasar';

  static const _alquranBase = 'https://api.alquran.cloud/v1';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFavorites();
        _load();
      }
    });
  }

  Future<void> _loadFavorites() async {
    final favs = await VerseFavoritesService.instance.getFavorites();
    if (!mounted) return;
    setState(() => _favoriteKeys = favs);
  }

  Future<void> _load() async {
    _loading = true;
    _error = null;
    if (mounted) setState(() {});

    try {
      final lang = AppLang.fr;

      final packReady = await QuranTranslationPackService.isPackReady(lang);
      final useOffline = widget.preferOffline && packReady;

      if (useOffline) {
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
      } else {
        final arRes = await _dio.get('$_alquranBase/surah/${widget.surahNumber}/quran-uthmani');
        final arAyahs = (arRes.data['data']['ayahs'] as List);
        _arabic = arAyahs.map((e) => (e['text'] ?? '').toString()).toList();

        final trRes = await _dio.get('$_quranEncBase/translation/sura/$_translationKey/${widget.surahNumber}');
        final trAyahs = _extractQuranEncList(trRes.data);
        _translation = trAyahs
            .map((e) => _stripHtml((e['translation'] ?? '').toString()))
            .toList();

        final tafRes = await _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}');
        final tafAyahs = _extractQuranEncList(tafRes.data);
        _tafsir = tafAyahs
            .map((e) => _stripHtml((e['translation'] ?? '').toString()))
            .toList();
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _verseKey(int ayah) => '${widget.surahNumber}:$ayah';

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F1734) : const Color(0xFFFFF7EA),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final accent = isDark ? const Color(0xFFE3C880) : const Color(0xFFB37A2A);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            accent.withOpacity(0.0),
                            accent.withOpacity(0.8),
                            accent.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Arabe'),
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
                            title: const Text('Traduction'),
                            value: _showTranslation,
                            onChanged: (v) {
                              setStateSheet(() => _showTranslation = v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Taille arabe'),
                        Expanded(
                          child: Slider(
                            min: 28,
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

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié')));
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
    final accent = isDark ? const Color(0xFFE3C880) : const Color(0xFFB37A2A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F1734) : const Color(0xFFFFF7EA),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 3,
                width: 60,
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.0),
                      accent.withOpacity(0.8),
                      accent.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_rounded),
                title: const Text('Copier arabe + traduction'),
                onTap: () {
                  Navigator.pop(context);
                  _copyText('$ar\n\n$tr');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copier arabe'),
                onTap: () {
                  Navigator.pop(context);
                  _copyText(ar);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copier traduction'),
                onTap: () {
                  Navigator.pop(context);
                  _copyText(tr);
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
    return input.replaceAll(RegExp(r'[\s\u0660-\u0669\u06F0-\u06F9]+$'), '');
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

  @override
  Widget build(BuildContext context) {
    final title = '${widget.surahNumber}. ${widget.surahNameFr}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicColor = isDark ? const Color(0xFFF6E7C5) : const Color(0xFF4B2E0E);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: arabicColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0D132F) : const Color(0xFFF7EEDB),
        foregroundColor: isDark ? const Color(0xFFF6E7C5) : const Color(0xFF3B2A0B),
        actions: [
          IconButton(
            onPressed: _showSettingsSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B1025),
                    Color(0xFF131A3A),
                    Color(0xFF1C1635),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFBF5),
                    Color(0xFFF6F0E4),
                    Color(0xFFEDE2D1),
                  ],
                ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? Center(child: Text(_error!))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _arabic.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark ? const Color(0xFF0B1025).withOpacity(0.55) : Colors.white.withOpacity(0.85),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.20 : 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.surahNameAr,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'ScheherazadeNew',
                                  color: arabicColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.surahNameFr,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: arabicColor.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_arabic.length} versets',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final idx = i - 1;
                      final ayaNum = idx + 1;

                      final ar = _arabic.length > idx ? _arabic[idx] : '';
                      final tr = _translation.length > idx ? _translation[idx] : '';
                      final taf = _tafsir.length > idx ? _tafsir[idx] : '';

                      final key = _verseKey(ayaNum);
                      final isFav = _favoriteKeys.contains(key);

                      final subtleAccent = isDark ? Colors.white.withOpacity(0.70) : Colors.black.withOpacity(0.55);

                      return Column(
                        children: [
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: InkWell(
                                onTap: () => _toggleTafsir(ayaNum),
                                onLongPress: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0B1025).withOpacity(0.45) : Colors.white.withOpacity(0.75),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                              border: Border.all(
                                                color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                                              ),
                                            ),
                                            child: Text(
                                              '$ayaNum',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.70),
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            iconSize: 18,
                                            onPressed: () => _toggleFavorite(ayaNum),
                                            icon: Icon(
                                              isFav ? Icons.favorite : Icons.favorite_border,
                                              color: isFav ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black54),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            iconSize: 18,
                                            onPressed: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                                            icon: Icon(
                                              Icons.more_horiz_rounded,
                                              color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_showArabic) ...[
                                        const SizedBox(height: 10),
                                        Builder(
                                          builder: (_) {
                                            final style = TextStyle(
                                              fontSize: _fontArabic,
                                              height: 2.6,
                                              fontFamily: 'ScheherazadeNew',
                                              fontWeight: FontWeight.w600,
                                              wordSpacing: 5,
                                              letterSpacing: 0.6,
                                              color: arabicColor,
                                            );

                                            final clean = _stripTrailingAyahNumber(ar);
                                            final spans = _parseTajweedSpans(clean, arabicColor);

                                            spans.add(
                                              TextSpan(
                                                text: ' ﴿${_toArabicIndic(ayaNum)}﴾',
                                                style: TextStyle(
                                                  color: subtleAccent,
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 3,
                                              height: 42,
                                              margin: const EdgeInsets.only(right: 10, top: 2),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                tr,
                                                textAlign: TextAlign.justify,
                                                style: TextStyle(
                                                  fontSize: _fontTranslation + 1,
                                                  height: 1.7,
                                                  fontFamily: 'serif',
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.92 : 0.88),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tafsir (tap)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),

                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeOutCubic,
                                        child: (_openTafsirKey == key)
                                            ? Padding(
                                                padding: const EdgeInsets.only(top: 12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                                    border: Border.all(
                                                      color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Tafsir',
                                                        style: TextStyle(
                                                          fontSize: _fontTafsir + 1,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? Colors.white70 : Colors.black54,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        taf.trim().isEmpty ? 'Tafsir indisponible.' : taf,
                                                        style: TextStyle(
                                                          fontSize: _fontTafsir,
                                                          height: 1.45,
                                                          fontFamily: 'serif',
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.88 : 0.82),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
