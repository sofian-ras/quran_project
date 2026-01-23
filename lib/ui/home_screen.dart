import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import 'reader_screen.dart';
import 'widgets/surah_card.dart';
import 'widgets/mini_audio_player.dart';
import '../surah_name.dart';
import 'full_player_screen.dart';
import 'widgets/reciter_selector.dart';

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
  final Set<int> _favorites = {};
  Map<String, dynamic>? _currentSurah;

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  // --- LOGIQUE POUR CHOISIR LE RÉCITANT ---
  void _showReciterPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B3D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => ReciterSelectorSheet(
        onSelected: (name, server) {
          setState(() {
            _audio.setReciter(name, server);
          });
          // Si une sourate était en cours de lecture, la relancer avec le nouveau récitateur
          if (_currentSurah != null) {
            _startSurahAudio(_currentSurah!);
          }
        },
      ),
    );
  }

  void _startSurahAudio(Map<String, dynamic> s) {
    setState(() {
      _currentSurah = s;
    });
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = prefs.getStringList('favorites') ?? [];
      setState(() {
        _favorites.addAll(favs.map((e) => int.tryParse(e)).whereType<int>());
      });
    } catch (_) {}
  }

  void _openReader(int page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(initialPage: page)),
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
                          reciterName: _audio.currentReciterName,
                          onReciterTap: _showReciterPicker,
                        ),
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
                                return SurahCard(
                                  id: s['id'],
                                  nameAr: s['nameAr'],
                                  nameFr: s['nameFr'],
                                  ayahCount: s['ayahCount'],
                                  isFavorite: _favorites.contains(s['id']),
                                  isPlaying: s['id'] == currentPlayingId, // Nouvel état
                                  onTap: () => _openReader(s['page']),
                                  onPlay: () => _startSurahAudio(s),
                                  onToggleFavorite: () async {
                                    setState(() {
                                      _favorites.contains(s['id']) ? _favorites.remove(s['id']) : _favorites.add(s['id']);
                                    });
                                    final prefs = await SharedPreferences.getInstance();
                                    prefs.setStringList('favorites', _favorites.map((e) => e.toString()).toList());
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
  final String reciterName;
  final VoidCallback onReciterTap;

  const _HomeHeader({
    required this.controller,
    required this.onChanged,
    required this.reciterName,
    required this.onReciterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0B3D2E), Color(0xFF2E8B57)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bouton Récitant
              InkWell(
                onTap: onReciterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Color(0xFFC8A165), size: 16),
                      const SizedBox(width: 8),
                      Text(reciterName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const Text(
                'الْقُرْآنُ الْكَرِيمُ',
                style: TextStyle(fontFamily: 'Scheherazade', fontSize: 28, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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