import 'dart:convert';
import 'dart:io';
import '../services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/quran_image_service.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../services/reading_history_service.dart';
import '../surah_name.dart';
import 'full_player_screen.dart';
import 'reader_screen.dart';
import 'screens/quran_loader.dart';
import 'surah_list_screen.dart';
import 'widgets/home_french_quran_widget.dart';
import 'widgets/home_reciter_widget.dart';
import 'widgets/home_resume_reading_widget.dart';
import 'widgets/ios_side_menu.dart';
import 'widgets/liste_de_sourates_widget.dart';
import 'widgets/mini_audio_player.dart';
import '../theme/theme_service.dart';
import 'widgets/prayer_times_card.dart';
import '../models/reciter.dart';
import 'package:dio/dio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';









class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

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

    return type.isEmpty ? riwaya : '$riwaya • $type';
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
  final Map<String, String> _serverByName = {};
  final Map<String, List<_MoshafOption>> _moshafByName = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> filteredList = [];
  String _preferredReading = 'hafs';
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>(<int>{});
  List<Reciter> _reciters = [];
  bool _recitersLoading = true;
  final Map<String, String> _reciterAssetsByName = {};
  final Dio _dio = Dio();
  bool _serversLoading = false;

  
  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  bool _isMenuOpen = false;
  double _dragStartX = 0;

  

