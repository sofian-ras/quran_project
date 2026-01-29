import 'dart:convert';

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






class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final AudioService _audio = AudioService.instance;
  List<Map<String, dynamic>> fullSurahList = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> filteredList = [];
  String _preferredReading = 'hafs';
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>(<int>{});


  
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

    // précharge la page demandée pour éviter un petit freeze
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




  @override
  Widget build(BuildContext context) {
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
                                        onMenuTap: _openMenu,
                                        onThemeTap: _cycleTheme,
                                        onContinue: _openSurahListScreen, // temporaire
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverToBoxAdapter(
                                        child: _ExploreFeaturesSection(
                                          features: const [
                                            _FeatureChipData(label: 'Weekly Programs', icon: Icons.calendar_month_rounded),
                                            _FeatureChipData(label: 'Donate', icon: Icons.volunteer_activism_rounded),
                                            _FeatureChipData(label: 'Volunteers', icon: Icons.groups_rounded),
                                          ],
                                          onTap: (f) {
                                            // Étape suivante: navigation vers tes écrans
                                          },
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

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
                        StreamBuilder<bool>(
                          stream: _audio.isActiveStream,
                          builder: (context, snapshot) {
                            final bool isActive = snapshot.data ?? false;
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              bottom: isActive ? 0 : -150,
                              left: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const FullPlayerScreen(),
                                  );
                                },
                                child: const MiniAudioPlayer(),
                              ),
                            );
                          },
                        ),
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

  @override
  Widget build(BuildContext context) {
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
            child: Image.asset(
              'assets/images/fond_widget_bleu2.png',
              fit: BoxFit.cover,
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
                    const Color(0xFF2C6CB5).withOpacity(0.88),
                    const Color(0xFF1F5FAE).withOpacity(0.86),
                    const Color(0xFF174F9B).withOpacity(0.88),
                  ],
                ),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
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
                    IconButton(
                      onPressed: onThemeTap,
                      icon: const Icon(Icons.brightness_6_rounded, color: Colors.white),
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

                const SizedBox(height: 12),

                // Mini-card Hijri + location (à droite)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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

                const SizedBox(height: 14),

                // Pills prières (TOUTES visibles sans scroll)
                SizedBox(
                  height: 64,
                  child: Row(
                    children: List.generate(prayers.length, (i) {
                      final isActive = i == activeIndex;
                      final name = prayers[i].$1;
                      final hour = prayers[i].$2;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == prayers.length - 1 ? 0 : 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withOpacity(0.22)
                                  : Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    hour,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
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

  const _HeaderWithEngagement({
    required this.onMenuTap,
    required this.onThemeTap,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 320;

    // Position carte engagement
    const double engagementTop = headerHeight - 40;
    const double engagementHeightApprox = 76;

    // Position carte reciters (elle chevauche la carte engagement)
    const double recitersTop = engagementTop + 36;

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
              child: _RecitersSection(
                onSeeAll: () {},
                reciters: const [
                  _ReciterItem(name: 'Maher', asset: 'assets/images/reciters/maher.png'),
                  _ReciterItem(name: 'Mishari', asset: 'assets/images/reciters/mishari.png'),
                  _ReciterItem(name: 'Minshawi', asset: 'assets/images/reciters/minshawi.png'),
                  _ReciterItem(name: 'Husary', asset: 'assets/images/reciters/husary.png'),
                  _ReciterItem(name: 'Sudais', asset: 'assets/images/reciters/sudais.png'),
                ],
                onReciterTap: (r) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterItem {
  final String name;
  final String asset;
  const _ReciterItem({required this.name, required this.asset});
}

class _RecitersSection extends StatelessWidget {
  final VoidCallback onSeeAll;
  final List<_ReciterItem> reciters;
  final void Function(_ReciterItem) onReciterTap;

  const _RecitersSection({
    required this.onSeeAll,
    required this.reciters,
    required this.onReciterTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final linkColor = const Color(0xFF2C6CB5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reciters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: linkColor,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: reciters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final r = reciters[i];
              return InkWell(
                onTap: () => onReciterTap(r),
                borderRadius: BorderRadius.circular(999),
                child: Column(
                  children: [
                    // Avatar avec ring
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.35)
                              : const Color(0xFF2C6CB5).withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFF3F6FF),
                        backgroundImage: AssetImage(r.asset),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          r.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
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
    );
  }
}

class _FeatureChipData {
  final String label;
  final IconData icon;
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.0, // cases larges comme l’image
          ),
          itemBuilder: (context, i) {
            final f = features[i];
            return _FeatureGridItem(
              label: f.label,
              icon: f.icon,
              onTap: () => onTap(f),
              bgColor: cardColor,
            );
          },
        ),
      ],
    );
  }
}

class _FeatureGridItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color bgColor;

  const _FeatureGridItem({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2C6CB5);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white.withOpacity(0.92) : const Color(0xFF111827);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: textColor,
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


class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
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
            Icon(icon, size: 18, color: accent),
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

