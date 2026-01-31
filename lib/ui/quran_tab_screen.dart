import 'dart:convert';
import 'package:flutter/material.dart';
import '../surah_name.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import 'reader_screen.dart';
import 'surah_list_screen.dart';

class QuranTabScreen extends StatefulWidget {
  const QuranTabScreen({super.key});

  @override
  State<QuranTabScreen> createState() => _QuranTabScreenState();
}

class _QuranTabScreenState extends State<QuranTabScreen> {
  final AudioService _audio = AudioService.instance;

  late Future<List<Map<String, dynamic>>> _surahFuture;
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>({});

  Future<List<Map<String, dynamic>>> _loadSurahList() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;

    final Map<int, int> ayahCounts = {};
    final Map<int, int> startPage = {};

    for (final v in quranData) {
      final surahRaw = v['surah'];
      final pageRaw = v['page'];

      final int? id = (surahRaw is int) ? surahRaw : int.tryParse('$surahRaw');
      if (id == null) continue;

      final int page = (pageRaw is int) ? pageRaw : (int.tryParse('$pageRaw') ?? 1);

      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
      startPage[id] = startPage[id] ?? page;
    }

    final List<Map<String, dynamic>> list = [];
    for (int id = 1; id <= 114; id++) {
      list.add({
        'id': id,
        'nameAr': 'Sourate $id',
        'nameFr': surahFr[id] ?? 'Sourate $id',
        'page': startPage[id] ?? 1,
        'ayahCount': ayahCounts[id] ?? 0,
      });
    }

    return list;
  }


  @override
  void initState() {
    super.initState();
    _surahFuture = _loadSurahs();
    _loadFavorites();
  }

  Future<List<Map<String, dynamic>>> _loadSurahs() async {
    final jsonString = await rootBundle.loadString('assets/quran/surah_list.json');
    final List<dynamic> decoded = json.decode(jsonString) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.instance.getFavorites();
    if (!mounted) return;
    _favoriteIdsNotifier.value = ids;
  }


  void _openReader(int page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          initialPage: page,
          reading: 'hafs',
        ),
      ),
    );
  }

  void _playSurah(Map<String, dynamic> surah) async {
    final idRaw = surah['id'];
    final int? surahId = (idRaw is int) ? idRaw : int.tryParse(idRaw.toString());
    if (surahId == null) return;

    await _audio.loadPlaylistAndPlay(surahId);
  }


  @override
  void dispose() {
    _favoriteIdsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadSurahList(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) {
          return const Center(child: Text('Erreur chargement sourates'));
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Liste des sourates vide.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vérifie assets/data/quran_data.json et pubspec.yaml',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        return SurahListScreen(
          surahList: list,
          favoriteIdsNotifier: _favoriteIdsNotifier,
          onOpenReader: _openReader,
          onPlaySurah: _playSurah,
        );
      },
    );

  }
}
