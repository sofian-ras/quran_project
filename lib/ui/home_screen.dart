import 'dart:convert';
import 'dua_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/quran_image_service.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../services/reading_history_service.dart';
import '../services/quran_translation_pack_service.dart';
import 'package:sqflite/sqflite.dart';
import '../surah_name.dart';
import 'reciter_picker_screen.dart';
import 'reader_screen.dart';
import 'tafsir_library_screen.dart';
import 'screens/quran_loader.dart';
import 'surah_list_screen.dart';
import 'translated_quran_screen.dart';
import 'widgets/continue_reading_card.dart';
import 'widgets/youtube_video_card.dart';
import 'widgets/prayer_times_card_v2.dart';
import '../theme/theme_service.dart';
import '../models/reciter.dart';
import 'package:dio/dio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'widgets/location_picker_dialog.dart';
import '../services/location_service.dart';
import 'prayers_screen.dart';
import '../services/mp3quran_api.dart';
part 'home_screen_widgets.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  bool _statusBarGreen = false;
  bool _isUserScrolling = false;
  static const double hPad = 14;
  static const double vGap = 12;
  String _prettyMoshafName(String raw) {
    final s = raw.toLowerCase();

    String riwaya;
    if (s.contains('hafs')) riwaya = 'Hafs';
    else if (s.contains('warsh')) riwaya = 'Warsh';
    else if (s.contains('khalaf')) riwaya = 'Khalaf';
    else if (s.contains('assosi') || s.contains('soosi') || s.contains('soussi')) riwaya = 'As-Soosi';
    else riwaya = raw;

    String type = '';
    if (s.contains('murattal')) type = 'Murattal';
    else if (s.contains('mujawwad') || s.contains('mujawad')) type = 'Mujawwad';

    return type.isEmpty ? riwaya : '$riwaya â€¢ $type';
  }

  String? _pickDefaultServer(List<_MoshafOption> list) {
    // Priorité: Hafs, sinon 1er
    final hafs = list.where((o) => o.name.toLowerCase().contains('hafs')).toList();
    if (hafs.isNotEmpty) return hafs.first.server;
    return list.first.server;
  }

  @override
  bool get wantKeepAlive => true;

  final AudioService _audio = AudioService.instance;

  List<Map<String, dynamic>> fullSurahList = [];
  final Map<String, List<_MoshafOption>> _moshafByName = {};
  final Map<int, List<_MoshafOption>> _moshafById = {}; // Ajout pour indexation par reciterId
  bool _isLoading = true;
  List<Map<String, dynamic>> filteredList = [];
  String _preferredReading = 'hafs';
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>(<int>{});
  List<Reciter> _reciters = [];
  bool _recitersLoading = true;
  final Map<String, String> _reciterAssetsByName = {};
  final Map<int, String> _baseUrlById = {}; // Cache des baseUrl préchargées
  final Dio _dio = Dio();
  bool _serversLoading = false;

  late Future<_PrayerHeaderData> _prayerFuture;


  

@override
void initState() {
  super.initState();
  
  // Vérifie si c'est la première fois
  _checkFirstLaunch();
  
  _prayerFuture = _loadPrayerHeader();
  _loadSurahData();
  _loadPreferredReading();
  _loadFavorites();
  _loadReciters();
  _loadReciterServersIfNeeded();

  _scrollCtrl.addListener(() {
    final shouldBeGreen = _scrollCtrl.offset > 4; // seuil
    if (shouldBeGreen == _statusBarGreen) return;
    setState(() => _statusBarGreen = shouldBeGreen);
  });

}

