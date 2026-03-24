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

    final all = await _api.fetchTimings(
      surah: surah,
      readId: source.mp3quranReadId!,
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
