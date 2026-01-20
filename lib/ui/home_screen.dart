import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_screen.dart';
import 'widgets/surah_card.dart';
import 'widgets/bottom_audio_bar.dart';
import '../surah_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _loadSurahData() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;
  final List<Map<String, dynamic>> list = [];
    // compute ayah counts and surah page
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
    // sort by id
    list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    setState(() {
      fullSurahList = list;
      filteredList = List.from(list);
      _isLoading = false;
    });
    // load favorites from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = prefs.getStringList('favorites') ?? [];
      setState(() {
        _favorites.addAll(favs.map((s) => int.tryParse(s)).whereType<int>());
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
    if (qLower.isEmpty) {
      setState(() => filteredList = List.from(fullSurahList));
      return;
    }
    setState(() {
      filteredList = fullSurahList.where((s) {
        final a = (s['nameAr'] as String).toLowerCase();
        final f = (s['nameFr'] as String).toLowerCase();
        return a.contains(qLower) || f.contains(qLower) || s['id'].toString() == qLower;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF0B3D2E), Color(0xFF2E8B57)]),
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mon Coran', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Continue your journey', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          // Search bar
                          Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Rechercher une sourate...'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Featured (carousel-like horizontal)
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredList.length < 8 ? filteredList.length : 8,
                        itemBuilder: (context, index) {
                          final s = filteredList[index];
                          return GestureDetector(
                            onTap: () => _openReader(s['page']),
                            child: Container(
                              width: 240,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(child: Text(s['nameAr'], style: const TextStyle(fontFamily: 'Amiri', fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(height: 6),
                                  Text(s['nameFr'], style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sourate ${s['id']}', style: const TextStyle(fontSize: 12, color: Colors.black45)), IconButton(onPressed: () {}, icon: const Icon(Icons.play_circle_fill, color: Colors.green))])
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // All Surahs (card list)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Toutes les sourates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final s = filteredList[index];
                        return SurahCard(
                          id: s['id'],
                          nameAr: s['nameAr'],
                          nameFr: s['nameFr'],
                          ayahCount: s['ayahCount'] ?? 0,
                          isFavorite: _favorites.contains(s['id']),
                          onTap: () => _openReader(s['page']),
                          onToggleFavorite: () async {
                            setState(() {
                              if (_favorites.contains(s['id'])) {
                                _favorites.remove(s['id']);
                              } else {
                                _favorites.add(s['id']);
                              }
                            });
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              prefs.setStringList('favorites', _favorites.map((e) => e.toString()).toList());
                            } catch (_) {}
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: BottomAudioBar(title: 'Lecture en cours'),
      ),
    );
  }
}
