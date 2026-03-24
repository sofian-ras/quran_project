// lib/models/reciter_audio_source.dart
//
// Configuration d'un récitateur "seek-based" :
// lecture via un MP3 de sourate complète + timings API mp3quran.
//
// Usage :
//   const soufiHafs = ReciterAudioSource(
//     localCacheId  : 'soufi_hafs',
//     serverBaseUrl : 'https://server16.mp3quran.net/download/soufi/Rewayat-Hafs-A-n-Assem',
//     mp3quranReadId: 123,          // trouver via Mp3QuranTimingCache.logAvailableReads()
//   );
//
// Pour ajouter un récitateur compatible :
//   1. Trouver serverBaseUrl  → page du récitateur sur mp3quran.net → lien Download
//   2. Trouver mp3quranReadId → appeler Mp3QuranTimingCache.logAvailableReads()
//      et noter l'id correspondant au récitateur + riwaya voulu.

class ReciterAudioSource {
  /// Identifiant unique stable pour le stockage local.
  /// Utilisé comme nom de dossier : timed_audio/{localCacheId}/{surah:3}.mp3
  final String localCacheId;

  /// URL de base du serveur mp3quran.
  /// Le fichier sourate est à : {serverBaseUrl}/{surah:3}.mp3
  final String serverBaseUrl;

  /// ID de la récitation dans l'API mp3quran ayat_timing.
  /// Obtenir via : Mp3QuranTimingCache.instance.logAvailableReads()
  /// null = non configuré → la lecture seek-based sera désactivée.
  final int? mp3quranReadId;

  const ReciterAudioSource({
    required this.localCacheId,
    required this.serverBaseUrl,
    required this.mp3quranReadId,
  });

  /// URL du MP3 complet d'une sourate.
  String surahUrl(int surah) {
    final s = surah.toString().padLeft(3, '0');
    return '$serverBaseUrl/$s.mp3';
  }

  /// Chemin relatif du fichier local dans le dossier timed_audio.
  /// Format : {localCacheId}/{surah:3}.mp3
  String localRelativePath(int surah) {
    final s = surah.toString().padLeft(3, '0');
    return '$localCacheId/$s.mp3';
  }

  /// Vrai si ce récitateur est prêt pour la lecture seek-based.
  bool get isConfigured => mp3quranReadId != null;

  @override
  String toString() =>
      'ReciterAudioSource($localCacheId, readId=$mp3quranReadId)';
}
