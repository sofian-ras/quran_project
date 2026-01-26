import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../services/reading_history_service.dart';
import '../services/daily_verse_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import 'widgets/surah_card.dart';
import 'widgets/mini_audio_player.dart';
import 'widgets/reciter_selector.dart';
import '../surah_name.dart';
import 'full_player_screen.dart';
import 'widgets/ios_side_menu.dart';
import 'screens/quran_loader.dart';
import 'reader_screen.dart';

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
  bool _favoritesLoaded = false;


  
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
      final id = v['surah'] as int;
      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
      startPage[id] = startPage[id] ?? (v['page'] ?? 1);
    }

    for (final id in ayahCounts.keys) {
      list.add({
        'id': id,
        'nameAr': quranData.firstWhere((e) => e['surah'] == id)['sura_name'] ?? 'Sourate $id',
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
      _favoritesLoaded = true;
    });
  }


  void _showReadingSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choisir la lecture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Hafs'),
                trailing: _preferredReading == 'hafs' ? const Icon(Icons.check, color: Color(0xFF2E7D32)) : null,
                onTap: () async {
                  await ReadingHistoryService.instance.setPreferredReading('hafs');
                  if (mounted) setState(() => _preferredReading = 'hafs');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Warsh'),
                trailing: _preferredReading == 'warsh' ? const Icon(Icons.check, color: Color(0xFF2E7D32)) : null,
                onTap: () async {
                  await ReadingHistoryService.instance.setPreferredReading('warsh');
                  if (mounted) setState(() => _preferredReading = 'warsh');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openReader(int page, {String? reading}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            initialPage: page,
            reading: reading ?? _preferredReading,
          ),
        ),
      );
    });
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
                          colors: [Color(0xFFF5F7FA), Color(0xFFE8EEF7), Color(0xFFDBE4F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                    )
                  : Stack(
                      children: [
                        // Header en arrière-plan
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _HomeHeader(
                            onMenuTap: _openMenu,
                            reading: _preferredReading,
                            onReadingTap: _showReadingSelector,
                          ),
                        ),
                        
                        // Contenu principal avec overlap
                        Positioned.fill(
                          top: 120, // Ajuster selon la hauteur du header
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF5F7FA), Color(0xFFE8EEF7), Color(0xFFDBE4F0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, -5),
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  
                                  // Widget Récitateur
                                  _ReciterWidget(),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Widgets actions rapides
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _ResumeReadingWidget(
                                                  onTap: (page, reading) => _openReader(page, reading: reading),
                                                 ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _FrenchQuranWidget(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Liste scrollable des sourates
                                  Expanded(
                                    child: ListView.builder(
                                      key: const PageStorageKey('surah_list'),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final s = filteredList[index];
                                        final int surahId = s['id'];

                                        return _SurahPlayingTile(
                                          surahId: surahId,
                                          childBuilder: (isPlaying) => ValueListenableBuilder<Set<int>>(
                                            valueListenable: _favoriteIdsNotifier,
                                            builder: (context, favs, _) {
                                              return SurahCard(
                                                id: surahId,
                                                nameAr: s['nameAr'],
                                                nameFr: s['nameFr'],
                                                ayahCount: s['ayahCount'],
                                                isFavorite: _favoritesLoaded ? favs.contains(surahId) : false,
                                                isPlaying: isPlaying,
                                                onTap: () => _openReader(s['page']),
                                                onPlay: () => _startSurahAudio(s),
                                                onToggleFavorite: () async {
                                                  final isNowFavorite = await FavoritesService.instance.toggleFavorite(surahId);
                                                  if (!mounted) return;

                                                  final next = Set<int>.from(_favoriteIdsNotifier.value);
                                                  if (isNowFavorite) {
                                                    next.add(surahId);
                                                  } else {
                                                    next.remove(surahId);
                                                  }
                                                  _favoriteIdsNotifier.value = next;
                                                },
                                              );
                                            },
                                          ),

                                        );
                                      },
                                    ),
                                  ),

                                ],
                              ),
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
                    child: const IOSSideMenu(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------- HEADER MODIFIÉ ----------------
class _HomeHeader extends StatelessWidget {
  final VoidCallback onMenuTap;
  final String reading;
  final VoidCallback onReadingTap;

  const _HomeHeader({
    required this.onMenuTap,
    required this.reading,
    required this.onReadingTap,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/quran_header_mobile.webp'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16213e).withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bouton Menu iOS
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onMenuTap,
                  child: const Icon(
                    Icons.dehaze,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                // Badge Hafs/Warsh (à droite)
                GestureDetector(
                  onTap: onReadingTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                    ),
                    child: Text(
                      reading == 'warsh' ? 'Warsh' : 'Hafs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

// Widget Récitateur
class _ReciterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AudioService audio = AudioService.instance;
    
    return Stack(
      children: [
        // Container principal avec décorations
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a0033), Color(0xFF2d1b4e), Color(0xFF4a1c6f)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4a1c6f).withOpacity(0.6),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image et nom du récitateur
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: audio.currentReciterNotifier,
                  builder: (context, reciterName, _) {
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ReciterSelectorSheet(
                            onSelected: (name, server) {
                              audio.setReciter(name, server);
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          // Avatar du récitateur
                          const Icon(
                            Icons.person,
                            color: Color(0xFFD4AF37),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          
                          // Nom du récitateur
                          Expanded(
                            child: Text(
                              reciterName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Bouton Play
              StreamBuilder<PlayerState>(
                stream: audio.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  
                  return InkWell(
                    onTap: () {
                      if (isPlaying) {
                        audio.pause();
                      } else {
                        // Si rien n'est en cours, lancer la première sourate
                        if (audio.currentSurahId == null) {
                          audio.loadPlaylistAndPlay(1);
                        } else {
                          audio.play();
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFFD4AF37),
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Traits dorés décoratifs au milieu du widget
        // Côté gauche/centre
        Positioned(
          top: 15,
          left: 25,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.0),
                    const Color(0xFFD4AF37).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          top: 28,
          left: 32,
          child: Transform.rotate(
            angle: -0.3,
            child: Container(
              width: 30,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.0),
                    const Color(0xFFD4AF37).withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 35,
          left: 60,
          child: Transform.rotate(
            angle: 0.4,
            child: Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.7),
                    const Color(0xFFD4AF37).withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        
        // Côté bas/centre
        Positioned(
          bottom: 15,
          left: 25,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.0),
                    const Color(0xFFD4AF37).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 28,
          left: 30,
          child: Transform.rotate(
            angle: 0.3,
            child: Container(
              width: 35,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.0),
                    const Color(0xFFD4AF37).withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 35,
          left: 55,
          child: Transform.rotate(
            angle: -0.5,
            child: Container(
              width: 45,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.8),
                    const Color(0xFFD4AF37).withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        
        // Points et ornements dorés au centre
        Positioned(
          top: 25,
          left: 20,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 50,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 25,
          left: 22,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 65,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 80,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 45,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// Widget Citation du jour
class _DailyVerseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyVerse>(
      future: DailyVerseService.instance.getDailyVerse(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final verse = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0f0f0f), Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16213e).withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.9), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Citation du jour',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                verse.arabic,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.8,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                verse.french,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${verse.surahName} (${verse.surahNumber}:${verse.verseNumber})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget Reprendre la lecture (compact)
class _ResumeReadingWidget extends StatelessWidget {
  final void Function(int page, String reading) onTap;
  
  const _ResumeReadingWidget({required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ReadingHistoryService.instance.getLastReading(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        final lastReading = snapshot.data!;
        final page = lastReading['page'] as int;
        final surahName = lastReading['surahName'] as String;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a0033),
                const Color(0xFF2d1b4e),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onTap(page, (lastReading['reading'] as String?) ?? 'hafs'),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: const Color(0xFFD4AF37),
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reprendre',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFD4AF37).withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      surahName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget Coran en français
class _FrenchQuranWidget extends StatelessWidget {
  const _FrenchQuranWidget();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Image en arrière-plan
            Positioned.fill(
              child: Image.asset(
                'assets/icon/logo_coran.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1a0033),
                  );
                },
              ),
            ),
            // Overlay gradient semi-transparent
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF5F7FA).withOpacity(0.9),
                      const Color(0xFFE8EEF7).withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Contenu
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  // TODO: Ouvrir la fenêtre Coran en français
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Coran en français',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF1a0033),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SurahPlayingTile extends StatefulWidget {
  final int surahId;
  final Widget Function(bool isPlaying) childBuilder;

  const _SurahPlayingTile({
    required this.surahId,
    required this.childBuilder,
  });

  @override
  State<_SurahPlayingTile> createState() => _SurahPlayingTileState();
}

class _SurahPlayingTileState extends State<_SurahPlayingTile> {
  late final AudioService _audio;
  late bool _isPlaying;

  void _handlePlayingChanged() {
    final current = _audio.currentPlayingSurahIdNotifier.value;
    final shouldBePlaying = current == widget.surahId;
    if (_isPlaying != shouldBePlaying) {
      setState(() => _isPlaying = shouldBePlaying);
    }
  }

  @override
  void initState() {
    super.initState();
    _audio = AudioService.instance;
    _isPlaying = _audio.currentPlayingSurahIdNotifier.value == widget.surahId;
    _audio.currentPlayingSurahIdNotifier.addListener(_handlePlayingChanged);
  }

  @override
  void dispose() {
    _audio.currentPlayingSurahIdNotifier.removeListener(_handlePlayingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.childBuilder(_isPlaying);
  }
}
