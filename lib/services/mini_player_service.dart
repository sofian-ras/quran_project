// lib/services/mini_player_service.dart
//
// Service audio dédié au mini lecteur du reader screen.
// Indépendant de AudioService (qui sert le full player).
//
// Source audio : QUL (qul.tarteel.ai) via QulAudioResolver.
// Les URLs ne sont JAMAIS construites directement ici :
// elles sont résolues par QulAudioResolver → QulApiClient.
//
// Modes de lecture :
//   surah       — du verset sélectionné jusqu'à la fin de la sourate
//   verseByVerse — un verset, puis pause (l'utilisateur avance manuellement)
//   selection   — plage de versets sélectionnée (début → fin)
//
// Repeat : ×1 · ×2 · ×3 · ∞   (sur le verset en cours avant d'avancer)
// Persist: récitateur · mode · repeat → shared_preferences

import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qul_audio/models/qul_reciter.dart';
import 'qul_audio/qul_catalog_service.dart';
import 'qul_audio/qul_audio_resolver.dart';
import 'qul_audio/audio_download_manager.dart';
import 'qul_audio/audio_playback_source.dart';

// ── Modèle récitateur (compatibilité UI) ─────────────────────────────────────

class MiniReciter {
  final String name;
  /// Contient le qulId.toString() — utilisé comme clé d'identification.
  final String folder;
  /// Vrai si le récitateur est disponible sur le CDN QUL.
  final bool isAvailable;
  const MiniReciter(this.name, this.folder, {this.isAvailable = true});
}

enum MiniPlayMode { surah, verseByVerse, selection }

enum MiniRepeatMode { x1, x2, x3, infinite }

// ── Liste des récitateurs (depuis le catalogue QUL) ───────────────────────────

/// Convertit le catalogue QUL en liste MiniReciter pour l'UI.
/// Les récitateurs indisponibles sont marqués avec un suffixe.
final List<MiniReciter> kMiniReciters = QulCatalogService.reciters
    .where((r) => r.isAvailable)
    .map((r) => MiniReciter(r.displayName, r.qulId.toString()))
    .toList();

// ── Constantes ───────────────────────────────────────────────────────────────

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

// ── Service ───────────────────────────────────────────────────────────────────

class MiniPlayerService {
  MiniPlayerService._() { _init(); }
  static final MiniPlayerService instance = MiniPlayerService._();

  // ── État public (ValueNotifiers) ──────────────────────────────────────────

  final ValueNotifier<bool> isPlaying           = ValueNotifier(false);
  final ValueNotifier<bool> isExpanded          = ValueNotifier(false);
  final ValueNotifier<bool> isLoading           = ValueNotifier(false);

  /// Vrai pendant la transition automatique entre deux versets consécutifs
  /// (range/sourate). Permet à l'UI de ne pas afficher le spinner de
  /// chargement et de montrer à la place le bouton pause (la plage joue
  /// toujours conceptuellement).
  final ValueNotifier<bool> isRangeAutoAdvancing = ValueNotifier(false);

  /// Clé du verset en cours : "surah:ayah" (ex : "2:255"), null si arrêté.
  final ValueNotifier<String?> currentAyahKey = ValueNotifier(null);

  final ValueNotifier<MiniPlayMode>   playMode   = ValueNotifier(MiniPlayMode.surah);
  final ValueNotifier<MiniRepeatMode> repeatMode = ValueNotifier(MiniRepeatMode.x1);
  final ValueNotifier<MiniReciter>    currentReciter =
      ValueNotifier(kMiniReciters[0]);

  /// Message d'erreur affiché quand l'audio est indisponible sur QUL.
  final ValueNotifier<String?> unavailableMessage = ValueNotifier(null);

  // ── Sélection ─────────────────────────────────────────────────────────────

  String? selectionStartKey;
  String? selectionEndKey;

  bool get hasSelectionStart => selectionStartKey != null && selectionEndKey == null;
  bool get hasFullSelection  => selectionStartKey != null && selectionEndKey != null;

  // ── Interne ───────────────────────────────────────────────────────────────

  final AudioPlayer _player = AudioPlayer();

  int  _curSurah    = 0;
  int  _curAyah     = 0;
  int  _endAyah     = 0;
  int  _repeatCount = 0;
  bool _stopping    = false;

  // Génération courante — s'incrémente à chaque _playCurrent.
  // Permet d'annuler tout appel obsolète après un await.
  int _playToken = 0;

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

