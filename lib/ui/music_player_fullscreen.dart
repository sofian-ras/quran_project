import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../surah_name.dart';
import 'widgets/reciter_selector.dart';
import 'package:dio/dio.dart';

class MusicPlayerFullScreen extends StatefulWidget {
  final ScrollController? scrollController;
  
  const MusicPlayerFullScreen({super.key, this.scrollController});

  @override
  State<MusicPlayerFullScreen> createState() => _MusicPlayerFullScreenState();
}

class _MusicPlayerFullScreenState extends State<MusicPlayerFullScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService.instance;
  late AnimationController _animationController;
  final Dio _dio = Dio();

  String _normName(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

  String _baseReciterName(String s) {
    final i = s.indexOf('(');
    return (i == -1 ? s : s.substring(0, i)).trim();
  }

  String _prettyMoshafName(String raw) {
    final s = raw.toLowerCase();

    String riwaya;
    if (s.contains('hafs')) riwaya = 'Hafs';
    else if (s.contains('warsh')) riwaya = 'Warsh';
    else if (s.contains('khalaf')) riwaya = 'Khalaf';
    else if (s.contains('assosi') || s.contains('soosi') || s.contains('soussi')) riwaya = 'As-Soosi';
    else riwaya = raw;

    String type = '';
    if (s.contains('murattal')) type = 'Murattal';
    else if (s.contains('mujawwad') || s.contains('mujawad')) type = 'Mujawwad';

    return type.isEmpty ? riwaya : '$riwaya • $type';
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    // Ne pas démarrer automatiquement, attendre que l'audio joue
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showSurahPicker(BuildContext context) {
    int selectedSurahId = _audio.currentSurahId ?? 1;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                    ),
                    const Text(
                      'Choisir une sourate',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _audio.loadPlaylistAndPlay(selectedSurahId);
                      },
                      child: const Text('OK', style: TextStyle(color: Color(0xFFC8A165), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListWheelScrollView.useDelegate(
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: selectedSurahId - 1),
                      onSelectedItemChanged: (index) {
                        selectedSurahId = index + 1;
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 114,
                        builder: (context, index) {
                          final surahId = index + 1;
                          final surahName = surahFr[surahId] ?? 'Sourate $surahId';
                          return Center(
                            child: Text(
                              '$surahId. $surahName',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          );
                        },
                      ),
                    ),
                    Center(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: const Color(0xFFC8A165).withOpacity(0.3), width: 1),
                            bottom: BorderSide(color: const Color(0xFFC8A165).withOpacity(0.3), width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReciterPicker(BuildContext context) async {
    List<Map<String, dynamic>> reciters = [];
    try {
      final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=eng");
      reciters = ((res.data['reciters'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de chargement des récitateurs')),
      );
      return;
    }

    if (reciters.isEmpty || !mounted) return;

    final currentReciter = _audio.currentReciterNotifier.value;
    final currentBase = _baseReciterName(currentReciter);
    int initialIndex = 0;
    for (int i = 0; i < reciters.length; i++) {
      final name = (reciters[i]['name'] ?? '').toString();
      if (_normName(name) == _normName(currentBase)) {
        initialIndex = i;
        break;
      }
    }

    int selectedIndex = initialIndex;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 350,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                    ),
                    const Text(
                      'Choisir un récitateur',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final selected = reciters[selectedIndex];
                        final name = (selected['name'] ?? '').toString();
                        final moshafs = (selected['moshaf'] as List?) ?? [];
                        
                        if (moshafs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Aucun moshaf disponible pour $name')),
                          );
                          return;
                        }

                        Map<String, dynamic>? selectedMoshaf;
                        for (final m in moshafs) {
                          final moshafName = (m['name'] ?? '').toString().toLowerCase();
                          if (moshafName.contains('hafs')) {
                            selectedMoshaf = m as Map<String, dynamic>;
                            break;
                          }
                        }
                        selectedMoshaf ??= moshafs.first as Map<String, dynamic>;

                        final server = (selectedMoshaf['server'] ?? '').toString();
                        final moshafName = (selectedMoshaf['name'] ?? '').toString();
                        final displayName = '$name (${_prettyMoshafName(moshafName)})';

                        _audio.setReciter(displayName, server);
                        final id = _audio.currentSurahId;
                        if (id != null) _audio.loadPlaylistAndPlay(id);
                      },
                      child: const Text('OK', style: TextStyle(color: Color(0xFFC8A165), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListWheelScrollView.useDelegate(
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: initialIndex),
                      onSelectedItemChanged: (index) {
                        selectedIndex = index;
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: reciters.length,
                        builder: (context, index) {
                          final reciterName = (reciters[index]['name'] ?? '').toString();
                          return Center(
                            child: Text(
                              reciterName,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    Center(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: const Color(0xFFC8A165).withOpacity(0.3), width: 1),
                            bottom: BorderSide(color: const Color(0xFFC8A165).withOpacity(0.3), width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaylist(BuildContext context) {
    const gold = Color(0xFFC8A165);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Favoris',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Liste des favoris
              Expanded(
                child: FutureBuilder<Set<int>>(
                  future: FavoritesService.instance.getFavorites(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    final favorites = snapshot.data!.toList()..sort();
                    if (favorites.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border, size: 64, color: Colors.white30),
                            const SizedBox(height: 16),
                            const Text(
                              "Aucun favori pour le moment.",
                              style: TextStyle(color: Colors.white60, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return StreamBuilder<int?>(
                      stream: _audio.currentIndexStream,
                      builder: (context, indexSnapshot) {
                        final currentIndex = indexSnapshot.data;
                        final currentSurahId = currentIndex != null ? currentIndex + 1 : null;
                        
                        return ListView.builder(
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final surahId = favorites[index];
                            final surahName = surahFr[surahId] ?? 'Sourate $surahId';
                            final isPlaying = currentSurahId == surahId;
                            
                            return ListTile(
                              leading: isPlaying
                                  ? Icon(Icons.volume_up, color: gold)
                                  : Text(
                                      '$surahId',
                                      style: const TextStyle(color: Colors.white60, fontSize: 16),
                                    ),
                              title: Text(
                                surahName,
                                style: TextStyle(
                                  color: isPlaying ? gold : Colors.white,
                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                onPressed: () async {
                                  await FavoritesService.instance.removeFavorite(surahId);
                                  // Rafraîchir l'écran parent pour mettre à jour le bouton favori
                                  if (mounted) setState(() {});
                                  // Rafraîchir en fermant et réouvrant
                                  Navigator.pop(context);
                                  _showPlaylist(context);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _audio.loadPlaylistAndPlay(surahId);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
          children: [
            // Image de La Mecque en fond
            Positioned.fill(
              child: Image.asset(
                'assets/images/la_mecque_portrait.webp',
                fit: BoxFit.cover,
              ),
            ),
            
            // Dégradé noir en bas pour la lisibilité
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            SafeArea(
            child: Column(
              children: [
                // AppBar personnalisée
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      const Text(
                        'Lecteur Audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPlaylist(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // Espace pour l'artwork (maintenant l'image est en fond)
                            const SizedBox(height: 240),

                            const SizedBox(height: 32),

                            // Titre et récitant
                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentTitleNotifier,
                              builder: (context, title, _) => GestureDetector(
                                onTap: () => _showSurahPicker(context),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 28),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            ValueListenableBuilder<String>(
                              valueListenable: _audio.currentReciterNotifier,
                              builder: (context, reciter, _) => GestureDetector(
                                onTap: () => _showReciterPicker(context),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      reciter,
                                      style: const TextStyle(
                                        color: gold,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_drop_down, color: gold.withOpacity(0.7), size: 24),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Barre de progression
                            _buildProgressBar(),

                            const SizedBox(height: 24),

                            // Contrôles de lecture
                            _buildControls(gold),

                            const SizedBox(height: 16),

                            // Contrôles secondaires
                            _buildSecondaryControls(gold),

                            const SizedBox(height: 20),
                          ],
                        ), // Fermeture Column interne
                      ), // Fermeture Padding
                    ), // Fermeture SingleChildScrollView
                  ), // Fermeture Expanded
                ], // Fermeture children de Column SafeArea
            ), // Fermeture Column SafeArea
          ), // Fermeture SafeArea
          ], // Fermeture children de Stack
        ), // Fermeture Stack
    ); // Fermeture Scaffold
  }

  Widget _buildProgressBar() {
    const gold = Color(0xFFC8A165);

    return StreamBuilder<PositionData>(
      stream: _audio.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        final position = positionData?.position ?? Duration.zero;
        final duration = positionData?.duration ?? Duration.zero;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16.0),
                activeTrackColor: gold,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: gold,
                overlayColor: gold.withOpacity(0.3),
              ),
              child: Slider(
                max: duration.inMilliseconds
                    .toDouble()
                    .clamp(1.0, double.infinity),
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, duration.inMilliseconds.toDouble()),
                onChanged: (value) =>
                    _audio.seek(Duration(milliseconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Précédent
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _audio.skipToPrevious,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.backward_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),

        // Play/Pause
        StreamBuilder<PlayerState>(
          stream: _audio.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final isPlaying = playerState?.playing ?? false;
            final processingState = playerState?.processingState;

            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withOpacity(0.3),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: gold,
                    strokeWidth: 3,
                  ),
                ),
              );
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _audio.togglePlayPause,
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            );
          },
        ),

        // Suivant
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _audio.skipToNext,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.forward_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mode répétition
        ValueListenableBuilder<LoopMode>(
          valueListenable: _audio.loopModeNotifier,
          builder: (context, loopMode, _) {
            final isActive = loopMode != LoopMode.off;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _audio.cycleLoopMode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? gold.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? gold.withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    loopMode == LoopMode.one
                        ? CupertinoIcons.repeat_1
                        : CupertinoIcons.repeat,
                    color: isActive ? gold : Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),

        // Shuffle
        ValueListenableBuilder<bool>(
          valueListenable: _audio.isShuffleEnabled,
          builder: (context, isShuffleOn, _) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _audio.toggleShuffle(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.shuffle,
                    color: isShuffleOn ? gold : Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),

        // Favori
        FutureBuilder<bool>(
          future: _audio.currentSurahId != null 
              ? FavoritesService.instance.isFavorite(_audio.currentSurahId!)
              : Future.value(false),
          builder: (context, snapshot) {
            final isFavorite = snapshot.data ?? false;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final surahId = _audio.currentSurahId;
                  if (surahId != null) {
                    await FavoritesService.instance.toggleFavorite(surahId);
                    setState(() {}); // Rafraîchir l'icône
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFavorite
                        ? const Color(0xFFFF6B6B).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFavorite
                          ? const Color(0xFFFF6B6B).withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: isFavorite ? const Color(0xFFFF6B6B) : Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),

        // Stop
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _audio.stop();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.stop_fill,
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
