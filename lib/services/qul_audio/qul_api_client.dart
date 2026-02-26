// lib/services/qul_audio/qul_api_client.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// COUCHE D'HYPOTHÈSE — QUL Audio API
// ─────────────────────────────────────────────────────────────────────────────
// Source audio : QUL (qul.tarteel.ai) est alimenté par le CDN Quran.com.
//
// API de résolution des URLs (source unique) :
//   https://api.quran.com/api/v4/recitations/{quranComId}/by_chapter/{surah}
//   → retourne les URLs exactes pour chaque verset de la sourate.
//
//   https://api.quran.com/api/v4/chapter_recitations/{quranComId}/{surah}
//   → retourne l'URL du fichier audio de la sourate complète (si dispo).
//
// CDN audio (gérés par Quran.com / Tarteel, écosystème QUL) :
//   • https://verses.quran.com/{slug}/mp3/{S:3}{A:3}.mp3
//   • https://mirrors.quranicaudio.com/everyayah/{slug}/{S:3}{A:3}.mp3
//
// L'URL renvoyée par l'API est normalisée avant usage.
//
// Si un récitateur n'a pas de quranComId → résolution retourne null → indisponible.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class QulApiClient {
  QulApiClient._();
  static final QulApiClient instance = QulApiClient._();

  static const String _base = 'https://api.quran.com/api/v4';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // ── Caches ────────────────────────────────────────────────────────────────

  /// Cache verset : quranComId → surah → ayah → URL absolue
  final Map<int, Map<int, Map<int, String>>> _ayahCache = {};

  /// Cache sourate : quranComId → surah → URL absolue
  final Map<int, Map<int, String>> _surahCache = {};

  /// Récitateurs marqués indisponibles (404 sur l'API)
  final Set<int> _unavailable = {};

  // ── Résolution verset ─────────────────────────────────────────────────────

  /// Retourne l'URL audio du verset, ou null si indisponible sur QUL.
  Future<String?> resolveAyahUrl(int quranComId, int surah, int ayah) async {
    if (_unavailable.contains(quranComId)) return null;

    // Cache hit
    final hit = _ayahCache[quranComId]?[surah]?[ayah];
    if (hit != null) return hit;

    // Charger toute la sourate en une seule requête
    await _fetchChapter(quranComId, surah);
    return _ayahCache[quranComId]?[surah]?[ayah];
  }

  // ── Résolution sourate ────────────────────────────────────────────────────

  /// Retourne l'URL audio de la sourate complète, ou null si indisponible.
  Future<String?> resolveSurahUrl(int quranComId, int surah) async {
    if (_unavailable.contains(quranComId)) return null;

    final hit = _surahCache[quranComId]?[surah];
    if (hit != null) return hit;

    try {
      final resp = await _dio.get(
        '$_base/chapter_recitations/$quranComId/$surah',
      );
      final data = resp.data as Map<String, dynamic>;
      final audioFile = data['audio_file'] as Map<String, dynamic>?;
      final raw = audioFile?['audio_url'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final url = _normalize(raw);
        (_surahCache[quranComId] ??= {})[surah] = url;
        return url;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('QulApiClient: sourate indispo ($quranComId/$surah) — 404');
      } else {
        debugPrint('QulApiClient: erreur réseau sourate ($quranComId/$surah) — $e');
      }
    } catch (e) {
      debugPrint('QulApiClient: erreur inattendue sourate ($quranComId/$surah) — $e');
    }
    return null;
  }

  // ── Préchargement ─────────────────────────────────────────────────────────

  /// Précharge en cache toutes les URLs d'une sourate (évite la latence sur
  /// le premier verset joué). Appel idempotent.
  Future<void> prefetchChapter(int quranComId, int surah) async {
    if (_unavailable.contains(quranComId)) return;
    if (_ayahCache[quranComId]?.containsKey(surah) == true) return;
    await _fetchChapter(quranComId, surah);
  }

  // ── Interne ───────────────────────────────────────────────────────────────

  Future<void> _fetchChapter(int quranComId, int surah) async {
    try {
      final resp = await _dio.get(
        '$_base/recitations/$quranComId/by_chapter/$surah',
      );
      final data  = resp.data as Map<String, dynamic>;
      final files = data['audio_files'] as List<dynamic>?;

      if (files == null || files.isEmpty) {
        _unavailable.add(quranComId);
        debugPrint('QulApiClient: aucun fichier pour ($quranComId/$surah)');
        return;
      }

      final map = <int, String>{};
      for (final f in files) {
        final item = f as Map<String, dynamic>;
        final key  = item['verse_key'] as String; // ex: "2:255"
        final raw  = item['url'] as String;
        final parts = key.split(':');
        if (parts.length == 2) {
          final ayah = int.tryParse(parts[1]);
          if (ayah != null) map[ayah] = _normalize(raw);
        }
      }

      (_ayahCache[quranComId] ??= {})[surah] = map;
      debugPrint('QulApiClient: ${map.length} versets chargés pour ($quranComId/$surah)');

    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _unavailable.add(quranComId);
        debugPrint('QulApiClient: récitateur $quranComId introuvable sur QUL (404)');
      } else {
        debugPrint('QulApiClient: erreur réseau ($quranComId/$surah) — $e');
      }
    } catch (e) {
      debugPrint('QulApiClient: erreur inattendue ($quranComId/$surah) — $e');
    }
  }

  /// Normalise une URL relative / protocol-relative en URL absolue HTTPS.
  ///   "Alafasy/mp3/001001.mp3"        → "https://verses.quran.com/Alafasy/mp3/001001.mp3"
  ///   "//mirrors.quranicaudio.com/…"  → "https://mirrors.quranicaudio.com/…"
  ///   "https://…"                     → inchangé
  String _normalize(String raw) {
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('//'))   return 'https:$raw';
    return 'https://verses.quran.com/$raw';
  }
}