@override
void initState() {
  super.initState();
  _loadSurahData();
  _loadPreferredReading();
  _loadFavorites();

  _loadReciters();
  _loadReciterServersIfNeeded();

  _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  _menuAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic),
  );
}


  @override
  void dispose() {
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
      _reciterAssetsByName.clear();

      for (final e in data) {
        final m = e as Map<String, dynamic>;
        final name = (m['name'] ?? '').toString().trim();
        final asset = (m['asset'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        // ✅ Ton JSON n’a pas id/server/letter → on crée Reciter à la main
        list.add(Reciter(
          id: '',
          name: name,
          server: '', // sera résolu via API mp3quran au tap
          letter: '',
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _recitersLoading = false);
    }
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
                  'Choisir la riwāya',
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
      final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=fr");
      final reciters = (res.data['reciters'] as List?) ?? const [];

      for (final item in reciters) {
        final r = item as Map<String, dynamic>;
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
            server: server.endsWith('/') ? server : '$server/',
            surahTotal: total,
          ));
        }

        if (options.isNotEmpty) {
          _moshafByName[_normName(name)] = options;
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

    final options = _moshafByName[_normName(r.name)] ?? const [];

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune riwāya trouvée pour ${r.name}')),
      );
      return;
    }

    _MoshafOption? selected;
    if (options.length == 1) {
      selected = options.first;
    } else {
      selected = await _pickMoshaf(r.name, options);
    }

    if (selected == null) return;

    final displayName = '${r.name} (${_prettyMoshafName(selected.name)})';
    _audio.setReciter(displayName, selected.server);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Réciteur: $displayName')),
    );
  }


    
  Future<String?> _resolveServerForReciter(String reciterName) async {
    try {
      final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=fr");
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    super.build(context);

    return Scaffold(
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isMenuOpen,
            child: GestureDetector(
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: _isLoading
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFF5F7FA),
                            Color(0xFFE8EEF7),
                            Color(0xFFDBE4F0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFFFFF)),
                      ),
                    )
                  : Stack(
                      children: [
                        // FOND DÉGRADÉ EN BAS (AJOUT)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 180,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(30),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    const Color(0xFF4169E1).withOpacity(0.25), // bleu roi
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Contenu principal
                       Positioned.fill(
                        top: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: Theme.of(context).brightness == Brightness.dark
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
                                      Color(0xFFFFFFFF), // blanc lumineux
                                      Color(0xFFF9FBFF), // blanc bleuté léger
                                      Color(0xFFF2F6FF), // blanc froid doux
                                    ],
                                    stops: [0.0, 0.6, 1.0],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.15,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, -8),
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // ✨ effet lumière subtil
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.04),
                                          Colors.transparent,
                                          const Color(0xFFFFFFFF).withOpacity(0.02),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // TON CONTENU EXISTANT
                              SafeArea(
                                top: true,
                                child: CustomScrollView(
                                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: _HeaderWithEngagement(
                                        audio: _audio,
                                        onMenuTap: _openMenu,
                                        onThemeTap: _cycleTheme,
                                        onContinue: _openSurahListScreen,
                                        reciters: _reciters,
                                        recitersLoading: _recitersLoading,
                                        onReciterTap: _onReciterSelected,
                                        getReciterAsset: (name) => _reciterAssetsByName[name] ?? '',
                                      ),
                                    ),



                                    const SliverToBoxAdapter(child: SizedBox(height: 0)),

                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverToBoxAdapter(
                                        child: Transform.translate(
                                          offset: const Offset(0, -40),
                                          child: _ExploreFeaturesSection(
                                            features: const [
                                              _FeatureChipData(label: 'Player', icon: PhosphorIconsDuotone.playCircle),
                                              _FeatureChipData(label: 'Duʿa', icon: PhosphorIconsDuotone.handsPraying),
                                              _FeatureChipData(label: 'Hadith', icon: PhosphorIconsDuotone.bookOpenText),
                                              _FeatureChipData(label: 'Qibla', icon: PhosphorIconsDuotone.compassRose),
                                              _FeatureChipData(label: 'Adhkar', icon: PhosphorIconsDuotone.moonStars),
                                              _FeatureChipData(label: 'Bookmarks', icon: PhosphorIconsDuotone.bookmarkSimple),
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
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                                    // === ICI tu ajoutes les cards image ===
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverToBoxAdapter(
                                        child: _ContentCardsSection(
                                          items: const [
                                            _ContentCardData(
                                              title: 'Boys Quran Class',
                                              subtitle: 'Start at 9:00 AM',
                                              imageAsset: 'assets/images/cards/quran_class.jpg',
                                            ),
                                            _ContentCardData(
                                              title: 'Tafsir Session',
                                              subtitle: 'Tonight • 20:30',
                                              imageAsset: 'assets/images/cards/tafsir.jpg',
                                            ),
                                          ],
                                          onTap: (item) {},
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverToBoxAdapter(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _HomeCardShell(
                                                child: ResumeReadingWidget(
                                                  onTap: (page, reading) => _openReader(page, reading: reading),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: _HomeCardShell(
                                                child: FrenchQuranWidget(),
                                              ),
                                            ),
                                          ],
                                        ),

                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                                    // IMPORTANT: padding bas pour ne pas être caché par MiniAudioPlayer
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        170 + MediaQuery.of(context).padding.bottom, // marge mini player
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: ListeDeSouratesWidget(
                                          surahCount: filteredList.length,
                                          onTap: _openSurahListScreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                        // Mini lecteur audio
                        
                      ],
                    ),
            ),
          ),

          // Menu latéral qui suit le doigt
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
                    offset: Offset(
                      -screenWidth + (screenWidth * _menuAnimation.value),
                      0,
                    ),
                    child: const RepaintBoundary(
                      child: IOSSideMenu(),
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
            'القرآن الكريم',
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

  const _DribbbleHomeHeader({
    required this.onMenuTap,
    required this.onThemeTap,
  });

  IconData _prayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_rounded; // lever de soleil
      case 'sunrise':
        return Icons.wb_sunny_rounded;
      case 'zohr':
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.wb_sunny_rounded;
      case 'maghrib':
        return Icons.nights_stay_rounded; // coucher / nuit
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Valeurs en dur (étape 1)
    const timeText = '3:00 PM';
    const subtitle = 'Zohr ends in 0h 17m 20s';
    const hijri = "Dhu’l-Qi’dah 5, 1446 AH";
    const location = 'Paris, France';

    final prayers = const [
      ('Fajr', '5:53 AM'),
      ('Sunrise', '5:15 AM'),
      ('Zohr', '11:49 AM'),
      ('Asr', '3:18 PM'),
      ('Maghrib', '6:24 PM'),
      ('Isha', '7:45 PM'),
    ];

    const activeIndex = 3; // Asr sélectionnée (exemple)

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: isDark
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.35),
                      BlendMode.darken,
                    ),
                    child: Image.asset(
                      'assets/images/fond_widget_bleu2.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/images/fond_widget_bleu2.png',
                    fit: BoxFit.cover,
                  ),
          ),
          if (isDark)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
              ),
            ),

          // Overlay gradient (pour garder le style + lisibilité du texte)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2C6CB5).withOpacity(isDark ? 0.92 : 0.88),
                    const Color(0xFF1F5FAE).withOpacity(isDark ? 0.90 : 0.86),
                    const Color(0xFF174F9B).withOpacity(isDark ? 0.92 : 0.88),
                  ],
                ),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 2,
              left: 16,
              right: 16,
              bottom: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: menu + titre + theme
                Row(
                  children: [
                    IconButton(
                      onPressed: onMenuTap,
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Home',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.themeMode,
                      builder: (context, mode, _) {
                        final IconData icon = (mode == ThemeMode.system)
                            ? Icons.brightness_auto_rounded
                            : (mode == ThemeMode.light)
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded;
                        final Color color = (mode == ThemeMode.light)
                            ? const Color(0xFFFFD54F)
                            : Colors.white;
                        return IconButton(
                          onPressed: onThemeTap,
                          icon: Icon(icon, color: color),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Heure + sous-titre
                const Text(
                  timeText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 1),

                // Mini-card Hijri + location (à droite)
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hijri,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_rounded, size: 14, color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),


                const SizedBox(height: 8),

                // Pills prières (TOUTES visibles sans scroll)
                SizedBox(
                  height: 80,
                  child: Row(
                    children: List.generate(prayers.length, (i) {
                      final isActive = i == activeIndex;
                      final name = prayers[i].$1;
                      final hour = prayers[i].$2;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == prayers.length - 1 ? 0 : 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // ✅ ICI l’icône entre le nom et l’heure
                                Icon(
                                  _prayerIcon(name),
                                  size: 20,
                                  color: Colors.white.withOpacity(0.92),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    hour,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
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
    required this.reciters,
    required this.recitersLoading,
    required this.onReciterTap,
    required this.getReciterAsset,
  });


  @override
  Widget build(BuildContext context) {
    const double headerHeight = 320;

    // Position carte engagement
    const double engagementTop = headerHeight - 40;
    const double engagementHeightApprox = 76;

    // Position carte reciters (elle chevauche la carte engagement)
    const double recitersTop = engagementTop + 60;

    return SizedBox(
      height: headerHeight + 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: headerHeight,
            child: _DribbbleHomeHeader(
              onMenuTap: onMenuTap,
              onThemeTap: onThemeTap,
            ),
          ),

          // === Carte Quran engagement ===
          Positioned(
            left: 16,
            right: 16,
            top: engagementTop,
            child: _QuranEngagementCard(
              minutes: 15,
              subtitle: 'Quran engagement time',
              buttonText: 'Continue',
              onPressed: onContinue,
            ),
          ),

          // === Carte Reciters (AU-DESSUS) ===
          Positioned(
            left: 16,
            right: 16,
            top: recitersTop,
            child: _HomeCardShell(
              child: recitersLoading
                  ? const SizedBox(
                      height: 64,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _RecitersSection(
                      onSeeAll: () {},
                      reciters: reciters,
                      onReciterTap: onReciterTap,
                      getAssetByName: getReciterAsset,
                    ),
            ),
          ),
        ],
      ),
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
    final linkColor = const Color(0xFF2C6CB5);

    return Padding(
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
                              : const Color(0xFFF3F6FF),
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
  final PhosphorIconData icon;

  const _FeatureChipData({required this.label, required this.icon});
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
    final cardColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF2F6FF);

    return Column(
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
        SizedBox(
          height: 104,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            scrollDirection: Axis.horizontal,
            itemCount: features.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, i) {
              final f = features[i];
              return _FeatureIconItem(
                label: f.label,
                icon: f.icon,
                onTap: () => onTap(f),
                isDark: isDark,
              );
            },
          ),
        ),

      ],
    );
  }
}

class _FeatureIconItem extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _FeatureIconItem({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              icon,
              size: 32,
              color: textColor,
              duotoneSecondaryOpacity: 0.28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F1734) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Material(
      color: cardColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                item.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor.withOpacity(0.65),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C6CB5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF2C6CB5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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


