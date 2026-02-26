// lib/services/qul_audio/models/qul_reciter.dart
//
// Modèle de données pour un récitateur QUL (qul.tarteel.ai).
//
//   qulId       : identifiant interne de qul.tarteel.ai
//   quranComId  : identifiant sur api.quran.com/v4 (null si non indexé = indisponible)
//   name        : nom d'affichage
//   style       : style de récitation (Murattal, Mujawwad…), nullable

class QulReciter {
  final int qulId;
  final int? quranComId;
  final String name;
  final String? style;

  const QulReciter({
    required this.qulId,
    this.quranComId,
    required this.name,
    this.style,
  });

  /// Nom complet avec style si présent.
  String get displayName =>
      style != null ? '$name ($style)' : name;

  /// Vrai si ce récitateur est disponible sur le CDN QUL.
  bool get isAvailable => quranComId != null;

  @override
  bool operator ==(Object other) =>
      other is QulReciter && other.qulId == qulId;

  @override
  int get hashCode => qulId.hashCode;

  @override
  String toString() => 'QulReciter($qulId, $displayName)';
}
