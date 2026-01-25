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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AudioService _audio = AudioService.instance;
  List<Map<String, dynamic>> fullSurahList = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> filteredList = [];

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  @override
  void dispose() {
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

  void _openReader(int page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuranLoader(initialPage: page)),
    );
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE8EEF7), Color(0xFFDBE4F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('home_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          onMenuTap: () {
                            showGeneralDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: 'Menu',
                              barrierColor: Colors.black54,
                              transitionDuration: const Duration(milliseconds: 300),
                              pageBuilder: (context, anim1, anim2) => const IOSSideMenu(),
                              transitionBuilder: (context, anim1, anim2, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(-1, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: anim1,
                                    curve: Curves.easeOutCubic,
                                  )),
                                  child: child,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Widget Récitateur
                        _ReciterWidget(),
                        
                        const SizedBox(height: 16),
                        
                        // Widgets actions rapides
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ResumeReadingWidget(onTap: _openReader),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _FrenchQuranWidget(),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Toutes les sourates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        // 2. UI/UX : StreamBuilder pour mettre à jour l'UI quand la sourate change
                        StreamBuilder<int?>(
                          stream: _audio.currentIndexStream,
                          builder: (context, snapshot) {
                            final currentPlayingId = (snapshot.data ?? -1) + 1;
                            
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final s = filteredList[index];
                                return FutureBuilder<bool>(
                                  future: FavoritesService.instance.isFavorite(s['id']),
                                  builder: (context, favoriteSnapshot) {
                                    return SurahCard(
                                      id: s['id'],
                                      nameAr: s['nameAr'],
                                      nameFr: s['nameFr'],
                                      ayahCount: s['ayahCount'],
                                      isFavorite: favoriteSnapshot.data ?? false,
                                      isPlaying: s['id'] == currentPlayingId,
                                      onTap: () => _openReader(s['page']),
                                      onPlay: () => _startSurahAudio(s),
                                      onToggleFavorite: () async {
                                        await FavoritesService.instance.toggleFavorite(s['id']);
                                        setState(() {}); // Rafraîchir l'UI
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          }
                        ),
                         const SizedBox(height: 150), // Espace pour le mini-lecteur
                      ],
                    ),
                  ),
                ),
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
    );
  }
}

// ---------------- HEADER MODIFIÉ ----------------
class _HomeHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _HomeHeader({
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.variant1,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
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
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const Text(
                'الْقُرْآنُ الْكَرِيمُ',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
  final Function(int) onTap;
  
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
              onTap: () => onTap(page),
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
