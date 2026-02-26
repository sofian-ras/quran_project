// lib/services/mini_player_service.dart
//
// Service audio dédié au mini lecteur du reader screen.
// Indépendant de AudioService (qui sert le full player).
//
// Modes de lecture :
//   surah       — du verset sélectionné jusqu'à la fin de la sourate
//   verseByVerse — un verset, puis pause (l'utilisateur avance manuellement)
//   selection   — plage de versets sélectionnée (début → fin)
//
// Repeat : ×1 · ×2 · ×3 · ∞   (sur le verset en cours avant d'avancer)
// Audio  : everyayah.com  (fichiers par ayah)
// Persist: récitateur · mode · repeat  →  shared_preferences

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Modèles ──────────────────────────────────────────────────────────────────

class MiniReciter {
  final String name;
  final String folder; // dossier sur https://everyayah.com/data/
  const MiniReciter(this.name, this.folder);
}

enum MiniPlayMode { surah, verseByVerse, selection }

enum MiniRepeatMode { x1, x2, x3, infinite }

// ── Constantes ───────────────────────────────────────────────────────────────

const String _kEveryAyahBase = 'https://everyayah.com/data';

/// Nombre de versets par sourate (Hafs, index 0 = sourate 1).
const List<int> kSurahAyahCounts = [
  7,   286, 200, 176, 120, 165, 206, 75,  129, 109,
  123, 111, 43,  52,  99,  128, 111, 110, 98,  135,
  112, 78,  118, 64,  77,  227, 93,  88,  69,  60,
  34,  30,  73,  54,  45,  83,  182, 88,  75,  85,
  54,  53,  89,  59,  37,  35,  38,  29,  18,  45,
  60,  49,  62,  55,  78,  96,  29,  22,  24,  13,
  14,  11,  11,  18,  12,  12,  30,  52,  52,  44,
  28,  28,  20,  56,  40,  31,  50,  40,  46,  42,
  29,  19,  36,  25,  22,  17,  19,  26,  30,  20,
  15,  21,  11,  8,   8,   19,  5,   8,   8,   11,
  11,  8,   3,   9,   5,   4,   7,   3,   6,   3,
  5,   4,   5,   6,
];

const List<MiniReciter> kMiniReciters = [
  MiniReciter('Mishary Alafasy',        'Alafasy_128kbps'),
  MiniReciter('AbdulBasit Mujawwad',    'Abdul_Basit_Mujawwad_128kbps'),
  MiniReciter('AbdulBasit Murattal',    'Abdul_Basit_Murattal_192kbps'),
  MiniReciter('As-Sudais',              'Abdurrahmaan_As-Sudais_64kbps'),
  MiniReciter('Ash-Shuraym',            'Saood_ash-Shuraym_128kbps'),
  MiniReciter('Al-Hudhaify',            'Hudhaify_128kbps'),
  MiniReciter('Maher Al-Muaiqly',       'MaherAlMuaiqly128kbps'),
  MiniReciter('Mohamed Ayyoub',         'Muhammad_Ayyoub_128kbps'),
  MiniReciter('Mohamed Jibreel',        'Muhammad_Jibreel_128kbps'),
  MiniReciter('Nasser Al-Qatami',       'Nasser_Alqatami_128kbps'),
  MiniReciter('Yasser Ad-Dussary',      'Yasser_Ad-Dussary_128kbps'),
  MiniReciter('Al-Minshawy Murattal',   'Minshawy_Murattal_128kbps'),
  MiniReciter('Al-Minshawy Mujawwad',   'Minshawy_Mujawwad_128kbps'),
  MiniReciter('Ali Jaber',              'Ali_Jaber_64kbps'),
  MiniReciter('Abu Bakr Ash-Shaatree',  'Abu_Bakr_Ash-Shaatree_64kbps'),
  MiniReciter('Abdullah Basfar',        'Abdullah_Basfar_192kbps'),
  MiniReciter('Hani Arrifai',           'Hani_Rifai_64kbps'),
  MiniReciter('Al-Hussary Murattal',    'Husary_128kbps'),
  MiniReciter('Saad Al-Ghamdi',         'Ghamadi_40kbps'),
  MiniReciter('Ahmed Al-Ajmy',          'Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com'),
  MiniReciter('Abdullah Al-Juhany',     'Abdullaah_3awwaad_Al-Juhaynee_128kbps'),
];

// ── Service ───────────────────────────────────────────────────────────────────

