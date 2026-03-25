// lib/models/ayah_timing.dart
//
// Timing d'un verset depuis l'API mp3quran.net.
//
//   ayah       : numéro du verset (0 = Basmalah introductive)
//   start      : position de début dans le fichier MP3 complet
//   end        : position de fin
//   page       : numéro de page mushaf (optionnel, peut être null)

class AyahTiming {
  final int ayah;
  final Duration start;
  final Duration end;
  final int? page;

  const AyahTiming({
    required this.ayah,
    required this.start,
    required this.end,
    this.page,
  });

  Duration get duration => end - start;

  static int _i(dynamic v) => v is int ? v : int.parse(v.toString());

  factory AyahTiming.fromJson(Map<String, dynamic> json) => AyahTiming(
        ayah: _i(json['ayah']),
        start: Duration(milliseconds: _i(json['start_time'])),
        end: Duration(milliseconds: _i(json['end_time'])),
        page: json['page'] is int ? json['page'] as int : null,
      );

  @override
  String toString() =>
      'AyahTiming(ayah=$ayah, '
      'start=${start.inMilliseconds}ms, '
      'end=${end.inMilliseconds}ms)';
}