Future<void> _checkFirstLaunch() async {
  final isFirst = await LocationService.isFirstTime();
  if (isFirst && mounted) {
    // Attends que le widget soit construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationPicker();
    });
  }
}

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startSurahAudio(Map<String, dynamic> s) {
    // Appelle la nouvelle fonction de playlist dans le service audio
    _audio.loadPlaylistAndPlay(s['id'] as int);
  }

  Future<void> _loadSurahData() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;

    final List<Map<String, dynamic>> list = [];
    final Map<int, int> ayahCounts = {};
    final Map<int, int> startPage = {};

    for (final v in quranData) {
      final surahRaw = v['surah'];
      final pageRaw = v['page'];

      final int? id = (surahRaw is int) ? surahRaw : int.tryParse('$surahRaw');
      if (id == null) continue; // skip lignes invalides

      final int page = (pageRaw is int) ? pageRaw : (int.tryParse('$pageRaw') ?? 1);

      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
      startPage[id] = startPage[id] ?? page;
    }

    for (final id in ayahCounts.keys) {
      final ar = quranData.firstWhere(
        (e) => e['surah'] == id,
        orElse: () => null,
      );

      list.add({
        'id': id,
        'nameAr': ar?['sura_name'] ?? 'Sourate $id',
        'nameFr': surahFr[id] ?? 'Sourate $id',
        'page': startPage[id] ?? 1,
        'ayahCount': ayahCounts[id] ?? 0,
      });
    }


    list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    setState(() {
      fullSurahList = list;
      filteredList = List.from(list);
      _isLoading = false;
    });
  }
  Future<void> _loadPreferredReading() async {
    final reading = await ReadingHistoryService.instance.getPreferredReading();
    if (mounted) {
      setState(() => _preferredReading = reading);
    }
  }
  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteIdsNotifier.value = favs;
    });
  }

  Future<void> _loadReciters() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/reciters_mapping.json');
      final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;

      final List<Reciter> list = [];
      final List<int> reciterIds = [];
      _reciterAssetsByName.clear();

      for (final e in data) {
        final m = e as Map<String, dynamic>;
        final name = (m['name'] ?? '').toString().trim();
        final asset = (m['asset'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final reciterId = m['reciterId'] as int?;
        if (reciterId != null) {
          reciterIds.add(reciterId);
        }

        list.add(Reciter(
          id: '',
          name: name,
          server: '',
          letter: '',
          reciterId: reciterId,
          moshafId: null,
          baseUrl: null, // Sera récupéré dynamiquement
        ));

        if (asset.isNotEmpty) {
          _reciterAssetsByName[name] = asset;
        }
      }

      if (!mounted) return;
      setState(() {
        _reciters = list;
        _recitersLoading = false;
      });

      // Précharger les baseUrl en arrière-plan
      if (reciterIds.isNotEmpty) {
        _preloadBaseUrls(reciterIds);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _recitersLoading = false);
    }
  }

  Future<void> _preloadBaseUrls(List<int> reciterIds) async {
    try {
      final baseUrls = await Mp3QuranApi.instance.preloadBaseUrls(reciterIds);
      if (!mounted) return;
      setState(() {
        _baseUrlById.addAll(baseUrls);
      });
    } catch (e) {
      debugPrint('Erreur lors du préchargement des baseUrl: $e');
    }
  }

  String _prayerMethodLabel(String id) {
    const labels = <String, String>{
      '2':  'ISNA',
      '3':  'Muslim World League',
      '4':  'Umm al-Qura, Makkah',
      '5':  'Egyptian Authority',
      '8':  'Gulf Region',
      '9':  'Kuwait',
      '10': 'Qatar',
      '11': 'Singapour (MUIS)',
      '12': 'UOIF – France',
      '13': 'Turkey (Diyanet)',
      '14': 'Russie',
      '15': 'Moon Sighting Committee',
      '16': 'Dubai',
      '17': 'Malaysia (JAKIM)',
      '18': 'Tunisie',
      '19': 'Algérie',
      '20': 'Indonésie (KEMENAG)',
      '21': 'Maroc',
      '22': 'Portugal',
      '23': 'Jordanie',
    };
    return labels[id] ?? 'Méthode $id';
  }

  Future<_PrayerHeaderData> _loadPrayerHeader() async {
    final location = await LocationService.getSavedOrCurrentLocation();
    final prefs = await SharedPreferences.getInstance();
    final methodRaw = (prefs.getString('prayer_method') ?? '12').trim();
    final method = methodRaw.isEmpty ? '12' : methodRaw;
    final methodLabel = _prayerMethodLabel(method);
    // Utilise les coordonnées si disponibles, sinon l'API par ville
    Uri uri;
    if (!location.isManual && location.latitude != 0 && location.longitude != 0) {
      // Précision GPS avec coordonnées
      uri = Uri.https('api.aladhan.com', '/v1/timings/${DateTime.now().millisecondsSinceEpoch ~/ 1000}', {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'method': method,
      });
    } else {
      // Fallback par nom de ville
      uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
        'city': location.city,
        'country': location.country,
        'method': method,
      });
    }

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return _PrayerHeaderData.error(city: location.city, country: location.country);
      }

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (payload['data'] as Map<String, dynamic>?) ?? {};

      final timings = (data['timings'] as Map<String, dynamic>?) ?? {};
      final date = (data['date'] as Map<String, dynamic>?) ?? {};
      final hijri = (date['hijri'] as Map<String, dynamic>?) ?? {};

      final hijriLine = _formatHijri(hijri);
      final times = _extractTimes(timings);

      return _PrayerHeaderData(
        city: location.city,      // â† Affiche seulement la ville
        country: location.country,
        hijriLine: hijriLine,
        times: times,
        methodLabel: methodLabel,
      );
    } catch (e) {
      return _PrayerHeaderData.error(city: location.city, country: location.country);
    }
  }

  Future<void> _showLocationPicker() async {
  final result = await showDialog<LocationData>(
    context: context,
    builder: (_) => const LocationPickerDialog(),
  );

  if (result != null && mounted) {
    // Recharge les horaires avec la nouvelle localisation
    setState(() {
      _prayerFuture = _loadPrayerHeader();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Localisation : ${result.displayLocation}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

  Map<String, String> _extractTimes(Map<String, dynamic> timings) {
    String clean(dynamic raw) {
      if (raw == null) return '--:--';
      final v = raw.toString().trim();
      if (v.isEmpty) return '--:--';
      return v.split(' ').first;
    }

    return {
      'Fajr': clean(timings['Fajr']),
      'Sunrise': clean(timings['Sunrise']),
      'Dhohr': clean(timings['Dhuhr']),
      'Asr': clean(timings['Asr']),
      'Maghrib': clean(timings['Maghrib']),
      'Isha': clean(timings['Isha']),
    };
  }

  String _formatHijri(Map<String, dynamic> hijri) {
    final day = hijri['day']?.toString() ?? '';
    final month = (hijri['month'] as Map<String, dynamic>?)?['en']?.toString() ?? '';
    final year = hijri['year']?.toString() ?? '';
    if (day.isEmpty || month.isEmpty || year.isEmpty) return '';
    return "$month $day, $year AH";
  }

  int _activeIndexFromTimes(List<(String, String)> prayers) {
    final now = DateTime.now();
    DateTime? parseToday(String t) {
      final parts = t.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(now.year, now.month, now.day, h, m);
    }

    for (int i = 0; i < prayers.length; i++) {
      final dt = parseToday(prayers[i].$2);
      if (dt != null && dt.isAfter(now)) return i;
    }
    return 0;
  }

  void _openSurahListScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahListScreen(
          surahList: filteredList,
          favoriteIdsNotifier: _favoriteIdsNotifier,
          onOpenReader: (page) => _openReader(page),
          onPlaySurah: (s) => _startSurahAudio(s),
        ),
      ),
    );
  }

  Future<bool> _showPagesDownloadPrompt() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1734) : const Color(0xFFFFFFFF);
    final titleColor = isDark ? const Color(0xFFF6E9D7) : const Color(0xFF5B3F12);
    final textColor = isDark ? Colors.white70 : const Color(0xFF5B4A2F);
    final accent = const Color(0xFFFFFFFF);

    final shouldDownload = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_download_rounded, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Telechargement requis',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Pour lire les pages (Hafs et Warsh), l\'application doit telecharger les images une seule fois.',
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: titleColor,
                          side: BorderSide(color: accent.withOpacity(0.6)),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: const Color(0xFF1B1205),
                        ),
                        child: const Text('Telecharger'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldDownload ?? false;
  }

  Future<void> _openReader(int page, {String? reading}) async {
    final selectedReading = reading ?? _preferredReading;

    try {
      // La page est déjà dans _syncCache (chargée par SurahCard._handleTap).
      // getPageFile est instantané ici, on navigue immédiatement.
      await QuranImageService.getPageFile(selectedReading, page);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            initialPage: page,
            reading: selectedReading,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const QuranLoader()),
      );

      if (ok == true && mounted) {
        await _openReader(page, reading: selectedReading);
      }
    }
  }


  void _cycleTheme() {
    final current = ThemeService.themeMode.value;
    final next = (current == ThemeMode.system)
        ? ThemeMode.light
        : (current == ThemeMode.light)
            ? ThemeMode.dark
            : ThemeMode.system;
    ThemeService.setTheme(next);
  }

  String _normName(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<_MoshafOption?> _pickMoshaf(String reciterName, List<_MoshafOption> options) async {
    final ctx = NavigationService.navigatorKey.currentContext ?? context;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1734) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return showModalBottomSheet<_MoshafOption>(
      context: ctx,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reciterName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisir la riwāya',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: titleColor.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: titleColor.withOpacity(0.10),
                    ),
                    itemBuilder: (_, i) {
                      final o = options[i];
                      final pretty = _prettyMoshafName(o.name);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          pretty,
                          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
                        ),
                        subtitle: Text(
                          o.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor.withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          '${o.surahTotal} sourates',
                          style: TextStyle(
                            color: titleColor.withOpacity(0.55),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => Navigator.pop(sheetCtx, o),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _loadReciterServersIfNeeded() async {
    if (_moshafByName.isNotEmpty || _serversLoading) return;

    _serversLoading = true;
    try {
      final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=eng");
      final reciters = (res.data['reciters'] as List?) ?? const [];

      for (final item in reciters) {
        final r = item as Map<String, dynamic>;
        final reciterId = (r['id'] is int) ? (r['id'] as int) : int.tryParse('${r['id']}') ?? 0;
        final name = (r['name'] ?? '').toString().trim();
        final moshaf = (r['moshaf'] as List?) ?? const [];
        if (name.isEmpty || moshaf.isEmpty) continue;

        final List<_MoshafOption> options = [];

        for (final m in moshaf) {
          final mm = m as Map<String, dynamic>;
          final server = (mm['server'] ?? '').toString().trim();
          if (server.isEmpty) continue;

          final id = (mm['id'] is int) ? (mm['id'] as int) : int.tryParse('${mm['id']}') ?? 0;
          final mName = (mm['name'] ?? '').toString().trim();
          final total = (mm['surah_total'] is int) ? (mm['surah_total'] as int) : int.tryParse('${mm['surah_total']}') ?? 114;

          options.add(_MoshafOption(
            id: id,
            name: mName,
            server: server.endsWith('/') ? server.substring(0, server.length - 1) : server,

            surahTotal: total,
          ));
        }

        if (options.isNotEmpty) {
          _moshafByName[_normName(name)] = options;
          if (reciterId > 0) {
            _moshafById[reciterId] = options; // Indexer aussi par reciterId
          }
        }

      }
    } catch (_) {
      // ignore
    } finally {
      _serversLoading = false;
    }
  }


  Future<void> _onReciterSelected(Reciter r) async {
    String? server;
    
    // Résolution par NOM (plus fiable que reciterId pour les featured reciters)
    await _loadReciterServersIfNeeded();
    final options = _moshafByName[_normName(r.name)] ?? [];
    
    if (options.isNotEmpty) {
      server = _pickDefaultServer(options);
    }
    
    // Fallback: résoudre par nom via API
    if (server == null || server.isEmpty) {
      server = await _resolveServerForReciter(r.name);
    }
    
    // Si toujours pas de serveur, afficher une erreur
    if (server == null || server.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger ${r.name}')),
      );
      return;
    }

    // Normalisation: trim et enlever slash final
    server = server.trim();
    if (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }

    if (!mounted) return;

    final moshafLabel = options.isNotEmpty ? options.first.name : 'Hafs';
    final displayName = moshafLabel.isEmpty ? r.name : '${r.name} ($moshafLabel)';

    // Jouer directement sans naviguer — le mini player global apparaît
    _audio.setReciter(displayName, server);
    final lastSurah = _audio.currentPlayingSurahIdNotifier.value ?? 1;
    _audio.loadPlaylistAndPlay(lastSurah);
  }


    
  Future<String?> _resolveServerForReciter(String reciterName) async {
    try {
      final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=eng");
      final reciters = (res.data['reciters'] as List?) ?? [];

      for (final item in reciters) {
        final r = item as Map<String, dynamic>;
        final name = (r['name'] ?? '').toString();

        if (_normName(name) == _normName(reciterName)) {
          final moshaf = (r['moshaf'] as List?) ?? [];
          if (moshaf.isNotEmpty) {
            final server = (moshaf[0]['server'] ?? '').toString();
            if (server.isNotEmpty) return server;
          }
        }
      }
    } catch (_) {}
    return null;
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color statusBarColor = isDark
    ? Colors.transparent
    : (_statusBarGreen ? const Color(0xFFF7EEDB) : Colors.transparent);

    final overlay = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(overlay);

    final bgGradient = isDark
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
          Color(0xFFF2ECE5),
          Color(0xFFF2ECE5),
          Color(0xFFF2ECE5),
        ],
      );


    Widget loading() {
      return Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFFFFF)),
        ),
      );
    }

    Widget content() {
      return Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            // voile lumière subtil
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.04 : 0.06),
                        Colors.transparent,
                        Colors.white.withOpacity(isDark ? 0.02 : 0.03),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                final scrolling =
                    n is UserScrollNotification && n.direction != ScrollDirection.idle;
                if (scrolling != _isUserScrolling) {
                  setState(() => _isUserScrolling = scrolling);
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: hPad),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _HeaderWithEngagement(
                            audio: _audio,
                            onThemeTap: _cycleTheme,
                            onContinue: _openSurahListScreen,
                            onLocationTap: _showLocationPicker,
                            prayerFuture: _prayerFuture,
                            activeIndexFromTimes: _activeIndexFromTimes,
                            reciters: _reciters,
                            recitersLoading: _recitersLoading,
                            onReciterTap: _onReciterSelected,
                            getReciterAsset: (name) => _reciterAssetsByName[name] ?? '',
                            pausePrayerTicker: _isUserScrolling, // <-- AJOUT
                          ),
                          const SizedBox(height: vGap),
                          const _VerseOfTheDayCard(),
                          const SizedBox(height: vGap),
                          const YoutubeVideoCard(mode: QuranVideoMode.sufi),
                          const SizedBox(height: vGap),

                          _ExploreFeaturesSection(
                            features: const [
                              _FeatureChipData(label: 'Duʿa', imagePath: 'assets/images/Features/dua.webp'),
                              _FeatureChipData(label: 'Hadith', imagePath: 'assets/images/Features/hadith.webp'),
                              _FeatureChipData(label: 'Qibla', imagePath: 'assets/images/Features/qibla.webp'),
                              _FeatureChipData(label: 'Adhkar', imagePath: 'assets/images/Features/adhkar.webp'),
                              _FeatureChipData(label: 'Bookmarks', imagePath: 'assets/images/Features/bookmarks.webp'),
                            ],
                            onTap: (f) {
                              final ctx = NavigationService.navigatorKey.currentContext ?? context;
                              if (f.label == 'Duʿa') {
                                Navigator.of(ctx).push(
                                  MaterialPageRoute(builder: (_) => const DuaScreen()),
                                );
                                return;
                              }
                            },
                          ),
                          const SizedBox(height: vGap),

                          _ContentCardsSection(
                            items: const [
                              _ContentCardData(
                                title: 'Coran en français',
                                subtitle: 'Lire avec traduction',
                                imageAsset: 'assets/images/Programmes/coran_fr_thumbnail.webp',
                              ),
                              _ContentCardData(
                                title: 'Tafsir Session',
                                subtitle: 'Tonight • 20:30',
                                imageAsset: 'assets/images/Programmes/tafsir.webp',
                              ),
                            ],
                            onTap: (item) {
                              if (item.title == 'Coran en français') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TranslatedQuranScreen(preferOffline: true),
                                  ),
                                );
                              } else if (item.title == 'Tafsir Session') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TafsirLibraryScreen(),
                                  ),
                                );
                              }
                            },
                          ),

                          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

        ],
      ),
    );
  }

  return Scaffold(
    body: _isLoading ? loading() : content(),
  );
 }
}

