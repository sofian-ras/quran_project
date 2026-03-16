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
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// Progression du pré-téléchargement de la sourate : null = inactif, 0.0–1.0 = en cours.
  final ValueNotifier<double?> prepProgress = ValueNotifier(null);
  int _prepToken = 0;

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
  StreamSubscription<int?>?            _indexSub;
  StreamSubscription<dynamic>?         _playbackErrorSub;

  // Non-null en mode playlist (surah/selection) : index playlist → numéro d'ayah.
  // Null en mode source unique (verseByVerse).
  List<int>? _playlistAyahs;

  // ── Init ──────────────────────────────────────────────────────────────────

  void _init() {
    _processingStateSub = _player.processingStateStream.listen((state) {
      isLoading.value =
          state == ProcessingState.loading || state == ProcessingState.buffering;
      if (state == ProcessingState.completed) {
        _onAyahCompleted();
      }
      // En mode playlist, la piste suivante est prête → fin de la micro-transition
      if (state == ProcessingState.ready && _playlistAyahs != null) {
        isRangeAutoAdvancing.value = false;
      }
    });

    _playingSub = _player.playingStream.listen((playing) {
      if (currentAyahKey.value != null || !playing) {
        isPlaying.value = playing;
      }
    });

    // Capture les erreurs just_audio (ex: 403, cleartext http, timeout…)
    _playbackErrorSub = _player.playbackEventStream.listen(
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

    final reciter = _qulReciter;
    if (reciter == null) {
      unavailableMessage.value = 'Récitateur introuvable';
      return;
    }

    // verseByVerse : un seul verset → streaming direct, pas de pré-téléchargement
    if (playMode.value == MiniPlayMode.verseByVerse) {
      QulAudioResolver.instance.prefetch(reciter, _curSurah);
      await _playCurrent();
      return;
    }

    // surah / selection : pré-télécharger tous les versets avant de lire
    await _prepareAndPlay(reciter, _curSurah, _curAyah);
  }

  // ── Pré-téléchargement ────────────────────────────────────────────────────

  /// Vérifie si tous les versets d'une sourate sont déjà en cache local.
  bool _allAyahsDownloaded(int qid, int surah, int total) {
    final mgr = AudioDownloadManager.instance;
    for (int i = 1; i <= total; i++) {
      if (!mgr.isDownloaded(AudioDownloadManager.ayahKey(qid, surah, i))) {
        return false;
      }
    }
    return true;
  }

  /// Télécharge tous les versets manquants de la sourate (lots de 5 en parallèle),
  /// affiche la progression dans [prepProgress], puis lance [_playCurrent].
  Future<void> _prepareAndPlay(QulReciter reciter, int surah, int startAyah) async {
    final qid   = reciter.quranComId;
    if (qid == null) {
      // Récitateur sans ID quran.com → streaming direct
      await _playCurrent();
      return;
    }

    final myToken = ++_prepToken;
    final total   = kSurahAyahCounts[surah - 1];
    final mgr     = AudioDownloadManager.instance;

    // Si tout est déjà téléchargé → lecture immédiate
    if (_allAyahsDownloaded(qid, surah, total)) {
      prepProgress.value = null;
      if (myToken == _prepToken && !_stopping) await _playCurrent();
      return;
    }

    // Précharger toutes les URLs en un seul appel API
    prepProgress.value = 0.0;
    await QulAudioResolver.instance.prefetch(reciter, surah);
    if (myToken != _prepToken) { prepProgress.value = null; return; }

    // Collecter les versets manquants
    final pending = <int>[];
    int done = 0;
    for (int i = 1; i <= total; i++) {
      if (mgr.isDownloaded(AudioDownloadManager.ayahKey(qid, surah, i))) {
        done++;
      } else {
        pending.add(i);
      }
    }
    prepProgress.value = done / total;

    // Téléchargement par lots de 5 en parallèle
    const batchSize = 5;
    for (int i = 0; i < pending.length; i += batchSize) {
      if (myToken != _prepToken) { prepProgress.value = null; return; }

      final batch = pending.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((ayah) async {
        final url = await QulAudioResolver.instance.resolveAyah(reciter, surah, ayah);
        if (url != null && myToken == _prepToken) {
          await mgr.downloadAyah(quranComId: qid, surah: surah, ayah: ayah, url: url);
        }
      }));

      done += batch.length;
      if (myToken == _prepToken) {
        prepProgress.value = (done / total).clamp(0.0, 1.0);
      }
    }

    if (myToken != _prepToken) { prepProgress.value = null; return; }
    prepProgress.value = null;
    if (!_stopping) await _startPlaylistMode(reciter, surah, startAyah);
  }

  /// Annule le pré-téléchargement en cours et replie le mini lecteur.
  void cancelPrep() {
    ++_prepToken;
    prepProgress.value = null;
    isExpanded.value   = false;
  }

  // ── Playlist gapless (surah / selection) ─────────────────────────────────

  /// Construit un [ConcatenatingAudioSource] à partir des fichiers locaux
  /// et lance la lecture. just_audio gère les transitions sans coupure entre
  /// les versets — aucun stop()/setAudioSource() entre chaque piste.
  Future<void> _startPlaylistMode(
      QulReciter reciter, int surah, int startAyah) async {
    final qid = reciter.quranComId!;
    final mgr = AudioDownloadManager.instance;

    // Chemin de base des fichiers (mirrors AudioDownloadManager._baseDir())
    final docs       = await getApplicationDocumentsDirectory();
    final reciterDir = p.join(docs.path, 'qul_audio', qid.toString());

    // Facteur de répétition par verset
    final isInfinite = repeatMode.value == MiniRepeatMode.infinite;
    final factor     = switch (repeatMode.value) {
      MiniRepeatMode.x1       => 1,
      MiniRepeatMode.x2       => 2,
      MiniRepeatMode.x3       => 3,
      MiniRepeatMode.infinite => 1, // géré par LoopMode.one
    };

    // Construire la playlist de startAyah → _endAyah
    final sources = <AudioSource>[];
    _playlistAyahs = [];

    for (int ayah = startAyah; ayah <= _endAyah; ayah++) {
      final key  = AudioDownloadManager.ayahKey(qid, surah, ayah);
      final path = p.join(reciterDir, '${surah}_$ayah.mp3');
      // Utilise le fichier local si disponible
      if (!mgr.isDownloaded(key) || !await File(path).exists()) continue;

      for (int r = 0; r < factor; r++) {
        sources.add(AudioSource.uri(
          Uri.file(path),
          tag: MediaItem(
            id:     '$surah:$ayah:$r',
            title:  'Sourate $surah · Verset $ayah',
            artist: reciter.displayName,
            album:  'Coran',
          ),
        ));
        _playlistAyahs!.add(ayah);
      }
    }

    if (sources.isEmpty) {
      _clearPlaylist();
      unavailableMessage.value = '${reciter.name} : audio introuvable';
      return;
    }

    // Suivi du verset courant via l'index playlist
    _indexSub?.cancel();
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null || _playlistAyahs == null) return;
      if (idx < _playlistAyahs!.length) {
        final ayah = _playlistAyahs![idx];
        if (ayah != _curAyah) {
          _curAyah             = ayah;
          currentAyahKey.value = '$_curSurah:$ayah';
          // Micro-transition entre pistes → masquer le spinner
          isRangeAutoAdvancing.value = true;
        }
      }
    });

    // Mode de boucle : ∞ répète la piste courante, sinon lecture unique
    await _player.setLoopMode(isInfinite ? LoopMode.one : LoopMode.off);

    unavailableMessage.value = null;
    currentAyahKey.value     = '$surah:$startAyah';
    _curAyah                 = startAyah;

    await _player.setAudioSource(
      ConcatenatingAudioSource(useLazyPreparation: true, children: sources),
      initialIndex:    0,
      initialPosition: Duration.zero,
    );
    await _player.play();
  }

  /// Libère les ressources du mode playlist.
  void _clearPlaylist() {
    _indexSub?.cancel();
    _indexSub      = null;
    _playlistAyahs = null;
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

    // Mode playlist (surah/selection) : la playlist entière est terminée.
    if (_playlistAyahs != null) {
      _clearPlaylist();
      isPlaying.value            = false;
      isRangeAutoAdvancing.value = false;
      return;
    }

    // Mode source unique (verseByVerse) : gestion repeat + arrêt.
    _repeatCount++;
    final limit = _repeatLimit;

    if (limit < 0 || _repeatCount < limit) {
      _player.seek(Duration.zero).then((_) {
        if (!_stopping) _player.play();
      });
      return;
    }

    _repeatCount    = 0;
    isPlaying.value = false;
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
    if (prepProgress.value != null) return; // Préparation en cours → ignorer

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
    ++_prepToken;             // Annule tout pré-téléchargement en cours.
    prepProgress.value = null;
    _clearPlaylist();         // Arrête le suivi de l'index playlist.
    _stopping = true;
    _playToken++;
    isRangeAutoAdvancing.value = false;
    await _player.setLoopMode(LoopMode.off);
    await _player.stop();
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
    if (_curAyah >= maxAyah) return;

    if (_playlistAyahs != null) {
      // Mode playlist : seek vers la première occurrence du verset suivant
      final idx = _playlistAyahs!.indexOf(_curAyah + 1);
      if (idx >= 0) {
        _repeatCount = 0;
        await _player.seek(Duration.zero, index: idx);
        if (!_player.playing) await _player.play();
      }
      return;
    }

    _curAyah++;
    _repeatCount = 0;
    _endAyah     = _computeEndAyah(_curSurah, _curAyah);
    _stopping    = false;
    await _playCurrent();
  }

  Future<void> prevVerse() async {
    if (_curSurah == 0 || _curAyah <= 1) return;

    if (_playlistAyahs != null) {
      final idx = _playlistAyahs!.indexOf(_curAyah - 1);
      if (idx >= 0) {
        _repeatCount = 0;
        await _player.seek(Duration.zero, index: idx);
        if (!_player.playing) await _player.play();
      }
      return;
    }

    _curAyah--;
    _repeatCount = 0;
    _endAyah     = _computeEndAyah(_curSurah, _curAyah);
    _stopping    = false;
    await _playCurrent();
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
    if (_curSurah > 0 && _curAyah > 0) {
      _repeatCount = 0;
      _clearPlaylist();
      // Relance la préparation depuis le verset courant avec le nouveau récitateur
      playFrom(surah: _curSurah, ayah: _curAyah);
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
    _indexSub?.cancel();
    _playbackErrorSub?.cancel();
    _player.dispose();
  }
}
