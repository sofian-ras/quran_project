import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
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
import 'full_player_screen.dart';
import 'reader_screen.dart';
import 'screens/quran_loader.dart';
import 'surah_list_screen.dart';
import 'translated_quran_screen.dart';
import 'widgets/ios_side_menu.dart';
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
import 'reciters_gallery_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  bool _statusBarGreen = false;
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

  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  bool _isMenuOpen = false;
  double _dragStartX = 0;

  

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

  _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  _menuAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic),
  );
}

  void _refreshPrayerHeader() {
    setState(() {
      _prayerFuture = _loadPrayerHeader();
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
    _menuController.dispose();
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
      print('Erreur lors du préchargement des baseUrl: $e');
    }
  }

  String _prayerMethodLabel(String id) {
    switch (id) {
      case '2':
        return 'ISNA (2)';
      case '3':
        return 'Muslim World League (3)';
      case '4':
        return 'Umm al-Qura (4)';
      case '5':
        return 'Egyptian Authority (5)';
      case '8':
        return 'Gulf Region (8)';
      case '9':
        return 'Kuwait (9)';
      case '10':
        return 'Qatar (10)';
      case '12':
        return 'Turkey (12)';
      case '13':
        return 'Morocco (13)';
      case '15':
        return 'Moon Sighting Committee (15)';
      case '16':
        return 'Karachi (16)';
      case '18':
        return 'France (18)';
      case '20':
        return 'Tunisia (20)';
      case '21':
        return 'Algeria (21)';
      default:
        return 'Méthode ($id)';
    }
  }

  Future<_PrayerHeaderData> _loadPrayerHeader() async {
    final location = await LocationService.getSavedOrCurrentLocation();
    final prefs = await SharedPreferences.getInstance();
    final methodRaw = (prefs.getString('prayer_method') ?? '2').trim();
    final method = methodRaw.isEmpty ? '2' : methodRaw;
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
      // précharge la page demandée pour éviter un petit freeze
      final File firstFile = await QuranImageService.getPageFile(selectedReading, page);
      if (!mounted) return;
      await precacheImage(FileImage(firstFile), context);

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


  void _openMenu() {
    if (!_isMenuOpen) {
      setState(() => _isMenuOpen = true);
      _menuController.forward();
    }
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      _menuController.reverse().then((_) {
        setState(() => _isMenuOpen = false);
      });
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    final screenWidth = MediaQuery.of(context).size.width * 0.8;
    
    // Ouvrir le menu si on commence près du bord gauche
    if (_dragStartX < 50 && !_isMenuOpen) {
      setState(() => _isMenuOpen = true);
    }
    // Permettre de glisser le menu si on est déjà dessus
    else if (_isMenuOpen && _dragStartX < screenWidth) {
      // Le menu est ouvert et on touche dessus - on peut le faire glisser
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width * 0.8;
    final currentX = details.globalPosition.dx;
    
    // Calculer la progression: 0 = fermé, 1 = ouvert
    double progress;
    
    if (_isMenuOpen) {
      // Menu déjà ouvert - calculer la progression basée sur la position actuelle
      progress = (currentX / screenWidth).clamp(0.0, 1.0);
    } else if (_dragStartX < 50) {
      // Ouverture depuis le bord gauche
      progress = (currentX / screenWidth).clamp(0.0, 1.0);
    } else {
      // Ignorer les drags qui ne commencent pas près du bord gauche si le menu est fermé
      return;
    }
    
    _menuController.value = progress;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isMenuOpen) return;
    
    // Si plus de 50% ouvert, terminer l'ouverture, sinon fermer
    if (_menuController.value > 0.5) {
      _menuController.forward();
    } else {
      _closeMenu();
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

    // Lancer le lecteur audio avec le récitateur
    _audio.setReciter(r.name, server);

    // Lancer automatiquement la première sourate (Al-Fatiha)
    await _audio.loadPlaylistAndPlay(1);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('▶ ${r.name} - Al-Fatiha'),
        duration: const Duration(seconds: 2),
      ),
    );
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
    : (_statusBarGreen ? const Color(0xFFDDF5E6) : Colors.transparent);

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
            // Vert léger en haut
            Color(0xFFEAF7F0),
            Color(0xFFF1FAF5),

            // Transition douce vers crème
            Color(0xFFFFFBF2),
            Color(0xFFF7F3EA),
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

            CustomScrollView(
              controller: _scrollCtrl,
              physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: hPad),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        // Header
                        _HeaderWithEngagement(
                          audio: _audio,
                          onMenuTap: _openMenu,
                          onThemeTap: _cycleTheme,
                          onContinue: _openSurahListScreen,
                          prayerFuture: _prayerFuture,
                          activeIndexFromTimes: _activeIndexFromTimes,
                          reciters: _reciters,
                          recitersLoading: _recitersLoading,
                          onReciterTap: _onReciterSelected,
                          getReciterAsset: (name) => _reciterAssetsByName[name] ?? '',
                        ),
                        const SizedBox(height: vGap),

                        // Verse of the day
                        const _VerseOfTheDayCard(),
                        const SizedBox(height: vGap),

                        // Video of the day
                        const YoutubeVideoCard(mode: QuranVideoMode.sufi),
                        const SizedBox(height: vGap),

                        // Explore
                        _ExploreFeaturesSection(
                          features: const [
                            _FeatureChipData(label: 'Player', imagePath: 'assets/images/Features/player.webp'),
                            _FeatureChipData(label: 'Duʿa', imagePath: 'assets/images/Features/dua.webp'),
                            _FeatureChipData(label: 'Hadith', imagePath: 'assets/images/Features/hadith.webp'),
                            _FeatureChipData(label: 'Qibla', imagePath: 'assets/images/Features/qibla.webp'),
                            _FeatureChipData(label: 'Adhkar', imagePath: 'assets/images/Features/adhkar.webp'),
                            _FeatureChipData(label: 'Bookmarks', imagePath: 'assets/images/Features/bookmarks.webp'),
                          ],
                          onTap: (f) {
                            final ctx = NavigationService.navigatorKey.currentContext ?? context;
                            if (f.label == 'Player') {
                              _audio.isFullPlayerOpenNotifier.value = true;
                              showModalBottomSheet(
                                context: ctx,
                                useSafeArea: true,
                                useRootNavigator: true,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const FullPlayerScreen(),
                              ).whenComplete(() {
                                _audio.isFullPlayerOpenNotifier.value = false;
                              });
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${f.label} bientôt')),
                            );
                          },
                        ),
                        const SizedBox(height: vGap),

                        // Programs / content cards
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
                            }
                          },
                        ),

                        // Bottom space (mini-player / safe area)
                        SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  return Scaffold(
    body: Stack(
      children: [
        IgnorePointer(
          ignoring: _isMenuOpen,
          child: GestureDetector(
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            child: _isLoading ? loading() : content(),
          ),
        ),
        if (_isMenuOpen)
          AnimatedBuilder(
            animation: _menuAnimation,
            builder: (context, child) {
              final screenWidth = MediaQuery.of(context).size.width * 0.8;
              return GestureDetector(
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: Transform.translate(
                  offset: Offset(-screenWidth + (screenWidth * _menuAnimation.value), 0),
                  child: RepaintBoundary(
                    child: IOSSideMenu(
                      onSettingsClosed: _refreshPrayerHeader,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
 }
}

class _HomeTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onThemeTap;

  const _HomeTopBar({
    required this.onMenuTap,
    required this.onThemeTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu_rounded),
          color: t.colorScheme.onBackground.withOpacity(0.75),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Ø§Ù„Ù‚Ø±Ø¢Ù† Ø§Ù„ÙƒØ±ÙŠÙ…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, mode, _) {
            final icon = (mode == ThemeMode.system)
                ? Icons.brightness_auto_rounded
                : (mode == ThemeMode.light)
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded;

            return IconButton(
              onPressed: onThemeTap,
              icon: Icon(icon),
              color: t.colorScheme.onBackground.withOpacity(0.75),
            );
          },
        ),
      ],
    );
  }
}

class _DribbbleHomeHeader extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onThemeTap;
  final Future<_PrayerHeaderData> prayerFuture;
  final int Function(List<(String, String)>) activeIndexFromTimes;

  const _DribbbleHomeHeader({
    required this.onMenuTap,
    required this.onThemeTap,
    required this.prayerFuture,
    required this.activeIndexFromTimes,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color muted = fg.withOpacity(isDark ? 0.72 : 0.60);
    final Color pillBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.92);
    final Color pillBorder = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
    return FutureBuilder<_PrayerHeaderData>(
      future: prayerFuture,
      builder: (context, snap) {
        final data = snap.data;

        final location = data == null ? 'Paris, France' : '${data.city}, ${data.country}';
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 2,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onMenuTap,
                    icon: Icon(Icons.menu_rounded, color: fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recherche bientôt')),
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: muted, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Rechercher',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.themeMode,
                    builder: (context, mode, _) {
                      final IconData icon = (mode == ThemeMode.system)
                          ? Icons.brightness_auto_rounded
                          : (mode == ThemeMode.light)
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded;
                      final Color color = isDark
                          ? ((mode == ThemeMode.light) ? const Color(0xFFFFD54F) : Colors.white)
                          : const Color(0xFF0F172A);
                      return IconButton(
                        onPressed: onThemeTap,
                        icon: Icon(icon, color: color),
                        tooltip: 'Thème',
                      );
                    },
                  ),
                  _NotificationBellButton(
                    count: 3,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications bientôt')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (snap.connectionState != ConnectionState.done || data == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Chargement des horaires...',
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                  builder: (context, _) {
                    final prayers5 = <(String, String)>[
                      ('Fajr', data.times['Fajr'] ?? '--:--'),
                      ('Dhuhr', data.times['Dhohr'] ?? '--:--'),
                      ('Asr', data.times['Asr'] ?? '--:--'),
                      ('Maghrib', data.times['Maghrib'] ?? '--:--'),
                      ('Isha', data.times['Isha'] ?? '--:--'),
                    ];

                    int nextIndex5 = 0;
                    final now = DateTime.now();
                    DateTime? parseToday(String t) {
                      final parts = t.split(':');
                      if (parts.length < 2) return null;
                      final h = int.tryParse(parts[0]);
                      final m = int.tryParse(parts[1]);
                      if (h == null || m == null) return null;
                      return DateTime(now.year, now.month, now.day, h, m);
                    }

                    for (int i = 0; i < prayers5.length; i++) {
                      final dt = parseToday(prayers5[i].$2);
                      if (dt != null && dt.isAfter(now)) {
                        nextIndex5 = i;
                        break;
                      }
                    }

                    final remaining5 = _DribbbleHomeHeader._remainingToNextPrayer(prayers5, nextIndex5);
                    final nextName = prayers5[nextIndex5].$1;
                    final nextTime = prayers5[nextIndex5].$2;

                    return PrayerTimesCardV2(
                      nextPrayerName: nextName,
                      nextPrayerTime: nextTime,
                      remaining: remaining5,
                      prayers: prayers5,
                      activeIndex: nextIndex5,
                      location: location,
                      onLocationTap: () {
                        (context.findAncestorStateOfType<_HomeScreenState>())?._showLocationPicker();
                      },
                      onExpandTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrayersScreen()),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );

      },
    );
  }

  static IconData _getPrayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_rounded;
      case 'sunrise':
        return Icons.wb_sunny_rounded;
      case 'dhohr':
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.wb_sunny;
      case 'maghrib':
        return Icons.nights_stay_rounded;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }
  
  static Duration _remainingToNextPrayer(List<(String, String)> prayers, int activeIndex) {
    final now = DateTime.now();
    final hhmm = prayers[activeIndex].$2;

    if (!hhmm.contains(':') || hhmm.contains('-')) return Duration.zero;

    final parts = hhmm.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts[1]) ?? 0;

    var next = DateTime(now.year, now.month, now.day, hh, mm);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    return next.difference(now);
  }

  static String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}h '
          '${m.toString().padLeft(2, '0')}m '
          '${s.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

}