    // Capture les erreurs just_audio (ex: 403, cleartext http, timeout…)
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace _) {
        debugPrint('MiniPlayerService: playbackEventStream error: $e');
        unavailableMessage.value = 'Erreur audio : $e';
        isLoading.value = false;
        isPlaying.value = false;
      },
    );

    _configureAudioSession();
    _loadPrefs();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('MiniPlayerService: AudioSession config error: $e');
    }
  }

  // ── Récitateur courant (QulReciter) ───────────────────────────────────────

  QulReciter? get _qulReciter {
    final id = int.tryParse(currentReciter.value.folder);
    return id != null ? QulCatalogService.instance.findByQulId(id) : null;
  }

  // ── Calcul du dernier ayah selon le mode ─────────────────────────────────

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

  Future<void> playFrom({required int surah, required int ayah}) async {
    _stopping    = false;
    _repeatCount = 0;
    isRangeAutoAdvancing.value = false;
    unavailableMessage.value = null;

    if (playMode.value == MiniPlayMode.selection && hasFullSelection) {
      final parts = selectionStartKey!.split(':');
      _curSurah = int.parse(parts[0]);
      _curAyah  = int.parse(parts[1]);
    } else {
      _curSurah = surah;
      _curAyah  = ayah;
    }

    _endAyah = _computeEndAyah(_curSurah, _curAyah);
    isExpanded.value = true;

    // Précharger les URLs du chapitre en arrière-plan pour éviter la latence
    final reciter = _qulReciter;
    if (reciter != null) {
      QulAudioResolver.instance.prefetch(reciter, _curSurah);
    }

    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_stopping) {
      isRangeAutoAdvancing.value = false;
      return;
    }

    final myToken = ++_playToken;

    final reciter = _qulReciter;
    if (reciter == null) {
      isRangeAutoAdvancing.value = false;
      unavailableMessage.value = 'Récitateur introuvable';
      return;
    }

    // Résolution via QulAudioResolver (source unique : QUL)
    final source = await AudioPlaybackSource.instance.forAyah(
      reciter, _curSurah, _curAyah,
    );

    // Un appel plus récent a démarré → abandonner celui-ci.
    if (myToken != _playToken || _stopping) {
      isRangeAutoAdvancing.value = false;
      return;
    }

    if (source == null) {
      isRangeAutoAdvancing.value = false;
      unavailableMessage.value =
          '${reciter.name} : audio indisponible sur QUL pour $_curSurah:$_curAyah';
      debugPrint('MiniPlayerService: indisponible $_curSurah:$_curAyah');
      isLoading.value  = false;
      isPlaying.value  = false;
      currentAyahKey.value = null;
      return;
    }

    unavailableMessage.value = null;
    currentAyahKey.value = '$_curSurah:$_curAyah';
    try {
      // Stop uniquement si le player est en train de charger/lire.
      // Si déjà en completed/idle (verset terminé naturellement), on saute
      // le stop() pour ne pas ajouter de délai inutile entre les versets.
      final ps = _player.processingState;
      if (ps != ProcessingState.completed && ps != ProcessingState.idle) {
        await _player.stop();
        if (myToken != _playToken) {
          isRangeAutoAdvancing.value = false;
          return;
        }
      }

      // just_audio_background exige un MediaItem tag sur chaque AudioSource.
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(source.url),
          tag: MediaItem(
            id: '$_curSurah:$_curAyah',
            title: 'Sourate $_curSurah · Verset $_curAyah',
            artist: reciter.displayName,
            album: 'Coran',
          ),
        ),
      );
      if (myToken != _playToken) {
        isRangeAutoAdvancing.value = false;
        return;
      }

      await _player.play();
      // La lecture a démarré : l'auto-transition est terminée.
      isRangeAutoAdvancing.value = false;

      // Précharger l'URL du verset suivant en arrière-plan pendant que
      // le courant joue, pour réduire la latence au passage au suivant.
      _prefetchNextSource(reciter);
    } catch (e) {
      isRangeAutoAdvancing.value = false;
      debugPrint('MiniPlayerService: erreur $_curSurah:$_curAyah — $e');
      unavailableMessage.value = 'Erreur lecture : $e';
      isLoading.value = false;
      isPlaying.value = false;
    }
  }

  /// Résout et met en cache l'URL du verset suivant de façon silencieuse.
  void _prefetchNextSource(QulReciter reciter) {
    final next = _curAyah + 1;
    if (next > _endAyah) return;
    // Fire-and-forget : on ne bloque pas la lecture courante
    AudioPlaybackSource.instance.forAyah(reciter, _curSurah, next);
  }

  // ── Gestion de la fin d'un verset ─────────────────────────────────────────

  void _onAyahCompleted() {
    if (_stopping) return;

    _repeatCount++;
    final limit = _repeatLimit;

    if (limit < 0 || _repeatCount < limit) {
      _player.seek(Duration.zero).then((_) {
        if (!_stopping) _player.play();
      });
      return;
    }

    _repeatCount = 0;

    if (playMode.value == MiniPlayMode.verseByVerse) {
      isPlaying.value = false;
      return;
    }

    if (_curAyah < _endAyah) {
      _curAyah++;
      // Signale à l'UI qu'on passe automatiquement au verset suivant :
      // ne pas afficher le spinner de chargement pendant cette transition.
      isRangeAutoAdvancing.value = true;
      _playCurrent();
    } else {
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

  // ── Contrôles ──────────────────────────────────────────────────────────────

  Future<void> playPause() async {
    // Si aucune source chargée, (re)lancer le verset courant
    if (currentAyahKey.value == null) {
      if (_curSurah > 0 && _curAyah > 0) {
        _stopping = false;
        await _playCurrent();
      }
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    _stopping = true;
    _playToken++; // Invalide tout _playCurrent en cours d'attente async.
    isRangeAutoAdvancing.value = false;
    await _player.stop();
    await _player.seek(Duration.zero);
    currentAyahKey.value     = null;
    isExpanded.value         = false;
    isPlaying.value          = false;
    unavailableMessage.value = null;
    _curSurah    = 0;
    _curAyah     = 0;
    _endAyah     = 0;
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
    currentReciter.value     = reciter;
    unavailableMessage.value = null;
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

  void setSelectionEnd(int surah, int ayah) {
    if (selectionStartKey == null) {
      selectionStartKey = '$surah:$ayah';
      return;
    }
    final startParts = selectionStartKey!.split(':');
    final startSurah = int.parse(startParts[0]);
    final startAyah  = int.parse(startParts[1]);

    if (startSurah != surah) {
      selectionStartKey = '$surah:$ayah';
      selectionEndKey   = null;
      return;
    }

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

  // ── Download ──────────────────────────────────────────────────────────────

  /// Clé de téléchargement pour le contenu courant.
  String? get currentDownloadKey {
    final r = _qulReciter;
    if (r?.quranComId == null || currentAyahKey.value == null) return null;
    final qid = r!.quranComId!;
    if (playMode.value == MiniPlayMode.verseByVerse) {
      return AudioDownloadManager.ayahKey(qid, _curSurah, _curAyah);
    }
    return AudioDownloadManager.surahKey(qid, _curSurah);
  }

  /// Lance le téléchargement du contenu courant (verset ou sourate selon mode).
  Future<void> downloadCurrent() async {
    final r = _qulReciter;
    if (r?.quranComId == null || currentAyahKey.value == null) return;

    if (playMode.value == MiniPlayMode.verseByVerse) {
      final url = await QulAudioResolver.instance.resolveAyah(r!, _curSurah, _curAyah);
      if (url == null) return;
      await AudioDownloadManager.instance.downloadAyah(
        quranComId: r.quranComId!,
        surah: _curSurah,
        ayah:  _curAyah,
        url:   url,
      );
    } else {
      final url = await QulAudioResolver.instance.resolveSurah(r!, _curSurah);
      if (url == null) return;
      await AudioDownloadManager.instance.downloadSurah(
        quranComId: r.quranComId!,
        surah: _curSurah,
        url:   url,
      );
    }
  }

  void cancelCurrentDownload() {
    final key = currentDownloadKey;
    if (key != null) AudioDownloadManager.instance.cancel(key);
  }

  Future<void> deleteCurrentDownload() async {
    final key = currentDownloadKey;
    if (key != null) await AudioDownloadManager.instance.delete(key);
  }

  // ── Persistance ───────────────────────────────────────────────────────────
  // Clé v2 pour éviter un conflit avec l'ancienne valeur (dossier everyayah).

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final qulIdStr = prefs.getString('mini_reciter_qul_v1');
    if (qulIdStr != null) {
      final r = kMiniReciters.where((x) => x.folder == qulIdStr).firstOrNull;
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
    await prefs.setString('mini_reciter_qul_v1', currentReciter.value.folder);
    await prefs.setInt('mini_mode',   playMode.value.index);
    await prefs.setInt('mini_repeat', repeatMode.value.index);
  }

  void dispose() {
    _processingStateSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
  }
}
