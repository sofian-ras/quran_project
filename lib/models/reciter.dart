class Reciter {
  final String id;
  final String name;
  final String server; // Le serveur spécifique à ce récitant
  final String letter; // Le code (ex: 'afs')
  final int? reciterId; // ID de l'API mp3quran.net
  final int? moshafId; // ID du moshaf dans l'API
  final String? baseUrl; // URL de base MP3Quran (ex: https://server8.mp3quran.net/afs)

  Reciter({
    required this.id,
    required this.name,
    required this.server,
    required this.letter,
    this.reciterId,
    this.moshafId,
    this.baseUrl,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      server: json['server'] ?? '',
      letter: json['suras']?.toString() ?? '', // Note: l'API varie selon les endpoints
      reciterId: json['reciterId'] as int?,
      moshafId: json['moshafId'] as int?,
      baseUrl: json['baseUrl'] as String?,
    );
  }

  /// Construit l'URL complète d'une sourate
  /// Exemple: pour surahId=1 => ${baseUrl}/001.mp3
  String getAudioUrl(int surahId) {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw Exception('baseUrl not configured for reciter: $name');
    }
    final paddedId = surahId.toString().padLeft(3, '0');
    return '$baseUrl/$paddedId.mp3';
  }
}