class MiniPlayerService {
  MiniPlayerService._() {
    _init();
  }

  static final MiniPlayerService instance = MiniPlayerService._();

  // ── État public (ValueNotifiers) ──────────────────────────────────────────

  final ValueNotifier<bool> isPlaying    = ValueNotifier(false);
  final ValueNotifier<bool> isExpanded   = ValueNotifier(false);
  final ValueNotifier<bool> isLoading    = ValueNotifier(false);

  /// Clé du verset en cours : "surah:ayah" (ex : "2:255"), null si arrêté.
  final ValueNotifier<String?> currentAyahKey = ValueNotifier(null);

  final ValueNotifier<MiniPlayMode>   playMode    = ValueNotifier(MiniPlayMode.surah);
  final ValueNotifier<MiniRepeatMode> repeatMode  = ValueNotifier(MiniRepeatMode.x1);
  final ValueNotifier<MiniReciter>    currentReciter =
      ValueNotifier(kMiniReciters[0]);

  // ── Sélection ────────────────────────────────────────────────────────────

  String? selectionStartKey; // "surah:ayah"
  String? selectionEndKey;   // "surah:ayah"

  bool get hasSelectionStart => selectionStartKey != null && selectionEndKey == null;
  bool get hasFullSelection  => selectionStartKey != null && selectionEndKey != null;

  // ── Interne ───────────────────────────────────────────────────────────────

  final AudioPlayer _player = AudioPlayer();

  int  _curSurah    = 0;
  int  _curAyah     = 0;
  int  _endAyah     = 0;
  int  _repeatCount = 0;
  bool _stopping    = false;

  StreamSubscription<ProcessingState>? _processingStateSub;
  StreamSubscription<bool>?            _playingSub;

  // ── Init ──────────────────────────────────────────────────────────────────

  void _init() {
    _processingStateSub = _player.processingStateStream.listen((state) {
      isLoading.value =
          state == ProcessingState.loading || state == ProcessingState.buffering;
      if (state == ProcessingState.completed) {
        _onAyahCompleted();
      }
    });

    _playingSub = _player.playingStream.listen((playing) {
      if (currentAyahKey.value != null || !playing) {
        isPlaying.value = playing;
      }
    });

    _loadPrefs();
  }

  // ── URL ───────────────────────────────────────────────────────────────────

  String _ayahUrl(int surah, int ayah) {
    final folder = currentReciter.value.folder;
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$_kEveryAyahBase/$folder/$s$a.mp3';
  }

  // ── Calcul du dernier ayah selon le mode ──────────────────────────────────

  int _computeEndAyah(int surah, int startAyah) {
    switch (playMode.value) {
      case MiniPlayMode.surah:
        return kSurahAyahCounts[surah - 1];

      case MiniPlayMode.verseByVerse:
        return startAyah;

      case MiniPlayMode.selection:
        if (hasFullSelection) {
          final parts    = selectionEndKey!.split(':');
          final endSurah = int.parse(parts[0]);
          if (endSurah == surah) return int.parse(parts[1]);
        }
        return startAyah;
    }
  }

  // ── Lecture ───────────────────────────────────────────────────────────────

