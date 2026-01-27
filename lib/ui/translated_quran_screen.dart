import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../surah_name.dart';
import '../hizb_juzz.dart';
import '../services/quran_translation_pack_service.dart';
import '../services/verse_favorites_service.dart';
import 'package:sqflite/sqflite.dart';

class TranslatedQuranScreen extends StatelessWidget {
  final bool preferOffline; // si true: on essaie le pack, sinon online

  const TranslatedQuranScreen({super.key, required this.preferOffline});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('en');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEn ? 'Translated Quran' : 'Coran traduit'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sourates'),
              Tab(text: 'Juz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SurahTab(preferOffline: preferOffline),
            _JuzTab(preferOffline: preferOffline),
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

    setState(() => _loading = false);
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _surahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _surahs[index];
        final surahId = (s['id'] is int) ? s['id'] as int : int.tryParse('${s['id']}') ?? 0;
        final isEn = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');

        final nameAr = (s['nameAr'] ?? '').toString();

        final nameTr = isEn
            ? (surahEn[surahId] ?? 'Surah $surahId')
            : (surahFr[surahId] ?? 'Sourate $surahId');

        final titleColor = Theme.of(context).colorScheme.onSurface;
        final subColor = Theme.of(context).colorScheme.onSurfaceVariant;


        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: Theme.of(context).cardColor,
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
                  surahNameFr: nameTr,     // (garde ton champ, mais on lui passe le libellé FR/EN)
                  surahNameAr: nameAr,
                  preferOffline: widget.preferOffline,
                ),
              ),
            );
          },
        );

      },
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

  // QuranEnc (traduction + “mokhtasar” en tafsir abrégé) :contentReference[oaicite:6]{index=6}
  static const _quranEncBase = 'https://quranenc.com/api/v1';
  static const _translationKey = 'french_hameedullah';
  static const _tafsirKey = 'french_mokhtasar';

  // AlQuran.cloud pour le texte arabe (édition par défaut: quran-uthmani) :contentReference[oaicite:7]{index=7}
  static const _alquranBase = 'https://api.alquran.cloud/v1';

  @override
  void initState() {
    super.initState();
  }
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
    // évite setState trop tôt
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

        // IMPORTANT: dans tes 2 DB (FR et EN), la traduction est dans la colonne "fr"
        _translation = rows.map((r) => (r['fr'] as String?) ?? '').toList();

        _tafsir = rows.map((r) => (r['tafsir'] as String?) ?? '').toList();
      } else {
        // 1) Arabe
        final arRes = await _dio.get('$_alquranBase/surah/${widget.surahNumber}/quran-uthmani');
        final arAyahs = (arRes.data['data']['ayahs'] as List);
        _arabic = arAyahs.map((e) => (e['text'] ?? '').toString()).toList();

        // 2) Traduction
        final trRes = await _dio.get('$_quranEncBase/translation/sura/$_translationKey/${widget.surahNumber}');
        final trAyahs = _extractQuranEncList(trRes.data);
        _translation = trAyahs.map((e) => (e['translation'] ?? '').toString()).toList();

        // 3) Tafsir abrégé
        final tafRes = await _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}');
        final tafAyahs = _extractQuranEncList(tafRes.data);
        _tafsir = tafAyahs.map((e) => (e['translation'] ?? '').toString()).toList();
      }

      setState(() => _loading = false);
    } catch (e) {
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
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
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
                            onChanged: (v) => setStateSheet(() => _fontArabic = v),
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
                            onChanged: (v) => setStateSheet(() => _fontTranslation = v),
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
                            onChanged: (v) => setStateSheet(() => _fontTafsir = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {});
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Appliquer'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copié')),
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
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

  Widget _softDivider(Color color) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.0),
            color.withOpacity(0.35),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
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
      spans.add(
        TextSpan(
          text: txt,
          style: TextStyle(color: _tajweedColors[cls] ?? fallback),
        ),
      );
      last = m.end;
    }
    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last), style: TextStyle(color: fallback)));
    }
    return spans;
  }

  String _stripTrailingAyahNumber(String input) {
    return input.replaceAll(RegExp(r'[\s\u0660-\u0669\u06F0-\u06F9]+$'), '');
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
    final accentColor = isDark ? const Color(0xFFE3C880) : const Color(0xFFB37A2A);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(isDark ? 0.18 : 0.12),
                              accentColor.withOpacity(isDark ? 0.08 : 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: accentColor.withOpacity(0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.18),
                              blurRadius: 18,
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
                                shadows: [
                                  Shadow(
                                    color: accentColor.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.surahNameFr,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor.withOpacity(0.9),
                                    accentColor.withOpacity(0.0),
                                  ],
                                ),
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [
                                  Color(0xFF141B3A),
                                  Color(0xFF10162E),
                                ]
                              : const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF6F2EA),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: accentColor.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onLongPress: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor.withOpacity(0.0),
                                    accentColor.withOpacity(0.6),
                                    accentColor.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: accentColor.withOpacity(0.18),
                                  ),
                                  child: Text(
                                    '$ayaNum',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _toggleFavorite(ayaNum),
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.redAccent : null,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _toggleTafsir(ayaNum),
                                  icon: Icon(
                                    _openTafsirKey == key ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                                    color: _openTafsirKey == key ? accentColor : null,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showVerseActions(ayah: ayaNum, ar: ar, tr: tr),
                                  icon: const Icon(Icons.more_horiz_rounded),
                                ),
                              ],
                            ),
                            if (_showArabic) ...[
                              _softDivider(accentColor),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (_) {
                                  final style = TextStyle(
                                    fontSize: _fontArabic,
                                  height: 3.0,
                                    fontFamily: 'ScheherazadeNew',
                                    fontWeight: FontWeight.w600,
                                  wordSpacing: 6,
                                  letterSpacing: 0.7,
                                    color: arabicColor,
                                    shadows: [
                                      Shadow(
                                        color: accentColor.withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  );
                                  final clean = _stripTrailingAyahNumber(ar);
                                  final spans = _parseTajweedSpans(clean, arabicColor);
                                  spans.add(
                                    TextSpan(
                                      text: ' ﴿${_toArabicIndic(ayaNum)}﴾',
                                      style: TextStyle(
                                        color: accentColor,
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
                              _softDivider(accentColor),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDark
                                      ? const Color(0xFF0E1530).withOpacity(0.7)
                                      : const Color(0xFFFFF8EE),
                                  border: Border.all(
                                    color: accentColor.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 42,
                                      margin: const EdgeInsets.only(right: 10, top: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: accentColor.withOpacity(0.7),
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(isDark ? 0.95 : 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_openTafsirKey == key) ...[
                              _softDivider(accentColor),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                                ),
                                child: Text(
                                  taf.trim().isEmpty ? 'Tafsir indisponible.' : taf,
                                  style: TextStyle(
                                    fontSize: _fontTafsir,
                                    height: 1.45,
                                    fontFamily: 'serif',
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                            /*
                              title: const Text('Tafsir (résumé)'),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(taf),
                                ),
                              ],
                            ),
                            */
                          ],
                        ),
                      ),
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
    // Pour un Juz “propre” (découpage exact + tafsir), le plus optimal est:
    // Juz info (QUL) -> verse_mapping -> fetch par sourates (QuranEnc) puis slice.
    // On l’ajoute à l’étape suivante (car il faut intégrer le JSON "Juz info"). :contentReference[oaicite:8]{index=8}
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
