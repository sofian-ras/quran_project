import 'dart:async';
import 'dart:convert';
import 'dua_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';
import '../../services/favorites_service.dart';
import '../../services/quran_translation_pack_service.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/surah_name.dart';
import 'reciter_picker_screen.dart';
import 'tafsir_library_screen.dart';
import '../widgets/continue_reading_card.dart';
import '../widgets/youtube_video_card.dart';
import '../../models/reciter.dart';
import '../../models/prayer_header_data.dart';
import 'package:dio/dio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/location_picker_dialog.dart';
import '../../services/location_service.dart';
import 'prayers_screen.dart';
import '../../services/mp3quran_api.dart';
import 'radio_browser_screen.dart';
import 'quran_search_screen.dart';
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
  bool? _lastStatusBarGreen;
  bool? _lastIsDark;
  static const double hPad = 14;
  static const double vGap = 12;
  String? _pickDefaultServer(List<_HomeMoshafServer> list) {
    // Priorité: Hafs, sinon 1er
    final hafs = list.where((o) => o.name.toLowerCase().contains('hafs')).toList();
    if (hafs.isNotEmpty) return hafs.first.server;
    return list.first.server;
  }

  @override
  bool get wantKeepAlive => true;

  final AudioService _audio = AudioService.instance;

  final Map<String, List<_HomeMoshafServer>> _moshafByName = {};
  final Map<int, List<_HomeMoshafServer>> _moshafById = {}; // Ajout pour indexation par reciterId
  bool _isLoading = true;
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>(<int>{});
  List<Reciter> _reciters = [];
  bool _recitersLoading = true;
  final Map<String, String> _reciterAssetsByName = {};
  final Map<int, String> _baseUrlById = {}; // Cache des baseUrl préchargées
  final Dio _dio = Dio();
  bool _serversLoading = false;

  late Future<PrayerHeaderData> _prayerFuture;


  

@override
void initState() {
  super.initState();
  
  // Vérifie si c'est la première fois
  _checkFirstLaunch();
  
  _prayerFuture = _loadPrayerHeader();
  _loadSurahData();
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
    _favoriteIdsNotifier.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _loadSurahData() async {
    if (!mounted) return;
    setState(() => _isLoading = false);
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

  Future<PrayerHeaderData> _loadPrayerHeader() async {
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
        return PrayerHeaderData.error(city: location.city, country: location.country);
      }

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (payload['data'] as Map<String, dynamic>?) ?? {};

      final timings = (data['timings'] as Map<String, dynamic>?) ?? {};
      final date = (data['date'] as Map<String, dynamic>?) ?? {};
      final hijri = (date['hijri'] as Map<String, dynamic>?) ?? {};

      final hijriLine = _formatHijri(hijri);
      final times = _extractTimes(timings);

      return PrayerHeaderData(
        city: location.city,      // â† Affiche seulement la ville
        country: location.country,
        hijriLine: hijriLine,
        times: times,
        methodLabel: methodLabel,
      );
    } catch (e) {
      return PrayerHeaderData.error(city: location.city, country: location.country);
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



  static final _wsRe = RegExp(r'\s+');
  String _normName(String s) => s.toLowerCase().replaceAll(_wsRe, ' ').trim();

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

        final List<_HomeMoshafServer> options = [];

        for (final m in moshaf) {
          final mm = m as Map<String, dynamic>;
          final server = (mm['server'] ?? '').toString().trim();
          if (server.isEmpty) continue;

          final id = (mm['id'] is int) ? (mm['id'] as int) : int.tryParse('${mm['id']}') ?? 0;
          final mName = (mm['name'] ?? '').toString().trim();
          final total = (mm['surah_total'] is int) ? (mm['surah_total'] as int) : int.tryParse('${mm['surah_total']}') ?? 114;

          options.add(_HomeMoshafServer(
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
    await _loadReciterServersIfNeeded();
    final options = _moshafByName[_normName(r.name)] ?? [];
    String? server = options.isNotEmpty ? _pickDefaultServer(options) : null;

    if (server == null || server.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger ${r.name}')),
      );
      return;
    }

    server = server.trim();
    if (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }

    if (!mounted) return;

    final moshafLabel = options.isNotEmpty ? options.first.name : 'Hafs';
    final displayName = moshafLabel.isEmpty ? r.name : '${r.name} ($moshafLabel)';

    _audio.setReciter(displayName, server);
    final lastSurah = _audio.currentPlayingSurahIdNotifier.value ?? 1;
    _audio.loadPlaylistAndPlay(lastSurah);
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color statusBarColor = isDark
    ? Colors.transparent
    : (_statusBarGreen ? const Color(0xFFF7EEDB) : Colors.transparent);

    if (_lastIsDark != isDark || _lastStatusBarGreen != _statusBarGreen) {
      _lastIsDark = isDark;
      _lastStatusBarGreen = _statusBarGreen;
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ));
    }

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
          child: CircularProgressIndicator(),
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
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.06),
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDark ? 0.02 : 0.03),
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
                            onContinue: () {
                            final lastSurah = _audio.currentPlayingSurahIdNotifier.value ?? 1;
                            _audio.loadPlaylistAndPlay(lastSurah);
                          },
                            onLocationTap: _showLocationPicker,
                            onSearchTap: () => Navigator.of(context).push(
                              QuranSearchScreen.route(),
                            ),
                            prayerFuture: _prayerFuture,
                            activeIndexFromTimes: _activeIndexFromTimes,
                            reciters: _reciters,
                            recitersLoading: _recitersLoading,
                            onReciterTap: _onReciterSelected,
                            getReciterAsset: (name) => _reciterAssetsByName[name] ?? '',
                            pausePrayerTicker: _isUserScrolling,
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
                                title: 'Apprendre l\'arabe',
                                subtitle: 'Vocabulaire & grammaire',
                                imageAsset: 'assets/images/Programmes/coran_fr_thumbnail.webp',
                              ),
                              _ContentCardData(
                                title: 'Tafsir Session',
                                subtitle: 'Tonight • 20:30',
                                imageAsset: 'assets/images/Programmes/tafsir.webp',
                              ),
                            ],
                            onTap: (item) {
                              if (item.title == 'Apprendre l\'arabe') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bientôt disponible'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
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

