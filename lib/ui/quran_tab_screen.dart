import 'dart:convert';
import 'package:flutter/material.dart';
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
      future: _surahFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final list = snap.data ?? const <Map<String, dynamic>>[];

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
