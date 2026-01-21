import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart'; // <--- Import du service
import 'reader_screen.dart';
import 'widgets/surah_card.dart';
import 'widgets/bottom_audio_bar.dart';
import '../surah_name.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AudioService _audio = AudioService.instance; // <--- Instance du service
  List<Map<String, dynamic>> fullSurahList = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> filteredList = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  // --- NOUVELLE MÉTHODE POUR L'AUDIO ---
  void _startSurahAudio(Map<String, dynamic> s) async {
    final String idStr = s['id'].toString().padLeft(3, '0');
    final String url = "https://server8.mp3quran.net/afs/$idStr.mp3";
    _audio.currentTitle = s['nameFr'];
    await _audio.setUrl(url);
    _audio.play();
    if (mounted) setState(() {}); // Rafraîchit l'UI pour la BottomBar
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
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialPage: page),
      ),
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
          : IndexedStack(
              index: 0,
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('home_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER (Passage du controller et de la fonction search)
                        _HomeHeader(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                        ),
                        const SizedBox(height: 16),

                        // FEATURED
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'En vedette',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
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
                                onTap: () {
                                  _startSurahAudio(s); // Lance l'audio
                                  _openReader(s['page']); // Ouvre le lecteur
                                },
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
                                      Text(
                                        s['nameAr'],
                                        style: const TextStyle(fontFamily: 'Amiri', fontSize: 18),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        s['nameFr'],
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ALL SURAH
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Toutes les sourates',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),

                        ListView.builder(
                          key: const PageStorageKey('all_surah_list'),
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
                              onTap: () {
                                _startSurahAudio(s); // Lance l'audio
                                _openReader(s['page']); // Ouvre le lecteur
                              },
                              onToggleFavorite: () async {
                                setState(() {
                                  _favorites.contains(s['id'])
                                      ? _favorites.remove(s['id'])
                                      : _favorites.add(s['id']);
                                });
                                final prefs = await SharedPreferences.getInstance();
                                prefs.setStringList(
                                  'favorites',
                                  _favorites.map((e) => e.toString()).toList(),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: BottomAudioBar(), // Utilise maintenant le titre du service
      ),
    );
  }
}

// ---------------- HEADER WIDGET MIS À JOUR ----------------
class _HomeHeader extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const _HomeHeader({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0B3D2E), Color(0xFF2E8B57)]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'الْقُرْآنُ الْكَرِيمُ',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize: 32,
              color: Colors.white,
              height: 1.7,
              letterSpacing: 0.5,
              shadows: [
                Shadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize: 26,
              color: Colors.white70,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              onChanged: onChanged, // <--- Relie la recherche
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