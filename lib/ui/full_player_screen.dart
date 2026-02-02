import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../surah_name.dart';
import 'widgets/reciter_selector.dart';
import 'package:dio/dio.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final AudioService _audio = AudioService.instance;

  final Dio _dio = Dio();

  String _normName(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

  String _baseReciterName(String s) {
    // si tu as "Nom (Hafs • Murattal)" -> garde juste "Nom"
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

  Future<List<Map<String, dynamic>>> _fetchMoshafOptions(String reciterName) async {
    final base = _baseReciterName(reciterName);

    final res = await _dio.get("https://mp3quran.net/api/v3/reciters?language=fr");
    final reciters = (res.data['reciters'] as List?) ?? const [];

    for (final item in reciters) {
      final r = item as Map<String, dynamic>;
      final name = (r['name'] ?? '').toString().trim();
      final nn = _normName(name);
      final bb = _normName(base);
      if (nn != bb && !nn.contains(bb) && !bb.contains(nn)) continue;


      final moshaf = (r['moshaf'] as List?) ?? const [];
      final List<Map<String, dynamic>> options = [];

      for (final m in moshaf) {
        final mm = m as Map<String, dynamic>;
        final server = (mm['server'] ?? '').toString().trim();
        if (server.isEmpty) continue;

        final mName = (mm['name'] ?? '').toString().trim();
        final total = (mm['surah_total'] is int)
            ? (mm['surah_total'] as int)
            : int.tryParse('${mm['surah_total']}') ?? 114;

        options.add({
          'name': mName,
          'server': server.endsWith('/') ? server : '$server/',
          'surah_total': total,
        });
      }
      return options;
    }

    return const [];
  }

  Future<void> _openRiwayaPicker(AudioService audio) async {
    final currentReciter = audio.currentReciterNotifier.value;
    final base = _baseReciterName(currentReciter);
    if (_normName(base).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis d’abord un réciteur')),
      );
      return;
    }


    final options = await _fetchMoshafOptions(base);

    if (!mounted) return;

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune riwāya e pour $base')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F1734)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final titleColor = Theme.of(sheetCtx).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(base, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor)),
                const SizedBox(height: 6),
                Text('Choisir la riwāya',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor.withOpacity(0.65))),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: titleColor.withOpacity(0.10)),
                    itemBuilder: (_, i) {
                      final o = options[i];
                      final raw = (o['name'] ?? '').toString();
                      final pretty = _prettyMoshafName(raw);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(pretty, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)),
                        subtitle: Text(
                          raw,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: titleColor.withOpacity(0.55), fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          '${o['surah_total'] ?? 114} sourates',
                          style: TextStyle(color: titleColor.withOpacity(0.55), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(sheetCtx, o),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    final raw = (picked['name'] ?? '').toString();
    final server = (picked['server'] ?? '').toString();

    final displayName = '$base (${_prettyMoshafName(raw)})';
    audio.setReciter(displayName, server);

    // ✅ recharge la sourate courante avec le nouveau server
    final id = audio.currentSurahId;
    if (id != null) audio.loadPlaylistAndPlay(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Réciteur: $displayName')),
    );

  }


  @override
  void initState() {
    super.initState();
    _audio.loadPlaylistAndPlay(1); // Load default surah on init
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.black54.withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: TabBar(
                  indicatorColor: gold,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: gold,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(text: 'Lecteur'),
                    Tab(text: "File d'attente"),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildPlayerView(context, gold),
                  _buildPlaylistView(context, gold),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

    // ---- Vue du lecteur principal ----

    Widget _buildPlayerView(BuildContext context, Color gold) {

      return Padding(

        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            // --- Partie Haute ---

            Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                const SizedBox(height: 10), // Un peu d'espace

                

                const SizedBox(height: 30),

                ValueListenableBuilder<String>(

                  valueListenable: _audio.currentTitleNotifier,

                  builder: (_, title, __) => Text(title, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),

                ),

                const SizedBox(height: 8),

                ValueListenableBuilder<String>(

                  valueListenable: _audio.currentReciterNotifier,

                  builder: (_, reciter, __) => Text(reciter, style: TextStyle(fontSize: 15, color: gold), textAlign: TextAlign.center),

                ),

              ],

            ),

  

            // --- Partie Basse ---

            Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                _buildProgressBar(),

                const SizedBox(height: 15),

                _buildControlsRow(gold),

                const SizedBox(height: 10),

              ],

            )

          ],

        ),

      );

    }
  
  // ---- Vue de la liste de lecture (File d'attente) ----
  Widget _buildPlaylistView(BuildContext context, Color gold) {
    final playlist = _audio.playlistSources;
    if (playlist.isEmpty) {
      return const Center(child: Text("Aucune liste de lecture chargée.", style: TextStyle(color: Colors.white60)));
    }

    return StreamBuilder<int?>(
      stream: _audio.currentIndexStream,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data ?? 0;
        return ListView.builder(
          itemCount: playlist.length,
          itemBuilder: (context, index) {
            final surahId = (playlist[index] as UriAudioSource).tag as int;
            final surahName = surahFr[surahId] ?? "Sourate $surahId";
            final bool isPlaying = index == currentIndex;

            return ListTile(
              leading: isPlaying
                  ? Icon(Icons.volume_up, color: gold)
                  : Text("${index + 1}", style: TextStyle(color: Colors.white60, fontSize: 16)),
              title: Text(surahName, style: TextStyle(color: isPlaying ? gold : Colors.white, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
              onTap: () {
                _audio.seekToIndex(index);
              },
            );
          },
        );
      },
    );
  }

  // ---- Widgets réutilisables ----
  Widget _buildControlsRow(Color gold) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 42,
                onPressed: _audio.skipToPrevious,
              ),
              const SizedBox(width: 8),
              StreamBuilder<PlayerState>(
                stream: _audio.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;

                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 70,
                      height: 70,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }

                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    iconSize: 70,
                    onPressed: _audio.togglePlayPause,
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 42,
                onPressed: _audio.skipToNext,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<LoopMode>(
                valueListenable: _audio.loopModeNotifier,
                builder: (context, loopMode, _) {
                  return IconButton(
                    icon: Icon(
                      loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                      color: loopMode == LoopMode.off ? Colors.white70 : gold,
                    ),
                    iconSize: 28,
                    onPressed: _audio.cycleLoopMode,
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                iconSize: 28,
                onPressed: () => _openRiwayaPicker(_audio),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.person_search, color: Colors.white70),
                iconSize: 28,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    useSafeArea: true,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => ReciterSelectorSheet(
                      onSelected: (name, server) {
                        _audio.setReciter(name, server);
                        final id = _audio.currentSurahId;
                        if (id != null) _audio.loadPlaylistAndPlay(id);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds" : "$twoDigitMinutes:$twoDigitSeconds";
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
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              ),
              child: Slider(
                activeColor: gold,
                inactiveColor: Colors.white24,
                max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                onChanged: (value) => _audio.seek(Duration(milliseconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
