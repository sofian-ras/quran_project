import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../surah_name.dart';
import '../hizb_juzz.dart';
import '../services/quran_translation_pack_service.dart';
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
      if (mounted) _load();
    });
  }


  Future<void> _load() async {
    // évite setState trop tôt
    _loading = true;
    _error = null;

    if (mounted) setState(() {});

    try {
      final langCode = Localizations.localeOf(context).languageCode.toLowerCase();
      final lang = langCode.startsWith('en') ? AppLang.en : AppLang.fr;

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
        final trAyahs = (trRes.data as List);
        _translation = trAyahs.map((e) => (e['translation'] ?? '').toString()).toList();

        // 3) Tafsir abrégé
        final tafRes = await _dio.get('$_quranEncBase/translation/sura/$_tafsirKey/${widget.surahNumber}');
        final tafAyahs = (tafRes.data as List);
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

  @override
  Widget build(BuildContext context) {
    final title = '${widget.surahNumber}. ${widget.surahNameFr}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text(_error!))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _arabic.length,
                  itemBuilder: (context, i) {
                    final ayaNum = i + 1;
                    final ar = _arabic.length > i ? _arabic[i] : '';
                    final tr = _translation.length > i ? _translation[i] : '';
                    final taf = _tafsir.length > i ? _tafsir[i] : '';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$ayaNum',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ar,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(tr),
                            const SizedBox(height: 10),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Tafsir (résumé)'),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(taf),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