  /// Démarre la lecture à partir d'un verset donné.
  /// Respecte le [playMode] courant pour déterminer où s'arrêter.
  Future<void> playFrom({required int surah, required int ayah}) async {
    _stopping     = false;
    _repeatCount  = 0;
    _curSurah     = surah;
    _curAyah      = ayah;
    _endAyah      = _computeEndAyah(surah, ayah);
    isExpanded.value = true;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_stopping) return;
    final url = _ayahUrl(_curSurah, _curAyah);
    currentAyahKey.value = '$_curSurah:$_curAyah';
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint('MiniPlayerService: erreur $_curSurah:$_curAyah — $e');
    }
  }

  // ── Gestion de la fin d'un verset ────────────────────────────────────────

  void _onAyahCompleted() {
    if (_stopping) return;

    _repeatCount++;
    final limit = _repeatLimit;

    // Répéter si nécessaire (limit < 0 = infini)
    if (limit < 0 || _repeatCount < limit) {
      _player.seek(Duration.zero).then((_) {
        if (!_stopping) _player.play();
      });
      return;
    }

    // Fin de la répétition → avancer
    _repeatCount = 0;

    if (playMode.value == MiniPlayMode.verseByVerse) {
      // Mode V/V : s'arrête après chaque verset, attend l'action utilisateur
      isPlaying.value = false;
      return;
    }

    if (_curAyah < _endAyah) {
      _curAyah++;
      _playCurrent();
    } else {
      // Fin de la plage
      isPlaying.value = false;
    }
  }

  int get _repeatLimit {
    switch (repeatMode.value) {
      case MiniRepeatMode.x1:       return 1;
      case MiniRepeatMode.x2:       return 2;
      case MiniRepeatMode.x3:       return 3;
      case MiniRepeatMode.infinite: return -1;
    }
  }

  // ── Contrôles ─────────────────────────────────────────────────────────────

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    _stopping = true;
    await _player.stop();
    await _player.seek(Duration.zero);
    currentAyahKey.value = null;
    isExpanded.value     = false;
    isPlaying.value      = false;
    _curSurah   = 0;
    _curAyah    = 0;
    _endAyah    = 0;
    _repeatCount = 0;
  }

  Future<void> nextVerse() async {
    if (_curSurah == 0) return;
    final maxAyah = kSurahAyahCounts[_curSurah - 1];
    if (_curAyah < maxAyah) {
      _curAyah++;
      _repeatCount = 0;
      _endAyah     = _computeEndAyah(_curSurah, _curAyah);
      _stopping    = false;
      await _playCurrent();
    }
  }

  Future<void> prevVerse() async {
    if (_curSurah == 0) return;
    if (_curAyah > 1) {
      _curAyah--;
      _repeatCount = 0;
      _endAyah     = _computeEndAyah(_curSurah, _curAyah);
      _stopping    = false;
      await _playCurrent();
    }
  }

  void cycleMode() {
    final idx = playMode.value.index;
    playMode.value = MiniPlayMode.values[(idx + 1) % MiniPlayMode.values.length];
    if (_curSurah > 0) {
      _endAyah = _computeEndAyah(_curSurah, _curAyah);
    }
    _savePrefs();
  }

  void cycleRepeat() {
    final idx = repeatMode.value.index;
    repeatMode.value = MiniRepeatMode.values[(idx + 1) % MiniRepeatMode.values.length];
    _savePrefs();
  }

  void setReciter(MiniReciter reciter) {
    if (reciter.folder == currentReciter.value.folder) return;
    currentReciter.value = reciter;
    _savePrefs();
    if (currentAyahKey.value != null) {
      _repeatCount = 0;
      _playCurrent();
    }
  }

  // ── Sélection de plage ────────────────────────────────────────────────────

  void setSelectionStart(int surah, int ayah) {
    selectionStartKey = '$surah:$ayah';
    selectionEndKey   = null;
  }

  /// Définit la fin de plage. Si la sourate ne correspond pas au début,
  /// recommence une nouvelle sélection. Inverse début/fin si nécessaire.
  void setSelectionEnd(int surah, int ayah) {
    if (selectionStartKey == null) {
      selectionStartKey = '$surah:$ayah';
      return;
    }
    final startParts = selectionStartKey!.split(':');
    final startSurah = int.parse(startParts[0]);
    final startAyah  = int.parse(startParts[1]);

    if (startSurah != surah) {
      // Sourate différente : nouvelle sélection
      selectionStartKey = '$surah:$ayah';
      selectionEndKey   = null;
      return;
    }

    // Garantit l'ordre start ≤ end
    if (ayah < startAyah) {
      selectionEndKey   = selectionStartKey;
      selectionStartKey = '$surah:$ayah';
    } else {
      selectionEndKey = '$surah:$ayah';
    }
  }

  void clearSelection() {
    selectionStartKey = null;
    selectionEndKey   = null;
  }

  // ── Persistance ───────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final folder = prefs.getString('mini_reciter');
    if (folder != null) {
      final r = kMiniReciters.where((x) => x.folder == folder).firstOrNull;
      if (r != null) currentReciter.value = r;
    }

    final modeIdx = prefs.getInt('mini_mode') ?? 0;
    if (modeIdx < MiniPlayMode.values.length) {
      playMode.value = MiniPlayMode.values[modeIdx];
    }

    final repeatIdx = prefs.getInt('mini_repeat') ?? 0;
    if (repeatIdx < MiniRepeatMode.values.length) {
      repeatMode.value = MiniRepeatMode.values[repeatIdx];
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mini_reciter', currentReciter.value.folder);
    await prefs.setInt('mini_mode',   playMode.value.index);
    await prefs.setInt('mini_repeat', repeatMode.value.index);
  }

  void dispose() {
    _processingStateSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
  }
}
