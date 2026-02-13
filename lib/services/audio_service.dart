import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../surah_name.dart';
import 'dart:async';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

/// Récitant "verset par verset" (EveryAyah)
class AyahReciter {
  final String name;
  final String folder; // dossier sur https://everyayah.com/data/<folder>/
  const AyahReciter(this.name, this.folder);
}

class AudioService {
  final ValueNotifier<bool> isFullPlayerOpenNotifier = ValueNotifier<bool>(false);

  AudioService._() {
    _player.setLoopMode(loopModeNotifier.value);
    _player.processingStateStream.listen((state) {
      isBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });

    // Écouter les changements de piste (lecture sourate complète)
    _currentIndexSub = _player.currentIndexStream.listen((index) {
      final int? surahId = index == null ? null : index + 1;
      currentPlayingSurahIdNotifier.value = surahId;
      if (surahId != null) {
        currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      }
    });

    // Buffering pour le player "verset par verset"
    _ayahPlayer.processingStateStream.listen((state) {
      isAyahBuffering.value = state == ProcessingState.buffering || state == ProcessingState.loading;
    });
  }

  static final AudioService instance = AudioService._();

  // =======================
  //  A) Sourate complète
  // =======================
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool _audioSourceReady = false;

  final ValueNotifier<int?> currentPlayingSurahIdNotifier = ValueNotifier<int?>(null);
  StreamSubscription<int?>? _currentIndexSub;

  final ValueNotifier<String> currentTitleNotifier = ValueNotifier("Aucune lecture");
  final ValueNotifier<String> currentReciterNotifier = ValueNotifier("Abdelrashid as-Soufy");
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> isShuffleEnabled = ValueNotifier(false);

