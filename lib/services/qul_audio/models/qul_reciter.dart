// lib/services/qul_audio/models/qul_reciter.dart
//
// Modèle de données pour un récitateur verset-par-verset.
//
//   qulId         : identifiant interne (qul.tarteel.ai ou synthétique)
//   quranComId    : ID sur api.quran.com/v4 — résout les URLs via CDN QUL
//   name          : nom d'affichage
//   style         : style (Murattal, Mujawwad…), nullable
//   everyayahSlug : slug everyayah.com — URL directe par verset
//                   https://everyayah.com/data/{slug}/{S:3}{A:3}.mp3
//   timedSource   : config seek-based — MP3 complet + timings API mp3quran.
//                   Si non null, la lecture délègue à TimedSurahPlayer.

import '../../../models/reciter_audio_source.dart';

class QulReciter {
  final int qulId;
  final int? quranComId;
  final String name;
  final String? style;
  final String? everyayahSlug;

  /// Configuration seek-based (MP3 sourate complète + timings mp3quran).
  /// Non null = ce récitateur n'a pas de fichiers audio par verset individuel.
  final ReciterAudioSource? timedSource;

  const QulReciter({
    required this.qulId,
    this.quranComId,
    required this.name,
    this.style,
    this.everyayahSlug,
    this.timedSource,
  });

  String get displayName => style != null ? '$name ($style)' : name;

  bool get isAvailable =>
      quranComId != null ||
      everyayahSlug != null ||
      (timedSource?.isConfigured ?? false);

  bool get isEveryayah  => everyayahSlug != null;
  bool get isSeekBased  => timedSource != null;

  @override
  bool operator ==(Object other) =>
      other is QulReciter && other.qulId == qulId;

  @override
  int get hashCode => qulId.hashCode;

  @override
  String toString() => 'QulReciter($qulId, $displayName)';
}
