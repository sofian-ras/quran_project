// lib/ui/translated_quran_screen.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../hizb_juzz.dart';
import '../services/quran_translation_pack_service.dart';
import '../services/verse_favorites_service.dart';
import '../services/audio_service.dart';
import '../surah_name.dart';

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
      _keys = favs.toList()..sort((a, b) {
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

    final bg = isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
    final tileBg = isDark ? const Color(0xFF0F1734) : Colors.white;
    final border = isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
    final titleColor = isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.90);
    final subColor = isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.60);

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

          return Container(
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                '$surahId. $nameTr',
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                nameAr,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: subColor, height: 1.4),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: subColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);

    return Container(
      color: bg,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: juzzMap.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final juz = juzzMap[i]['juz']!;
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: isDark ? const Color(0xFF0F1734) : Colors.white,
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
      ),
    );
  }
}

enum _BarPanel { reciters, settings }

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
  bool _shouldShowBasmalaForThisSurah() {
    // Sourate 1: la basmala fait partie du verset (selon beaucoup d'affichages)
    // Sourate 9: pas de basmala
    return widget.surahNumber != 1 && widget.surahNumber != 9;
  }

String _removeLeadingBasmalaIfPresent(String input) {
  final index = input.indexOf('الرَّحِيم');
  if (index == -1) return input;

  // on coupe juste après الرحيم
  final end = index + 'الرَّحِيم'.length;

  // sécurité : seulement si ça se trouve vraiment au début du verset
  if (end < 60) {
    return input.substring(end).trimLeft();
  }

  return input;
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

  final ScrollController _scrollController = ScrollController();
  int _selectedAyah = 1;

  int _repeatTimes = 1; // 1,3,5,-1...
  bool _loopRangeEnabled = false;
  int? _loopStartAyah;
  int? _loopEndAyah;

  int _rangeRepeatTimes = 1; // 1..25 ou -1 pour ∞
  int _eachAyahRepeatTimes = 1; // 1..25

  bool _barExpanded = false;
  _BarPanel _barPanel = _BarPanel.reciters;
  double _playbackSpeed = 1.0;

  // Choix API (quranenc)
  String _translationKey = 'french_hameedullah';
  String _tafsirKey = 'french_mokhtasar';

  // Options (tu peux en ajouter quand tu veux)
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
        if (_isTafsirMostlyEmpty()) {
          await _loadTafsirOnlineFallback();
          _normalizeLengths();
        }

        _selectedAyah = _selectedAyah.clamp(1, _arabic.length);
        _loopStartAyah ??= _selectedAyah;
        _loopEndAyah ??= (_selectedAyah + 1).clamp(1, _arabic.length);

        // assure scroll sur le verset initial (ex: favoris)
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
    if (!_scrollController.hasClients) return;

    const double header = 90;
    const double approxItem = 185;

    double target = header + (ayah - 1) * approxItem;

    if (center) {
      final viewport = _scrollController.position.viewportDimension;
      target = target - (viewport / 2) + (approxItem / 2);
    }

    final max = _scrollController.position.maxScrollExtent;
    target = target.clamp(0.0, max);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
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
    if (!mounted) return;
    setState(() => _barExpanded = false);
  }

  Future<void> _showAyahReciterDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svc = AudioService.instance;

    await showDialog(
      context: context,
      builder: (ctx) {
        AyahReciter selected = svc.currentAyahReciterNotifier.value;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF),
          title: const Text('Récitant (verset par verset)'),
          content: SizedBox(
            width: 420,
            child: StatefulBuilder(
              builder: (_, setStateDialog) {
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: AudioService.ayahReciters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final r = AudioService.ayahReciters[i];
                    final isSelected = r.folder == selected.folder;
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border(isDark)),
                      ),
                      child: ListTile(
                        title: Text(r.name),
                        subtitle: Text(r.folder, style: const TextStyle(fontSize: 12)),
                        trailing: isSelected ? const Icon(Icons.check_rounded) : null,
                        onTap: () => setStateDialog(() => selected = r),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                svc.setAyahReciter(selected);
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    setState(() {});
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

    final fg = _text(isDark);
    final subtle = _muted(isDark);
    final border = _border(isDark);
    final accent = _accent(isDark);

    final bg = isDark ? const Color(0xFF0B1025) : const Color(0xFFF9F6EF);
    final chipBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

    final svc = AudioService.instance;
    final reciterName = svc.currentAyahReciterNotifier.value.name;

    final active = currentKey != null;

    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    const rangeRepeatOptions = <int>[1, 2, 3, 5, 10, 25, -1];
    const eachAyahRepeatOptions = <int>[1, 2, 3, 5, 10, 25];

    String repeatText(int v) => v == -1 ? '∞' : '×$v';

    void openReciters() {
      setState(() {
        _barExpanded = true;
        _barPanel = _BarPanel.reciters;
      });
    }

    void openSettings() {
      setState(() {
        _barExpanded = true;
        _barPanel = _BarPanel.settings;
      });
    }

    void collapseBar() => setState(() => _barExpanded = false);

    IconButton bouton({
      required VoidCallback? onPressed,
      required IconData icon,
      String? tooltip,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      );
    }

    Widget petitChip({required Widget child, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: chipBg,
            border: Border.all(color: border),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: subtle,
              fontSize: 12,
            ),
            child: child,
          ),
        ),
      );
    }

    Widget compactRow() {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            bouton(onPressed: _stopFromBar, icon: Icons.stop_rounded, tooltip: 'Stop'),
            bouton(onPressed: _selectedAyah <= 1 ? null : _playPrevFromBar, icon: Icons.skip_previous_rounded),
            bouton(onPressed: _togglePlayPauseFromBar, icon: playingThis ? Icons.pause_rounded : Icons.play_arrow_rounded),
            bouton(onPressed: _selectedAyah >= _arabic.length ? null : _playNextFromBar, icon: Icons.skip_next_rounded),

            const SizedBox(width: 8),

            petitChip(
              onTap: _cycleRepeatFromBar,
              child: Text(_repeatLabel()),
            ),

            const SizedBox(width: 8),

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
                    child: Text('${v.toStringAsFixed(v == 1.0 ? 0 : 2)}×'),
                  ),
              ],
              child: petitChip(
                onTap: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 16, color: subtle),
                    const SizedBox(width: 8),
                    Text('${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.0 ? 0 : 2)}×'),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            bouton(onPressed: openSettings, icon: Icons.settings_rounded, tooltip: 'Paramètres'),
          ],
        ),
      );
    }

    // FIX overflow: row scrollable horizontal
   Widget controlsRow() {
    IconButton bouton({
      required VoidCallback? onPressed,
      required IconData icon,
      String? tooltip,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      );
    }

    Widget petitChip({required Widget child, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: chipBg,
            border: Border.all(color: border),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: subtle,
              fontSize: 12,
            ),
            child: child,
          ),
        ),
      );
    }

    return Row(
      children: [
        bouton(onPressed: _stopFromBar, icon: Icons.stop_rounded, tooltip: 'Stop'),
        bouton(onPressed: _selectedAyah <= 1 ? null : _playPrevFromBar, icon: Icons.skip_previous_rounded),
        bouton(onPressed: _togglePlayPauseFromBar, icon: playingThis ? Icons.pause_rounded : Icons.play_arrow_rounded),
        bouton(onPressed: _selectedAyah >= _arabic.length ? null : _playNextFromBar, icon: Icons.skip_next_rounded),

        const SizedBox(width: 8),

        // répétition
        petitChip(
          onTap: _cycleRepeatFromBar,
          child: Text(_repeatLabel()),
        ),

        const SizedBox(width: 8),

        // vitesse
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
                child: Text('${v.toStringAsFixed(v == 1.0 ? 0 : 2)}×'),
              ),
          ],
          child: petitChip(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed_rounded, size: 16, color: subtle),
                const SizedBox(width: 8),
                Text('${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.0 ? 0 : 2)}×'),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // paramètres
        bouton(onPressed: openSettings, icon: Icons.settings_rounded, tooltip: 'Paramètres'),
      ],
    );
  }

    Widget recitersPanel() {
      final selected = svc.currentAyahReciterNotifier.value;

      return ListView.separated(
        itemCount: AudioService.ayahReciters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final r = AudioService.ayahReciters[i];
          final isSelected = r.folder == selected.folder;

          return Container(
            decoration: BoxDecoration(
              color: isSelected ? accent.withOpacity(isDark ? 0.12 : 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: ListTile(
              dense: true,
              title: Text(r.name, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              subtitle: Text(r.folder, style: TextStyle(fontSize: 12, color: subtle)),
              trailing: isSelected ? Icon(Icons.check_rounded, color: accent) : null,
              onTap: () {
                svc.setAyahReciter(r);
                setState(() => _barExpanded = false);
              },
            ),
          );
        },
      );
    }

    Widget choiceChipGold({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        label: Text(label, style: TextStyle(color: selected ? fg : subtle, fontWeight: FontWeight.w800)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: accent.withOpacity(isDark ? 0.18 : 0.16),
        backgroundColor: chipBg,
        side: BorderSide(color: selected ? accent.withOpacity(0.55) : border),
        checkmarkColor: accent,
      );
    }

    Widget settingsPanel() {
      final maxAyah = _arabic.isEmpty ? 1 : _arabic.length;
      final start = (_loopStartAyah ?? _selectedAyah).clamp(1, maxAyah);
      final end = (_loopEndAyah ?? (_selectedAyah + 1)).clamp(1, maxAyah);

      InputDecoration deco(String label) => InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: subtle, fontWeight: FontWeight.w700),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.7))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          );

      return ListView(
        children: [
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
              setState(() => _tafsirKey = v);
              await _load();
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
              color: chipBg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Boucle plage (Start → End)', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                    ),
                    Switch(
                      value: _loopRangeEnabled,
                      onChanged: (v) => setState(() => _loopRangeEnabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: start,
                        dropdownColor: isDark ? const Color(0xFF0F1734) : Colors.white,
                        decoration: deco('Start'),
                        style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                        items: [
                          for (int i = 1; i <= maxAyah; i++)
                            DropdownMenuItem(value: i, child: Text('$i', style: TextStyle(color: fg))),
                        ],
                        onChanged: (v) => setState(() => _loopStartAyah = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: end,
                        dropdownColor: isDark ? const Color(0xFF0F1734) : Colors.white,
                        decoration: deco('End'),
                        style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                        items: [
                          for (int i = 1; i <= maxAyah; i++)
                            DropdownMenuItem(value: i, child: Text('$i', style: TextStyle(color: fg))),
                        ],
                        onChanged: (v) => setState(() => _loopEndAyah = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
              color: chipBg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Répéter la plage', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in rangeRepeatOptions)
                      choiceChipGold(
                        label: repeatText(v),
                        selected: _rangeRepeatTimes == v,
                        onTap: () => setState(() => _rangeRepeatTimes = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
              color: chipBg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Répéter chaque ayah', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in eachAyahRepeatOptions)
                      choiceChipGold(
                        label: repeatText(v),
                        selected: _eachAyahRepeatTimes == v,
                        onTap: () => setState(() => _eachAyahRepeatTimes = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget expandedPanel() {
      if (!_barExpanded) return const SizedBox.shrink();

      final maxH = MediaQuery.of(context).size.height * 0.42;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _barPanel == _BarPanel.reciters ? 'Récitateur' : 'Paramètres',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(onPressed: collapseBar, icon: const Icon(Icons.close_rounded), tooltip: 'Fermer'),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(child: _barPanel == _BarPanel.reciters ? recitersPanel() : settingsPanel()),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        // IMPORTANT: on ne met plus le même bg que la page
        // On met une "surface" (card) qui ressort.
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1734) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                blurRadius: isDark ? 18 : 22,
                spreadRadius: 0,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: active ? controlsRow() : compactRow(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: expandedPanel(),
                ),
              ],
            ),
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
            tooltip: 'Récitant (verset par verset)',
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: _showAyahReciterDialog,
          ),
          IconButton(
            tooltip: 'Affichage',
            onPressed: _showSettingsSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: merged,
        builder: (_, __) {
          final currentKey = AudioService.instance.currentAyahKeyNotifier.value;
          final mode = AudioService.instance.ayahPlayModeNotifier.value;
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
      body: Container(
        color: _bg(isDark),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_arabic.isEmpty)
                ? Center(child: Text(_error ?? 'Aucun verset', style: TextStyle(color: subtle)))
                : AnimatedBuilder(
                    animation: merged,
                    builder: (_, __) {
                      final currentKey = AudioService.instance.currentAyahKeyNotifier.value;
                      final mode = AudioService.instance.ayahPlayModeNotifier.value;
                      final isPlaying = AudioService.instance.isAyahPlayingNotifier.value;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
                          final highlight = isPlayingThis ? _accent(isDark).withOpacity(isDark ? 0.16 : 0.12) : Colors.transparent;

                          return InkWell(
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
                                          letterSpacing: 0.4,
                                          color: fg,
                                        );

                                      var clean = _stripTrailingAyahNumber(ar);

                                      // enlever la basmala du verset 1 (sauf sourate 1 et 9)
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
                                        color: fg.withOpacity(isDark ? 0.86 : 0.82),
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
                                                color: fg.withOpacity(isDark ? 0.78 : 0.74),
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