class _NotificationBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black.withOpacity(0.78);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(Icons.notifications_none_rounded, color: iconColor),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuranEngagementCard extends StatelessWidget {
  final int minutes;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _QuranEngagementCard({
    required this.minutes,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF0F1734) : Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$minutes minutes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : const Color(0xFF111827)).withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),

            // Bouton
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C6CB5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderWithEngagement extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onThemeTap;
  final VoidCallback onContinue;
  final Future<_PrayerHeaderData> prayerFuture;
  final int Function(List<(String, String)>) activeIndexFromTimes;
  final List<Reciter> reciters;
  final bool recitersLoading;
  final void Function(Reciter) onReciterTap;
  final String Function(String name) getReciterAsset;
  final AudioService audio;





  const _HeaderWithEngagement({
    required this.audio,
    required this.onMenuTap,
    required this.onThemeTap,
    required this.onContinue,
    required this.prayerFuture,
    required this.activeIndexFromTimes,
    required this.reciters,
    required this.recitersLoading,
    required this.onReciterTap,
    required this.getReciterAsset,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header prières
        _DribbbleHomeHeader(
          onMenuTap: onMenuTap,
          onThemeTap: onThemeTap,
          prayerFuture: prayerFuture,
          activeIndexFromTimes: activeIndexFromTimes,
        ),

        const SizedBox(height: 12),

        // Continuer / Reprendre lecture
        const ContinueReadingCard(),

        const SizedBox(height: 12),

        // Reciters
        _HomeCardShell(
          child: recitersLoading
              ? const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _RecitersSection(
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecitersGalleryScreen(reciters: reciters),
                      ),
                    );
                  },
                  reciters: reciters,
                  onReciterTap: onReciterTap,
                  getAssetByName: getReciterAsset,
                ),
        ),
      ],
    );
  }
}


