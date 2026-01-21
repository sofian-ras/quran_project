class Reciter {
  final String id;
  final String name;
  final String server; // Le serveur spécifique à ce récitant
  final String letter; // Le code (ex: 'afs')

  Reciter({required this.id, required this.name, required this.server, required this.letter});

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      server: json['server'] ?? '',
      letter: json['suras']?.toString() ?? '', // Note: l'API varie selon les endpoints
    );
  }
}