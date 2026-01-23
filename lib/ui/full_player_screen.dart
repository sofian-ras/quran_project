import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../surah_name.dart';
import 'widgets/reciter_selector.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final AudioService _audio = AudioService.instance;

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
  Row _buildControlsRow(Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ValueListenableBuilder<LoopMode>(
          valueListenable: _audio.loopModeNotifier,
          builder: (context, loopMode, _) {
            return IconButton(
              icon: Icon(loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat, color: loopMode == LoopMode.off ? Colors.white70 : gold),
              iconSize: 28,
              onPressed: _audio.cycleLoopMode,
            );
          },
        ),
        IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), iconSize: 42, onPressed: _audio.skipToPrevious),
        StreamBuilder<PlayerState>(
          stream: _audio.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final isPlaying = playerState?.playing ?? false;
            final processingState = playerState?.processingState;
            if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
              return const SizedBox(width: 70, height: 70, child: Center(child: CircularProgressIndicator(color: Colors.white)));
            }
            return IconButton(
              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
              iconSize: 70,
              onPressed: _audio.togglePlayPause,
            );
          },
        ),
        IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), iconSize: 42, onPressed: _audio.skipToNext),
        IconButton(
          icon: const Icon(Icons.person_search, color: Colors.white70),
          iconSize: 28,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => ReciterSelectorSheet(onSelected: (name, server) {
                _audio.setReciter(name, server);
                final id = _audio.currentSurahId;
                if (id != null) _audio.loadPlaylistAndPlay(id);
              }),
            );
          },
        ),
      ],
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
