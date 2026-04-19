import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';
import '../../services/favorites_service.dart';
import '../../data/surah_name.dart';
import 'package:dio/dio.dart';

class MusicPlayerFullScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const MusicPlayerFullScreen({super.key, this.scrollController});

  @override
  State<MusicPlayerFullScreen> createState() => _MusicPlayerFullScreenState();
}

class _MusicPlayerFullScreenState extends State<MusicPlayerFullScreen> {
  final AudioService _audio = AudioService.instance;
  final Dio _dio = Dio();
  List<Map<String, dynamic>>? _cachedReciters;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _baseReciterName(String s) {
    final i = s.indexOf('(');
    return (i == -1 ? s : s.substring(0, i)).trim();
  }

  String _prettyMoshaf(String raw) {
    final s = raw.toLowerCase();
    String riwaya = '';
    if (s.contains('hafs')) {
      riwaya = 'Hafs';
    } else if (s.contains('warsh')) {
      riwaya = 'Warsh';
    } else if (s.contains('khalaf')) {
      riwaya = 'Khalaf';
    }
    String type = '';
    if (s.contains('murattal')) {
      type = 'Murattal';
    } else if (s.contains('mujawwad') || s.contains('mujawad')) {
      type = 'Mujawwad';
    }
    if (riwaya.isEmpty && type.isEmpty) return raw;
    if (type.isEmpty)   return riwaya;
    if (riwaya.isEmpty) return type;
    return '$riwaya • $type';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final mm = two(d.inMinutes.remainder(60));
    final ss = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${two(d.inHours)}:$mm:$ss' : '$mm:$ss';
  }


