// lib/ui/full_player_screen.dart
//
// Lecteur audio plein-écran – redesign complet.
// Fond dégradé dynamique selon la sourate.
// Zone artwork + infos + barre de progression + contrôles.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../surah_name.dart';
import 'reciter_picker_screen.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final AudioService _audio = AudioService.instance;
  final Dio _dio = Dio();

  List<Map<String, dynamic>>? _cachedReciters;
  Set<int> _favorites = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.instance.getFavorites();
    if (mounted) setState(() => _favorites = favs);
  }

  // ── API reciters ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getReciters() async {
    if (_cachedReciters != null) return _cachedReciters!;
    final res = await _dio.get(
        'https://mp3quran.net/api/v3/reciters?language=eng');
    _cachedReciters =
        ((res.data['reciters'] as List?) ?? []).cast<Map<String, dynamic>>();
    return _cachedReciters!;
  }

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
    if (s.contains('hafs'))        { riwaya = 'Hafs'; }
    else if (s.contains('warsh'))  { riwaya = 'Warsh'; }
    else if (s.contains('khalaf')) { riwaya = 'Khalaf'; }
    String type = '';
    if (s.contains('murattal'))                              { type = 'Murattal'; }
    else if (s.contains('mujawwad') || s.contains('mujawad')) { type = 'Mujawwad'; }
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

  String _toArabicNum(int n) {
    const digits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }

  // Couleurs dynamiques selon la sourate (5 thèmes)
  List<Color> _artColors(int surahId) {
    final g = (surahId - 1) ~/ 23;
    return switch (g) {
      0 => const [Color(0xFF0E6B63), Color(0xFF0B4F4A)], // teal
      1 => const [Color(0xFF1A3A6B), Color(0xFF0F2355)], // bleu
      2 => const [Color(0xFF3A1A6B), Color(0xFF250F55)], // violet
      3 => const [Color(0xFF6B4A1A), Color(0xFF503510)], // or
      _ => const [Color(0xFF1A6B3A), Color(0xFF0F5025)], // vert
    };
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  void _openReciterPicker() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          const ReciterPickerScreen(pushPlayerOnSelect: false),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 220),
    ));
  }

  void _showSurahPicker() {
    int selected = _audio.currentSurahId ?? 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg  = isDark ? const Color(0xFF0F1628) : Colors.white;
        final txt = isDark ? Colors.white : const Color(0xFF111827);
        const gold = Color(0xFFC8A165);

        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: txt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler',
                          style: TextStyle(color: txt.withValues(alpha: 0.5))),
                    ),
                    Text('Choisir une sourate',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: txt)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _audio.loadPlaylistAndPlay(selected);
                      },
                      child: const Text('OK',
                          style: TextStyle(
                              color: gold, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              // Wheel
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ListWheelScrollView.useDelegate(
                      itemExtent: 48,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(
                          initialItem: selected - 1),
                      onSelectedItemChanged: (i) => selected = i + 1,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 114,
                        builder: (_, i) {
                          final id   = i + 1;
                          final name = surahFr[id] ?? 'Sourate $id';
                          return Center(
                            child: Text('$id. $name',
                                style: TextStyle(
                                    color: txt, fontSize: 17)),
                          );
                        },
                      ),
                    ),
                    // Lignes de sélection
                    IgnorePointer(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Divider(
                              height: 1,
                              color: gold.withValues(alpha: 0.4)),
                          const SizedBox(height: 48),
                          Divider(
                              height: 1,
                              color: gold.withValues(alpha: 0.4)),
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

  Future<void> _openRiwayaPicker() async {
    final currentReciter = _audio.currentReciterNotifier.value;
    final base = _baseReciterName(currentReciter);
    if (_normName(base).isEmpty) {
      _snack("Choisis d'abord un réciteur");
      return;
    }

    final reciters = await _getReciters();
    final normBase = _normName(base);
    List<Map<String, dynamic>> options = [];
    for (final r in reciters) {
      final nn = _normName((r['name'] ?? '').toString());
      if (nn != normBase && !nn.contains(normBase) && !normBase.contains(nn)) {
        continue;
      }
      final moshafs = (r['moshaf'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final m in moshafs) {
        final server = (m['server'] ?? '').toString().trim();
        if (server.isEmpty) continue;
        options.add({
          'name':        m['name'] ?? '',
          'server':      server.endsWith('/') ? server : '$server/',
          'surah_total': (m['surah_total'] is int)
              ? m['surah_total']
              : int.tryParse('${m['surah_total']}') ?? 114,
        });
      }
      break;
    }

    if (!mounted) return;
    if (options.isEmpty) { _snack('Aucune riwāya pour $base'); return; }

    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0F1628) : Colors.white;
    final txtPrim = isDark ? Colors.white : const Color(0xFF111827);

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(base,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: txtPrim)),
              const SizedBox(height: 4),
              Text('Choisir la riwāya',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: txtPrim.withValues(alpha: 0.55))),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: txtPrim.withValues(alpha: 0.08)),
                  itemBuilder: (_, i) {
                    final o      = options[i];
                    final pretty = _prettyMoshaf(o['name'].toString());
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(pretty,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: txtPrim)),
                      subtitle: Text(
                        o['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: txtPrim.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                            fontSize: 12),
                      ),
                      trailing: Text(
                        '${o['surah_total']} sourates',
                        style: TextStyle(
                            color: txtPrim.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(ctx, o),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    final displayName = '$base (${_prettyMoshaf(picked['name'].toString())})';
    _audio.setReciter(displayName, picked['server'].toString());
    final id = _audio.currentSurahId;
    if (id != null) _audio.loadPlaylistAndPlay(id);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: Stack(
        children: [
          // Fond dégradé animé selon la sourate
          Positioned.fill(
            child: ValueListenableBuilder<int?>(
              valueListenable: _audio.currentPlayingSurahIdNotifier,
              builder: (_, surahId, __) {
                final colors = _artColors(surahId ?? 1);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        colors[0].withValues(alpha: 0.45),
                        const Color(0xFF080D1A),
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                );
              },
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                // ── Barre du haut ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'En lecture',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // Favoris
                      ValueListenableBuilder<int?>(
                        valueListenable: _audio.currentPlayingSurahIdNotifier,
                        builder: (_, surahId, __) {
                          final isFav = surahId != null &&
                              _favorites.contains(surahId);
                          return IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav ? Colors.redAccent : Colors.white54,
                              size: 24,
                            ),
                            onPressed: () async {
                              if (surahId != null) {
                                await FavoritesService.instance
                                    .toggleFavorite(surahId);
                                _loadFavorites();
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Zone artwork ─────────────────────────────────────────────
                ValueListenableBuilder<int?>(
                  valueListenable: _audio.currentPlayingSurahIdNotifier,
                  builder: (_, surahId, __) => _Artwork(
                    surahId:   surahId ?? 1,
                    artColors: _artColors(surahId ?? 1),
                    arabicNum: _toArabicNum(surahId ?? 1),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Infos sourate + réciteur ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sourate (tappable)
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more_rounded,
                                color: Colors.white54, size: 26),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Réciteur (tappable → ReciterPickerScreen)
                      GestureDetector(
                        onTap: _openReciterPicker,
                        child: Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<String>(
                                valueListenable:
                                    _audio.currentReciterNotifier,
                                builder: (_, reciter, __) => Text(
                                  reciter,
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
                            Icon(Icons.expand_more_rounded,
                                color: gold.withValues(alpha: 0.5), size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Barre de progression ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildProgressBar(gold),
                ),

                const SizedBox(height: 20),

                // ── Contrôles principaux ─────────────────────────────────────
                _buildControls(gold),

                const SizedBox(height: 12),

                // ── Contrôles secondaires ────────────────────────────────────
                _buildSecondaryControls(gold),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de progression ──────────────────────────────────────────────────

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
                trackHeight: 3.5,
                activeTrackColor: gold,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: gold,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                overlayColor: gold.withValues(alpha: 0.20),
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
                          color: Colors.white54, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Text(_formatDuration(dur),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Contrôles principaux ──────────────────────────────────────────────────

  Widget _buildControls(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.skip_previous_rounded,
          size: 36,
          onTap: _audio.skipToPrevious,
        ),
        const SizedBox(width: 20),

        // Play / Pause
        StreamBuilder<PlayerState>(
          stream: _audio.playerStateStream,
          builder: (_, snap) {
            final state    = snap.data;
            final playing  = state?.playing ?? false;
            final process  = state?.processingState;
            final loading  = process == ProcessingState.loading ||
                             process == ProcessingState.buffering;

            return GestureDetector(
              onTap: _audio.togglePlayPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.black54, strokeWidth: 2.5),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black87,
                        size: 38,
                      ),
              ),
            );
          },
        ),

        const SizedBox(width: 20),
        _ControlBtn(
          icon: Icons.skip_next_rounded,
          size: 36,
          onTap: _audio.skipToNext,
        ),
      ],
    );
  }

  // ── Contrôles secondaires ─────────────────────────────────────────────────

  Widget _buildSecondaryControls(Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Boucle
          ValueListenableBuilder<LoopMode>(
            valueListenable: _audio.loopModeNotifier,
            builder: (_, mode, __) => _ControlBtn(
              icon: mode == LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 24,
              color: mode == LoopMode.off
                  ? Colors.white38
                  : gold,
              onTap: _audio.cycleLoopMode,
            ),
          ),

          // Réciteur (raccourci)
          _ControlBtn(
            icon: Icons.person_rounded,
            size: 24,
            color: Colors.white38,
            onTap: _openReciterPicker,
          ),

          // Riwāya
          _ControlBtn(
            icon: Icons.tune_rounded,
            size: 24,
            color: Colors.white38,
            onTap: _openRiwayaPicker,
          ),
        ],
      ),
    );
  }
}

// ── Artwork ───────────────────────────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  final int         surahId;
  final List<Color> artColors;
  final String      arabicNum;

  const _Artwork({
    required this.surahId,
    required this.artColors,
    required this.arabicNum,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: 230, height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: artColors,
          ),
          boxShadow: [
            BoxShadow(
              color: artColors[0].withValues(alpha: 0.55),
              blurRadius: 48,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Motif de points décoratif
            const Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(38)),
                child: CustomPaint(painter: _DotsPainter()),
              ),
            ),
            // Numéro arabe + label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  arabicNum,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'سورة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton de contrôle ────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double   size;
  final Color    color;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: onTap,
      splashRadius: size + 8,
    );
  }
}

// ── Motif de points ───────────────────────────────────────────────────────────

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(99);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 2.5 + 0.8;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter _) => false;
}