  String get currentTitle => currentTitleNotifier.value;
  String get currentReciterName => currentReciterNotifier.value;
  int? get currentSurahId => _player.currentIndex == null ? null : _player.currentIndex! + 1;
  List<AudioSource> get playlistSources => _playlist?.children ?? [];
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  // Serveur par défaut mp3quran.net (lecture sourate complète)
  String currentServer = "https://server16.mp3quran.net/download/soufi/Rewayat-Hafs-A-n-Assem";

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get isActiveStream => _player.processingStateStream.map((state) => state != ProcessingState.idle);

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      ).asBroadcastStream();

  // 1) changer récitant (sourate complète) + invalider playlist
  void setReciter(String name, String server) {
    if (currentReciterNotifier.value != name || currentServer != server) {
      currentReciterNotifier.value = name;
      currentServer = server;
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  Future<void> loadPlaylistAndPlay(int surahId) async {
    try {
      if (_playlist == null) {
        _playlist = _createPlaylist();
        _audioSourceReady = false;
      }

      currentTitleNotifier.value = surahFr[surahId] ?? 'Sourate $surahId';
      final targetIndex = surahId - 1;

      if (!_audioSourceReady || _player.audioSource == null) {
        await _player.setAudioSource(_playlist!, initialIndex: targetIndex);
        _audioSourceReady = true;
      } else {
        await _player.seek(Duration.zero, index: targetIndex);
      }

      play();
    } catch (e) {
      debugPrint("Erreur lors du chargement de la playlist: $e");
      _playlist = null;
      _audioSourceReady = false;
    }
  }

  ConcatenatingAudioSource _createPlaylist() {
    final List<AudioSource> sources = [];
    for (int i = 1; i <= 114; i++) {
      final surahNum = i.toString().padLeft(3, '0');
      final url = '$currentServer/$surahNum.mp3';
      sources.add(AudioSource.uri(Uri.parse(url), tag: i));
    }
    return ConcatenatingAudioSource(children: sources);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToIndex(int index) => _player.seek(Duration.zero, index: index);

  Future<void> skipToPrevious() => _player.seekToPrevious();
  Future<void> skipToNext() => _player.seekToNext();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void cycleLoopMode() {
    final currentMode = loopModeNotifier.value;
    LoopMode newMode;
    if (currentMode == LoopMode.off) {
      newMode = LoopMode.one;
    } else if (currentMode == LoopMode.one) {
      newMode = LoopMode.all;
    } else {
      newMode = LoopMode.off;
    }
    loopModeNotifier.value = newMode;
    _player.setLoopMode(newMode);
  }

  Future<void> toggleShuffle() async {
    final newShuffleState = !isShuffleEnabled.value;
    isShuffleEnabled.value = newShuffleState;
    await _player.setShuffleModeEnabled(newShuffleState);
  }

  // =======================
  //  B) Verset par verset
  // =======================
  static const String _everyAyahBase = 'https://everyayah.com/data';

  /// Liste simple (tu peux en ajouter) — dossiers confirmés via /data :contentReference[oaicite:4]{index=4}
  static const List<AyahReciter> ayahReciters = [
    AyahReciter('Mishary Alafasy (128kbps)', 'Alafasy_128kbps'),
    AyahReciter('AbdulBasit Mujawwad (128kbps)', 'Abdul_Basit_Mujawwad_128kbps'),
    AyahReciter('Saood Ash-Shuraym (128kbps)', 'Saood_ash-Shuraym_128kbps'),
    AyahReciter('As-Sudais (64kbps)', 'Abdurrahmaan_As-Sudais_64kbps'),
    AyahReciter('Al-Hudhaify (128kbps)', 'Hudhaify_128kbps'),
    AyahReciter('Ali Jaber (64kbps)', 'Ali_Jaber_64kbps'),
    AyahReciter('Abu Bakr Ash-Shaatree (64kbps)', 'Abu_Bakr_Ash-Shaatree_64kbps'),
    AyahReciter('Ahmad Al-Ajmy (64kbps)', 'Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com'),
    AyahReciter('Nasser Alqatami (128kbps)', 'Nasser_Alqatami_128kbps'),
    AyahReciter('Abdullah Al-Juhany (128kbps)', 'Abdullaah_3awwaad_Al-Juhaynee_128kbps'),
    AyahReciter('Maher Al-Muaiqly (128kbps)', 'MaherAlMuaiqly128kbps'),
    AyahReciter('Saad Al-Ghamdi (40kbps)', 'Ghamadi_40kbps'),
    AyahReciter('Hani Arrifai (64kbps)', 'Hani_Rifai_64kbps'),
    AyahReciter('Al-Hussary (128kbps)', 'Husary_128kbps'),
  ];

  final ValueNotifier<AyahReciter> currentAyahReciterNotifier =
      ValueNotifier<AyahReciter>(ayahReciters[0]);

  final AudioPlayer _ayahPlayer = AudioPlayer();
  final ValueNotifier<bool> isAyahBuffering = ValueNotifier(false);
  final ValueNotifier<String> currentAyahTitleNotifier = ValueNotifier("Aucun verset");

  Stream<PlayerState> get ayahPlayerStateStream => _ayahPlayer.playerStateStream;

  Stream<PositionData> get ayahPositionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _ayahPlayer.positionStream,
        _ayahPlayer.bufferedPositionStream,
        _ayahPlayer.durationStream,
        (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      ).asBroadcastStream();

  Stream<bool> get isAyahActiveStream =>
      _ayahPlayer.processingStateStream.map((state) => state != ProcessingState.idle);

  String _ayahFile(int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$s$a.mp3'; // ex: 001001.mp3
  }

  String _ayahUrl(int surah, int ayah) {
    final folder = currentAyahReciterNotifier.value.folder;
    return '$_everyAyahBase/$folder/${_ayahFile(surah, ayah)}';
  }

  void setAyahReciter(AyahReciter reciter) {
    currentAyahReciterNotifier.value = reciter;
  }

  StreamSubscription<PlayerState>? _ayahSeqSub;
  int? _seqSurah;
  int? _seqAyah;
  int? _seqEndAyah;

  /// Lecture d’un seul verset
  Future<void> playAyah(int surah, int ayah) async {
    // stop séquence si en cours
    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;
    _seqSurah = null;
    _seqAyah = null;
    _seqEndAyah = null;

    final url = _ayahUrl(surah, ayah);

    currentAyahTitleNotifier.value =
        'S${surah.toString().padLeft(3, '0')}:${ayah.toString().padLeft(3, '0')} • ${currentAyahReciterNotifier.value.name}';

    try {
      await _ayahPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _ayahPlayer.play();
    } catch (e) {
      debugPrint("Erreur lecture ayah ($surah:$ayah) : $e");
      rethrow;
    }
  }

  /// Lecture verset par verset (range) : ex 1..7
  Future<void> playAyahRange({
    required int surah,
    required int startAyah,
    required int endAyah,
  }) async {
    if (endAyah < startAyah) return;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    _seqSurah = surah;
    _seqAyah = startAyah;
    _seqEndAyah = endAyah;

    await playAyah(surah, startAyah);

    _ayahSeqSub = _ayahPlayer.playerStateStream.listen((st) async {
      if (st.processingState == ProcessingState.completed) {
        if (_seqSurah == null || _seqAyah == null || _seqEndAyah == null) return;
        final next = (_seqAyah ?? startAyah) + 1;
        if (next > (_seqEndAyah ?? endAyah)) {
          await _ayahSeqSub?.cancel();
          _ayahSeqSub = null;
          _seqSurah = null;
          _seqAyah = null;
          _seqEndAyah = null;
          return;
        }
        _seqAyah = next;
        try {
          await playAyah(surah, next);
        } catch (_) {}
      }
    });
  }

  Future<void> stopAyah() async {
    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;
    _seqSurah = null;
    _seqAyah = null;
    _seqEndAyah = null;
    await _ayahPlayer.stop();
  }

  Future<void> dispose() async {
    await _currentIndexSub?.cancel();
    _currentIndexSub = null;

    await _ayahSeqSub?.cancel();
    _ayahSeqSub = null;

    await _player.dispose();
    await _ayahPlayer.dispose();
  }
}