  List<Color> _surahColors(int surahId) {
    final g = (surahId - 1) ~/ 23;
    return switch (g) {
      0 => const [Color(0xFF0E6B63), Color(0xFF0B4F4A)],
      1 => const [Color(0xFF1A3A6B), Color(0xFF0F2355)],
      2 => const [Color(0xFF3A1A6B), Color(0xFF250F55)],
      3 => const [Color(0xFF6B4A1A), Color(0xFF503510)],
      _ => const [Color(0xFF1A6B3A), Color(0xFF0F5025)],
    };
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  void _showSurahPicker() {
    int selected = _audio.currentSurahId ?? 1;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: 320,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    const Text('Choisir une sourate',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _audio.loadPlaylistAndPlay(selected);
                      },
                      child: const Text('OK',
                          style: TextStyle(
                              color: Color(0xFFC8A165),
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ListWheelScrollView.useDelegate(
                      itemExtent: 48,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: selected - 1),
                      onSelectedItemChanged: (i) => selected = i + 1,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 114,
                        builder: (_, i) {
                          final id = i + 1;
                          return Center(
                            child: Text('$id. ${surahFr[id] ?? 'Sourate $id'}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 17)),
                          );
                        },
                      ),
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Divider(height: 1, color: const Color(0xFFC8A165).withValues(alpha: 0.35)),
                          const SizedBox(height: 48),
                          Divider(height: 1, color: const Color(0xFFC8A165).withValues(alpha: 0.35)),
                        ],
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

  Future<void> _showReciterPicker() async {
    List<Map<String, dynamic>> reciters = [];
    try {
      _cachedReciters ??= ((await _dio.get(
        'https://mp3quran.net/api/v3/reciters?language=eng',
      )).data['reciters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      reciters = _cachedReciters!;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau')),
        );
      }
      return;
    }
    if (reciters.isEmpty || !mounted) return;

    final currentBase = _baseReciterName(_audio.currentReciterNotifier.value);
    int initialIndex = 0;
    for (int i = 0; i < reciters.length; i++) {
      if (_normName((reciters[i]['name'] ?? '').toString()) == _normName(currentBase)) {
        initialIndex = i;
        break;
      }
    }
    int selectedIndex = initialIndex;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const Text('Choisir un réciteur',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final r = reciters[selectedIndex];
                      final name = (r['name'] ?? '').toString();
                      final moshafs = (r['moshaf'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                      if (moshafs.isEmpty) return;
                      final moshaf = moshafs.firstWhere(
                        (m) => (m['name'] ?? '').toString().toLowerCase().contains('hafs'),
                        orElse: () => moshafs.first,
                      );
                      final server = (moshaf['server'] ?? '').toString();
                      final displayName = '$name (${_prettyMoshaf(moshaf['name'].toString())})';
                      _audio.setReciter(displayName, server);
                      final id = _audio.currentSurahId;
                      if (id != null) _audio.loadPlaylistAndPlay(id);
                    },
                    child: const Text('OK',
                        style: TextStyle(
                            color: Color(0xFFC8A165),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ListWheelScrollView.useDelegate(
                    itemExtent: 48,
                    diameterRatio: 1.5,
                    perspective: 0.003,
                    physics: const FixedExtentScrollPhysics(),
                    controller: FixedExtentScrollController(initialItem: initialIndex),
                    onSelectedItemChanged: (i) => selectedIndex = i,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: reciters.length,
                      builder: (_, i) => Center(
                        child: Text(
                          (reciters[i]['name'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 17),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Divider(height: 1, color: const Color(0xFFC8A165).withValues(alpha: 0.35)),
                        const SizedBox(height: 48),
                        Divider(height: 1, color: const Color(0xFFC8A165).withValues(alpha: 0.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<String?>(
        valueListenable: _audio.currentReciterAssetNotifier,
        builder: (_, reciterAsset, __) {
          return ValueListenableBuilder<int?>(
            valueListenable: _audio.currentPlayingSurahIdNotifier,
            builder: (_, surahId, __) {
              final colors = _surahColors(surahId ?? 1);
              return Stack(
                children: [
                  // ── Fond ───────────────────────────────────────────────────
                  Positioned.fill(
                    child: reciterAsset != null
                        ? Image.asset(reciterAsset, fit: BoxFit.cover)
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [colors[0], colors[1]],
                              ),
                            ),
                          ),
                  ),

                  // ── Blur + overlay sombre ──────────────────────────────────
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                      child: Container(
                        color: Colors.black.withValues(alpha: reciterAsset != null ? 0.55 : 0.45),
                      ),
                    ),
                  ),

                  // ── Contenu ────────────────────────────────────────────────
                  SafeArea(
                    child: Column(
                      children: [
                        // Top bar
                        _buildTopBar(surahId, gold),

                        const Spacer(),

                        // Artwork
                        _buildArtwork(surahId ?? 1, reciterAsset, colors, gold),

                        const SizedBox(height: 36),

                        // Infos
                        _buildTrackInfo(gold),

                        const SizedBox(height: 32),

                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: _buildProgressBar(gold),
                        ),

                        const SizedBox(height: 20),

                        // Contrôles principaux
                        _buildControls(gold),

                        const SizedBox(height: 20),

                        // Contrôles secondaires
                        _buildSecondaryControls(gold),

                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(int? surahId, Color gold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_down,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'En lecture',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ValueListenableBuilder<int?>(
            valueListenable: _audio.currentPlayingSurahIdNotifier,
            builder: (_, id, __) {
              return FutureBuilder<bool>(
                future: id != null
                    ? FavoritesService.instance.isFavorite(id)
                    : Future.value(false),
                builder: (_, snap) {
                  final isFav = snap.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: isFav ? const Color(0xFFFF6B6B) : Colors.white60,
                      size: 22,
                    ),
                    onPressed: () async {
                      if (id != null) {
                        await FavoritesService.instance.toggleFavorite(id);
                        setState(() {});
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Artwork ───────────────────────────────────────────────────────────────

  Widget _buildArtwork(
      int surahId, String? reciterAsset, List<Color> colors, Color gold) {
    const size = 260.0;
    const radius = 24.0;

    final svgFallback = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1408), Color(0xFF0C0A04)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SvgPicture.asset(
              'assets/images/navbar/Quran_Kareem.svg',
              colorFilter: const ColorFilter.mode(
                  Color(0xFFC8A165), BlendMode.srcIn),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
    );

    Widget artContent;
    if (reciterAsset != null) {
      artContent = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          reciterAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => svgFallback,
        ),
      );
    } else {
      artContent = svgFallback;
    }

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: artContent,
      ),
    );
  }

  // ── Infos track ───────────────────────────────────────────────────────────

  Widget _buildTrackInfo(Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _showSurahPicker,
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _audio.currentTitleNotifier,
                    builder: (_, title, __) => Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_up_chevron_down,
                    color: Colors.white38, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showReciterPicker,
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _audio.currentReciterNotifier,
                    builder: (_, reciter, __) => Text(
                      _baseReciterName(reciter),
                      style: TextStyle(
                        color: gold.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.chevron_up_chevron_down,
                    color: gold.withValues(alpha: 0.4), size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar(Color gold) {
    return StreamBuilder<PositionData>(
      stream: _audio.positionDataStream,
      builder: (_, snap) {
        final pos = snap.data?.position ?? Duration.zero;
        final dur = snap.data?.duration ?? Duration.zero;
        final maxMs = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final posMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: posMs,
                max: maxMs,
                onChanged: (v) =>
                    _audio.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(pos),
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Text(_formatDuration(dur),
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _seekRelative(int seconds) {
    _audio.positionDataStream.first.then((data) {
      final newPos = data.position + Duration(seconds: seconds);
      _audio.seek(newPos.isNegative ? Duration.zero : newPos);
    });
  }

  // ── Contrôles principaux ──────────────────────────────────────────────────

  Widget _buildControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Sourate précédente
        IconButton(
          icon: const Icon(CupertinoIcons.backward_fill,
              color: Colors.white, size: 32),
          onPressed: _audio.skipToPrevious,
          iconSize: 32,
        ),
        const SizedBox(width: 8),

        // -10 secondes
        IconButton(
          icon: const Icon(Icons.replay_10_rounded,
              color: Colors.white, size: 32),
          onPressed: () => _seekRelative(-10),
          iconSize: 32,
        ),
        const SizedBox(width: 16),

        // Play / Pause
        StreamBuilder<PlayerState>(
          stream: _audio.playerStateStream,
          builder: (_, snap) {
            final playing = snap.data?.playing ?? false;
            final process = snap.data?.processingState;
            final loading = process == ProcessingState.loading ||
                process == ProcessingState.buffering;

            return GestureDetector(
              onTap: _audio.togglePlayPause,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: Colors.black54, strokeWidth: 2.5))
                    : Icon(
                        playing
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: Colors.black87,
                        size: 34,
                      ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),

        // +10 secondes
        IconButton(
          icon: const Icon(Icons.forward_10_rounded,
              color: Colors.white, size: 32),
          onPressed: () => _seekRelative(10),
          iconSize: 32,
        ),
        const SizedBox(width: 8),

        // Sourate suivante
        IconButton(
          icon: const Icon(CupertinoIcons.forward_fill,
              color: Colors.white, size: 32),
          onPressed: _audio.skipToNext,
          iconSize: 32,
        ),
      ],
    );
  }

  // ── Contrôles secondaires ─────────────────────────────────────────────────

  Widget _buildSecondaryControls(Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Repeat
          ValueListenableBuilder<LoopMode>(
            valueListenable: _audio.loopModeNotifier,
            builder: (_, mode, __) => IconButton(
              icon: Icon(
                mode == LoopMode.one
                    ? CupertinoIcons.repeat_1
                    : CupertinoIcons.repeat,
                color: mode == LoopMode.off ? Colors.white38 : gold,
                size: 22,
              ),
              onPressed: _audio.cycleLoopMode,
            ),
          ),

          // Shuffle
          ValueListenableBuilder<bool>(
            valueListenable: _audio.isShuffleEnabled,
            builder: (_, isOn, __) => IconButton(
              icon: Icon(
                CupertinoIcons.shuffle,
                color: isOn ? gold : Colors.white38,
                size: 22,
              ),
              onPressed: () => _audio.toggleShuffle(),
            ),
          ),

          // Stop
          IconButton(
            icon: const Icon(CupertinoIcons.stop_fill,
                color: Colors.white38, size: 22),
            onPressed: () {
              _audio.stop();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

