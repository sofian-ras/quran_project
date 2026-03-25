// lib/models/reciter_audio_source.dart
//
// Configuration d'un récitateur "seek-based".
//
// Deux modes pour le mp3quranReadId :
//
//   1. Hardcodé (connu d'avance) :
//      ReciterAudioSource(mp3quranReadId: 123, ...)
//
//   2. Auto-découverte (readId inconnu) :
//      ReciterAudioSource(
//        mp3quranReadId: null,
//        searchName   : 'soufi',    // recherché dans le champ "name" de /reads
//        searchRewaya : 'hafs',     // recherché dans le champ "rewaya"
//      )
//      → Mp3QuranTimingCache résout le readId au premier appel,
//        le met en cache pour la session.

class ReciterAudioSource {
  /// Identifiant unique stable pour le stockage local.
  /// Utilisé comme nom de dossier : timed_audio/{localCacheId}/{surah:3}.mp3
  final String localCacheId;

  /// URL de base du serveur mp3quran.
  /// Fichier sourate : {serverBaseUrl}/{surah:3}.mp3
  final String serverBaseUrl;

  /// ID de la récitation dans l'API mp3quran ayat_timing.
  /// null + searchName/searchRewaya → auto-découverte au premier play.
  final int? mp3quranReadId;

  /// Terme de recherche sur le champ "name" du read (insensible à la casse).
  /// Utilisé uniquement si mp3quranReadId est null.
  final String? searchName;

  /// Terme de recherche sur le champ "rewaya" du read (insensible à la casse).
  /// Utilisé uniquement si mp3quranReadId est null.
  final String? searchRewaya;

  const ReciterAudioSource({
    required this.localCacheId,
    required this.serverBaseUrl,
    this.mp3quranReadId,
    this.searchName,
    this.searchRewaya,
  });

  /// Vrai si le readId est connu OU auto-découvrable.
  bool get isConfigured =>
      mp3quranReadId != null ||
      (searchName != null && searchName!.isNotEmpty);

  /// URL du MP3 complet d'une sourate.
  String surahUrl(int surah) {
    final s = surah.toString().padLeft(3, '0');
    return '$serverBaseUrl/$s.mp3';
  }

  String localRelativePath(int surah) {
    final s = surah.toString().padLeft(3, '0');
    return '$localCacheId/$s.mp3';
  }

  @override
  String toString() =>
      'ReciterAudioSource($localCacheId, readId=$mp3quranReadId)';
}
