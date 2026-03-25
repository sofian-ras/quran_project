// lib/services/mp3quran/mp3quran_timing_cache.dart
//
// Cache mémoire des timings par (ReciterAudioSource, surah).
//
// Générique : fonctionne pour tout récitateur disposant d'un mp3quranReadId.
// Les versets avec ayah=0 (Basmalah introductive) sont filtrés automatiquement.
//
// Usage :
//   final timings = await Mp3QuranTimingCache.instance.getTimings(source, surah);
//   final timing  = await Mp3QuranTimingCache.instance.getAyahTiming(source, surah, 67);
//
// Debug (trouver les readIds) :
//   await Mp3QuranTimingCache.instance.logAvailableReads();

import 'package:flutter/foundation.dart';
import '../../models/ayah_timing.dart';
import '../../models/reciter_audio_source.dart';
import 'mp3quran_timing_api.dart';

class Mp3QuranTimingCache {
  Mp3QuranTimingCache._();
  static final Mp3QuranTimingCache instance = Mp3QuranTimingCache._();

  final _api = Mp3QuranTimingApi.instance;

  // Cache : localCacheId → surahNumber → timings
  final Map<String, Map<int, List<AyahTiming>>> _cache = {};

  // Cache des readIds résolus dynamiquement : localCacheId → readId
  final Map<String, int> _resolvedReadIds = {};
  // Future en cours pour éviter les requêtes parallèles
  final Map<String, Future<int>> _readIdFutures = {};

  // ── Résolution du readId ───────────────────────────────────────────────────

  /// Retourne le readId effectif pour une source.
  /// Si mp3quranReadId est connu → retourne directement.
  /// Sinon → auto-découverte via /reads en cherchant searchName + searchRewaya.
  Future<int> resolveReadId(ReciterAudioSource source) async {
    if (source.mp3quranReadId != null) return source.mp3quranReadId!;

    // Déjà résolu
    if (_resolvedReadIds.containsKey(source.localCacheId)) {
      return _resolvedReadIds[source.localCacheId]!;
    }

    // Éviter les requêtes parallèles pour la même source
    _readIdFutures[source.localCacheId] ??= _discoverReadId(source);
    try {
      final id = await _readIdFutures[source.localCacheId]!;
      _resolvedReadIds[source.localCacheId] = id;
      return id;
    } finally {
      _readIdFutures.remove(source.localCacheId);
    }
  }

  Future<int> _discoverReadId(ReciterAudioSource source) async {
    assert(source.searchName != null,
        '${source.localCacheId} : mp3quranReadId null sans searchName');

    final reads = await _api.fetchReads();
    debugPrint('Mp3QuranTimingCache: résolution readId pour ${source.localCacheId}');
    for (final r in reads) {
      debugPrint('  id=${r.id}  "${r.name}"  rewaya="${r.rewaya}"');
    }

    final name    = source.searchName!.toLowerCase();
    final rewaya  = source.searchRewaya?.toLowerCase() ?? '';

    final match = reads.firstWhere(
      (r) =>
          r.name.toLowerCase().contains(name) &&
          (rewaya.isEmpty || r.rewaya.toLowerCase().contains(rewaya)),
      orElse: () => throw StateError(
        'readId introuvable pour ${source.localCacheId} '
        '(searchName="${source.searchName}", searchRewaya="${source.searchRewaya}").\n'
        'IDs disponibles listés ci-dessus. Hardcoder mp3quranReadId dans ReciterAudioSource.',
      ),
    );

    debugPrint(
      'Mp3QuranTimingCache: readId résolu — '
      '${source.localCacheId} → ${match.id} ("${match.name} / ${match.rewaya}")',
    );
    return match.id;
  }

  // ── Timings ────────────────────────────────────────────────────────────────

  /// Retourne les timings pour un récitateur + sourate.
  /// Met en cache automatiquement. Filtre ayah=0.
  Future<List<AyahTiming>> getTimings(
    ReciterAudioSource source,
    int surah,
  ) async {
    assert(source.isConfigured,
        'mp3quranReadId non configuré pour ${source.localCacheId}');

    final surahMap = _cache[source.localCacheId] ??= {};
    if (surahMap.containsKey(surah)) return surahMap[surah]!;

    final readId = await resolveReadId(source);
    final all = await _api.fetchTimings(
      surah: surah,
      readId: readId,
    );

    final filtered = all.where((t) => t.ayah > 0).toList();
    surahMap[surah] = filtered;

    debugPrint(
      'Mp3QuranTimingCache: ${filtered.length} timings '
      'chargés pour ${source.localCacheId}/sourate $surah',
    );
    return filtered;
  }

  /// Retourne le timing d'un verset précis, ou null si introuvable.
  Future<AyahTiming?> getAyahTiming(
    ReciterAudioSource source,
    int surah,
    int ayah,
  ) async {
    final timings = await getTimings(source, surah);
    try {
      return timings.firstWhere((t) => t.ayah == ayah);
    } catch (_) {
      debugPrint(
        'Mp3QuranTimingCache: timing introuvable '
        '${source.localCacheId} S$surah:$ayah',
      );
      return null;
    }
  }

  /// Précharge les timings d'une sourate en arrière-plan.
  void prefetchTimings(ReciterAudioSource source, int surah) {
    if (!source.isConfigured) return;
    final already = _cache[source.localCacheId]?.containsKey(surah) ?? false;
    if (already) return;
    getTimings(source, surah).catchError((Object e) {
      debugPrint(
          'Mp3QuranTimingCache: prefetch ${source.localCacheId}/$surah — $e');
      return <AyahTiming>[];
    });
  }

  /// Invalide le cache pour un récitateur donné (utile en debug).
  void clearForSource(ReciterAudioSource source) {
    _cache.remove(source.localCacheId);
  }

  void clearAll() => _cache.clear();

  // ── Debug ──────────────────────────────────────────────────────────────────

  /// Affiche tous les reads disponibles dans les logs.
  /// Utiliser pour trouver les mp3quranReadId des récitateurs.
  Future<void> logAvailableReads() async {
    final reads = await _api.fetchReads();
    debugPrint('=== mp3quran reads disponibles (${reads.length}) ===');
    for (final r in reads) {
      debugPrint('  id=${r.id.toString().padLeft(4)}  '
          '"${r.name}"  rewaya="${r.rewaya}"');
    }
    debugPrint('=== fin ===');
  }
}
