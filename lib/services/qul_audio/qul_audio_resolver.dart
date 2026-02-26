// lib/services/qul_audio/qul_audio_resolver.dart
//
// Résolveur d'URLs audio QUL.
//
// L'UI n'appelle JAMAIS directement une URL audio :
// elle passe TOUJOURS par ce résolveur.
//
// Stratégie de résolution :
//   Verset  → QulApiClient.resolveAyahUrl()  → null si indisponible
//   Sourate → QulApiClient.resolveSurahUrl() → null si indisponible
//
// Retourne null si :
//   - le récitateur n'a pas de quranComId (non indexé sur QUL)
//   - l'API répond 404 pour ce récitateur / cette sourate

import 'package:flutter/foundation.dart';
import 'models/qul_reciter.dart';
import 'qul_api_client.dart';

class QulAudioResolver {
  QulAudioResolver._();
  static final QulAudioResolver instance = QulAudioResolver._();

  final _client = QulApiClient.instance;

  // ── Résolution verset ─────────────────────────────────────────────────────

  /// Retourne l'URL audio d'un verset depuis le CDN QUL.
  /// Retourne null si le récitateur n'est pas disponible sur QUL.
  Future<String?> resolveAyah(QulReciter reciter, int surah, int ayah) async {
    if (!reciter.isAvailable) {
      debugPrint('QulAudioResolver: ${reciter.name} indisponible (pas de quranComId)');
      return null;
    }
    return _client.resolveAyahUrl(reciter.quranComId!, surah, ayah);
  }

  // ── Résolution sourate ────────────────────────────────────────────────────

  /// Retourne l'URL audio d'une sourate complète depuis le CDN QUL.
  /// Retourne null si non disponible.
  Future<String?> resolveSurah(QulReciter reciter, int surah) async {
    if (!reciter.isAvailable) {
      debugPrint('QulAudioResolver: ${reciter.name} indisponible (pas de quranComId)');
      return null;
    }
    return _client.resolveSurahUrl(reciter.quranComId!, surah);
  }

  // ── Préchargement ─────────────────────────────────────────────────────────

  /// Précharge en cache les URLs de tous les versets d'une sourate.
  /// Appeler avant de démarrer la lecture d'une sourate pour éviter la latence.
  Future<void> prefetch(QulReciter reciter, int surah) async {
    if (!reciter.isAvailable) return;
    await _client.prefetchChapter(reciter.quranComId!, surah);
  }
}