class _RecitersSection extends StatelessWidget {
  final VoidCallback onSeeAll;
  final List<Reciter> reciters;
  final void Function(Reciter) onReciterTap;
  final String Function(String name) getAssetByName;

  const _RecitersSection({
    required this.onSeeAll,
    required this.reciters,
    required this.onReciterTap,
    required this.getAssetByName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    const linkColor = Color(0xFF2C6CB5);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2C3E50),
                  const Color(0xFF1A252F),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFEF5E7),
                  const Color(0xFFFAE5D3),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        // boxShadow supprimé
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reciters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const Spacer(),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: linkColor,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
          ),
          const SizedBox(height: 0),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: reciters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = reciters[i];
                final asset = getAssetByName(r.name);
                return InkWell(
                  onTap: () => onReciterTap(r),
                  borderRadius: BorderRadius.circular(999),
                  child: Column(
                    children: [
                      // Avatar avec ring
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.35)
                                : const Color(0xFF2C6CB5).withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color.fromARGB(255, 255, 251, 243),
                          backgroundImage: asset.isEmpty ? null : AssetImage(asset),
                          onBackgroundImageError: (_, __) {},
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            r.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: titleColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChipData {
  final String label;
  final String imagePath;

  const _FeatureChipData({required this.label, required this.imagePath});
}

class _ExploreFeaturesSection extends StatelessWidget {
  final List<_FeatureChipData> features;
  final void Function(_FeatureChipData) onTap;

  const _ExploreFeaturesSection({
    required this.features,
    required this.onTap,
  });



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore features',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 112,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: features.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = features[i];

                final pastel = <Color>[
                  const Color(0xFFFFF4CC), // jaune pâle
                  const Color(0xFFDFF7E9), // vert pâle
                  const Color(0xFFE3F0FF), // bleu pâle
                  const Color(0xFFFFE3E6), // rouge/rose pâle
                  const Color(0xFFEDE7FF), // violet pâle
                  const Color(0xFFE7FFF7), // menthe pâle
                ];

                return SizedBox(
                  width: 180, // même largeur que Programs
                  height: 112, // même hauteur que Programs
                  child: _FeatureSquareItem(
                    label: f.label,
                    imagePath: f.imagePath,
                    onTap: () => onTap(f),
                    isDark: isDark,
                    bgColor: pastel[i % pastel.length],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


class _FeatureChip extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;

  final VoidCallback onTap;

  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF2F6FF);
    final fg = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF111827);
    const accent = Color(0xFF2C6CB5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 18,
              color: accent,
              duotoneSecondaryOpacity: 0.28,
            ),

            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCardData {
  final String title;
  final String subtitle;
  final String imageAsset;

  const _ContentCardData({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
  });
}

class _ContentCardsSection extends StatelessWidget {
  final List<_ContentCardData> items;
  final void Function(_ContentCardData) onTap;

  const _ContentCardsSection({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Programs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(items.length, (i) {
            final item = items[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: _ContentCard(
                item: item,
                onTap: () => onTap(item),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final _ContentCardData item;
  final VoidCallback onTap;

  const _ContentCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    // Bande et texte lisibles en dark/light
    final Color bannerColor = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.55);

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.65);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 10, // ressemble plus au style "tuile" que 16/9
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                item.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black12),
              ),

              // Léger voile (tu peux le supprimer si tu veux l'image plus "crue")
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.03 : 0.06),
                          Colors.transparent,
                          Colors.black.withOpacity(isDark ? 0.18 : 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bande diagonale translucide
              Align(
                alignment: Alignment.bottomLeft,
                child: ClipPath(
                  clipper: _DiagonalBannerClipper(),
                  child: Container(color: bannerColor),
                ),
              ),

              // Textes (en bas à gauche)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: subTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagonalBannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(0, size.height);
    p.lineTo(0, size.height * 0.55);

    p.quadraticBezierTo(
      size.width * 0.22,
      size.height * 0.62,
      size.width * 0.56,
      size.height * 0.80,
    );

    p.lineTo(size.width, size.height * 0.60);
    p.lineTo(size.width, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _VerseOfTheDayCard extends StatefulWidget {
  const _VerseOfTheDayCard();

  @override
  State<_VerseOfTheDayCard> createState() => _VerseOfTheDayCardState();
}

class _VerseOfTheDayCardState extends State<_VerseOfTheDayCard> {
  String _arabicText = '';
  String _translationText = '';
  int _surahNumber = 1;
  int _verseNumber = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRandomVerse();
  }

  Future<void> _loadRandomVerse() async {
    try {
      // Générer un verset aléatoire basé sur la date du jour
      final today = DateTime.now();
      final seed = today.year * 10000 + today.month * 100 + today.day;
      final random = math.Random(seed);
      
      // Sourate aléatoire (1-114)
      _surahNumber = 1 + random.nextInt(114);
      
      // Essayer d'abord avec le pack offline français
      final isReady = await QuranTranslationPackService.isPackReady(AppLang.fr);
      if (isReady) {
        final dbPath = await QuranTranslationPackService.getDbPath(AppLang.fr);
        final db = await openDatabase(dbPath, readOnly: true);
        
        try {
          // Compter les versets de cette sourate
          final countResult = await db.rawQuery(
            'SELECT COUNT(*) as cnt FROM verses WHERE sura = ?',
            [_surahNumber],
          );
          final versesInSurah = (countResult.first['cnt'] as int?) ?? 0;
          
          if (versesInSurah > 0) {
            _verseNumber = 1 + random.nextInt(versesInSurah);
            
            // Récupérer le verset
            final rows = await db.rawQuery(
              'SELECT ar, fr FROM verses WHERE sura = ? AND aya = ?',
              [_surahNumber, _verseNumber],
            );
            
            if (rows.isNotEmpty) {
              final row = rows.first;
              _arabicText = ((row['ar'] as String?) ?? '')
                  .replaceAll('\u200F', '')
                  .replaceAll('\u200E', '')
                  .trim();
              _translationText = (row['fr'] as String?) ?? '';
              
              await db.close();
              if (!mounted) return;
              setState(() => _isLoading = false);
              return;
            }
          }
        } finally {
          await db.close();
        }
      }
      
      // Fallback: utiliser l'API en ligne si le pack offline n'est pas disponible
      final dio = Dio();
      final arRes = await dio.get('https://api.alquran.cloud/v1/surah/$_surahNumber/quran-uthmani');
      final frRes = await dio.get('https://quranenc.com/api/v1/translation/sura/french_hameedullah/$_surahNumber');
      
      final arAyahs = (arRes.data['data']['ayahs'] as List);
      final frData = (frRes.data['result'] as List);
      
      if (arAyahs.isNotEmpty && frData.isNotEmpty) {
        _verseNumber = 1 + random.nextInt(arAyahs.length);
        
        final arText = arAyahs[_verseNumber - 1]['text']?.toString() ?? '';
        final frText = frData[_verseNumber - 1]['translation']?.toString() ?? '';
        
        _arabicText = arText
            .replaceAll('\u200F', '')
            .replaceAll('\u200E', '')
            .trim();
        _translationText = frText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      // Fallback sur un verset par défaut
      _surahNumber = 2;
      _verseNumber = 286;
      _arabicText = 'لَا يُكَلِّفُ ٱللَّهُ نَفۡسًا إِلَّا وُسۡعَهَاۚ';
      _translationText = 'Allah n\'impose à aucune âme une charge supérieure à sa capacité.';
      
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2C3E50),
                    Color(0xFF1A252F),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFEF5E7),
                    Color(0xFFFAE5D3),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: (isDark ? Colors.black : Colors.orange.shade200).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final surahName = surahFr[_surahNumber] ?? 'Sourate $_surahNumber';
    final arabicColor = isDark ? const Color(0xFFF6E9D7) : const Color(0xFF3D2817);
    final translationColor = isDark ? const Color(0xFFD4C5B0) : const Color(0xFF6B5744);
    const goldColor = Color(0xFFA67C52);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C3E50),
                  Color(0xFF1A252F),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFEF5E7),
                  Color(0xFFFAE5D3),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        // boxShadow supprimé
      ),
      child: Column(
        children: [
          // Verset en arabe
          Text(
            _arabicText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: 18,
              color: arabicColor,
              height: 1.8,
            ),
          ),

          const SizedBox(height: 10),

          // Traduction française
          Text(
            _translationText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: translationColor,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 8),

          // Référence simple
          Text(
            '$surahName $_surahNumber:$_verseNumber',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: goldColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCardShell extends StatelessWidget {
  final Widget child;
  const _HomeCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return Material(
      color: isDark ? const Color(0xFF0F1734) : Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MoshafOption {
  final int id;
  final String name;
  final String server;
  final int surahTotal;

  const _MoshafOption({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
  });
}


class _PrayerHeaderData {
  final String city;
  final String country;
  final String hijriLine;
  final Map<String, String> times;
  final String methodLabel;

  const _PrayerHeaderData({
    required this.city,
    required this.country,
    required this.hijriLine,
    required this.times,
    required this.methodLabel,
  });

  factory _PrayerHeaderData.error({required String city, required String country}) {
    return _PrayerHeaderData(
      city: city,
      country: country,
      hijriLine: '',
      times: const {},
      methodLabel: '',
    );
  }
}


class _FeatureSquareItem extends StatelessWidget {
  final String label;
  final String imagePath;
  final VoidCallback onTap;
  final bool isDark;
  final Color bgColor;

  const _FeatureSquareItem({
    required this.label,
    required this.imagePath,
    required this.onTap,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color labelColor = isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF374151);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black12,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: labelColor,
                      ),
                    );
                  },
                ),
              ),
              // Voile léger comme Programs
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.03 : 0.06),
                          Colors.transparent,
                          Colors.black.withOpacity(isDark ? 0.18 : 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bande diagonale translucide en bas à gauche (collée en bas)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: _DiagonalBannerClipper(),
                  child: Container(
                    height: 60, // bande encore plus large
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : Colors.white.withOpacity(0.55),
                  ),
                ),
              ),
              // Titre bien en bas à gauche sur la bande
              Positioned(
                left: 14,
                bottom: 4,
                right: 16,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

