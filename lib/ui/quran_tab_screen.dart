import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../surah_name.dart';
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
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>({});

  late final List<Map<String, dynamic>> _surahList = _buildSurahList();

  List<Map<String, dynamic>> _buildSurahList() {
    return List.generate(114, (i) {
      final id = i + 1;
      return {
        'id': id,
        'nameAr': getSurahNameArabic(id),
        'nameFr': surahFr[id] ?? 'Sourate $id',
        'page': getPageNumber(id, 1),
        'ayahCount': getVerseCount(id),
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
    return SurahListScreen(
      surahList: _surahList,
      favoriteIdsNotifier: _favoriteIdsNotifier,
      onOpenReader: _openReader,
      onPlaySurah: _playSurah,
    );
  }
}
