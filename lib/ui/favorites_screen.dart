import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/favorites_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../surah_name.dart';
import 'reader_screen.dart';
import 'widgets/surah_card.dart';

/// Écran dédié aux sourates favorites
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final AudioService _audio = AudioService.instance;
  List<Map<String, dynamic>> _favoriteSurahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    
    // Charger toutes les sourates
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
      final ar = quranData.firstWhere(
        (e) => e['surah'] == id,
        orElse: () => null,
      );

      list.add({
        'id': id,
        'nameAr': ar?['sura_name'] ?? 'Sourate $id',
        'nameFr': surahFr[id] ?? 'Sourate $id',
        'page': startPage[id] ?? 1,
        'ayahCount': ayahCounts[id] ?? 0,
      });
    }

    list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    // Filtrer uniquement les favoris
    final favorites = await FavoritesService.instance.getFavorites();
    final favList = list.where((s) => favorites.contains(s['id'])).toList();

    setState(() {
      _favoriteSurahs = favList;
      _isLoading = false;
    });
  }

  void _openReader(int page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(initialPage: page, reading: 'hafs')),
    );
  }

  void _startSurahAudio(Map<String, dynamic> s) {
    _audio.loadPlaylistAndPlay(s['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mes Favoris',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _favoriteSurahs.isEmpty
                  ? _buildEmptyState()
                  : _buildFavoritesList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune sourate favorite',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Appuyez sur le ❤️ pour ajouter\ndes sourates à vos favoris',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_favoriteSurahs.length} sourate${_favoriteSurahs.length > 1 ? 's' : ''} favorite${_favoriteSurahs.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Vos sourates préférées du Coran',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: StreamBuilder<int?>(
              stream: _audio.currentIndexStream,
              builder: (context, snapshot) {
                final currentPlayingId = (snapshot.data ?? -1) + 1;
                
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  itemCount: _favoriteSurahs.length,
                  itemBuilder: (context, index) {
                    final s = _favoriteSurahs[index];
                    return SurahCard(
                      id: s['id'],
                      nameAr: s['nameAr'],
                      nameFr: s['nameFr'],
                      ayahCount: s['ayahCount'],
                      isFavorite: true, // Toujours true ici
                      isPlaying: s['id'] == currentPlayingId,
                      onTap: () => _openReader(s['page']),
                      onPlay: () => _startSurahAudio(s),
                      onToggleFavorite: () async {
                        await FavoritesService.instance.removeFavorite(s['id']);
                        _loadFavorites(); // Recharger la liste
                      },
                    );
                  },
                );
              }
            ),
          ),
        ),
      ],
    );
  }
}
