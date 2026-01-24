import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/reading_history_service.dart';
import '../services/daily_verse_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import 'widgets/surah_card.dart';
import 'widgets/mini_audio_player.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  void _onSearchChanged(String q) {
    final qLower = q.trim().toLowerCase();
    setState(() {
      if (qLower.isEmpty) {
        filteredList = List.from(fullSurahList);
      } else {
        filteredList = fullSurahList.where((s) {
          return s['nameAr'].toLowerCase().contains(qLower) ||
              s['nameFr'].toLowerCase().contains(qLower) ||
              s['id'].toString() == qLower;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('home_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
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
                        
                        // Citation du jour
                        _DailyVerseWidget(),
                        
                        const SizedBox(height: 16),
                        
                        // Reprendre la lecture
                        _ResumeReadingWidget(onTap: _openReader),
                        
                        const SizedBox(height: 16),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('En vedette', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              TextButton(onPressed: () {}, child: const Text('Voir tout')),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            key: const PageStorageKey('featured_list'),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,
                            itemCount: filteredList.length > 8 ? 8 : filteredList.length,
                            itemBuilder: (context, index) {
                              final s = filteredList[index];
                              return GestureDetector(
                                onTap: () => _openReader(s['page']),
                                child: Container(
                                  width: 240,
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(s['nameAr'], style: const TextStyle(fontFamily: 'Amiri', fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          IconButton(icon: const Icon(Icons.play_circle_fill, color: Color(0xFF0B3D2E)), onPressed: () => _startSurahAudio(s)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(s['nameFr'], style: const TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
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
    );
  }
}

// ---------------- HEADER MODIFIÉ ----------------
class _HomeHeader extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onMenuTap;

  const _HomeHeader({
    required this.controller,
    required this.onChanged,
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
            color: AppColors.primary.withOpacity(0.4),
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
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                hintText: 'Rechercher une sourate...',
              ),
            ),
          ),
        ],
      ),
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
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
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

// Widget Reprendre la lecture
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
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onTap(page),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bookmark,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reprendre la lecture',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            surahName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Page $page',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
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
