class Reciter {
  final String id;
  final String name;
  final String server; // Le serveur spécifique à ce récitant
  final String letter; // Le code (ex: 'afs')
  final int? reciterId; // ID de l'API mp3quran.net
  final int? moshafId; // ID du moshaf dans l'API

  Reciter({
    required this.id,
    required this.name,
    required this.server,
    required this.letter,
    this.reciterId,
    this.moshafId,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      server: json['server'] ?? '',
      letter: json['suras']?.toString() ?? '', // Note: l'API varie selon les endpoints
      reciterId: json['reciterId'] as int?,
      moshafId: json['moshafId'] as int?,
    );
  }
}