import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart'; // <--- N'oublie pas d'ajouter dio dans pubspec.yaml
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import 'reader_screen.dart';
import 'widgets/surah_card.dart';
import 'widgets/player_bottom_sheet.dart';
import '../surah_name.dart';

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

  void _showPlayerSheet() {
    if (_currentSurah == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlayerBottomSheet(
        surahList: fullSurahList,
        currentSurah: _currentSurah!,
        onReciterChangeRequested: _showReciterPicker,
        onSurahChange: (newSurah) {
          // On ne veut pas ré-ouvrir le lecteur, juste jouer le son
          _startSurahAudio(newSurah);
        },
      ),
    );
  }

  // --- LOGIQUE POUR CHOISIR LE RÉCITANT ---
  void _showReciterPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B3D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _ReciterSelectorSheet(
        onSelected: (name, server) {
          setState(() {
            _audio.currentReciterName = name;
            _audio.currentServer = server;
          });
          // Optionnel : redémarrer la lecture avec le nouveau récitant si une sourate est en cours
          if (_currentSurah != null) {
            _startSurahAudio(_currentSurah!);
          }
        },
      ),
    );
  }

  void _startSurahAudio(Map<String, dynamic> s) async {
    setState(() {
      _currentSurah = s;
    });

    final String idStr = s['id'].toString().padLeft(3, '0');
    String baseUrl = _audio.currentServer;
    if (!baseUrl.endsWith('/')) baseUrl += '/';
    
    final String url = "$baseUrl$idStr.mp3";
    
    _audio.currentTitle = s['nameFr'];
    await _audio.setUrl(url);
    _audio.play();
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
          : SafeArea(
              child: SingleChildScrollView(
                key: const PageStorageKey('home_scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeHeader(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      reciterName: _audio.currentReciterName,
                      onReciterTap: _showReciterPicker, // Relie le clic au picker
                    ),
                    const SizedBox(height: 16),
                    // ... (Reste de ton code Featured et All Surah identique)
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
                            onTap: () {
                              _startSurahAudio(s);
                              _openReader(s['page']);
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
                                  Text(s['nameAr'], style: const TextStyle(fontFamily: 'Amiri', fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    ListView.builder(
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
                            _startSurahAudio(s);
                            _openReader(s['page']);
                          },
                          onToggleFavorite: () async {
                            setState(() {
                              _favorites.contains(s['id']) ? _favorites.remove(s['id']) : _favorites.add(s['id']);
                            });
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setStringList('favorites', _favorites.map((e) => e.toString()).toList());
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: StreamBuilder<bool>(
        stream: _audio.isActiveStream,
        builder: (context, snapshot) {
          final bool isActive = snapshot.data ?? false;
          if (!isActive) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: _showPlayerSheet,
            backgroundColor: const Color(0xFFC8A165),
            child: StreamBuilder<PlayerState>(
              stream: _audio.playerStateStream,
              builder: (context, stateSnapshot) {
                final isPlaying = stateSnapshot.data?.playing ?? false;
                return Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white);
              }
            ),
          );
        },
      ),
    );
  }
}

// ---------------- WIDGET DE SÉLECTION DES RÉCITANTS ----------------
class _ReciterSelectorSheet extends StatefulWidget {
  final Function(String name, String server) onSelected;
  const _ReciterSelectorSheet({required this.onSelected});

  @override
  State<_ReciterSelectorSheet> createState() => _ReciterSelectorSheetState();
}

class _ReciterSelectorSheetState extends State<_ReciterSelectorSheet> {
  List allReciters = [];
  List filteredReciters = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReciters();
  }

  void _fetchReciters() async {
    try {
      final res = await Dio().get("https://mp3quran.net/api/v3/reciters?language=fr");
      setState(() {
        allReciters = res.data['reciters'];
        filteredReciters = allReciters;
        loading = false;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Choisir un récitant", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Chercher un récitant...",
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() {
                filteredReciters = allReciters.where((r) => r['name'].toLowerCase().contains(val.toLowerCase())).toList();
              });
            },
          ),
          const SizedBox(height: 15),
          Expanded(
            child: loading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8A165)))
              : ListView.builder(
                  itemCount: filteredReciters.length,
                  itemBuilder: (context, i) {
                    final r = filteredReciters[i];
                    final moshaf = r['moshaf'][0];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: Text(r['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(moshaf['name'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFC8A165)),
                      onTap: () {
                        widget.onSelected(r['name'], moshaf['server']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
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