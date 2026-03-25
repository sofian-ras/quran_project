// lib/services/mp3quran/mp3quran_timing_api.dart
//
// Client API mp3quran.net — timings de versets.
//
// Endpoints :
//   GET /api/v3/ayat_timing/reads
//       → liste de tous les récitateurs avec timings disponibles
//
//   GET /api/v3/ayat_timing?surah={n}&read={readId}
//       → timings de tous les versets d'une sourate pour un readId donné

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/ayah_timing.dart';

/// Un "read" = une récitation pour laquelle mp3quran fournit des timings.
class Mp3QuranRead {
  final int id;
  final String name;
  final String rewaya;

  const Mp3QuranRead({
    required this.id,
    required this.name,
    required this.rewaya,
  });

  factory Mp3QuranRead.fromJson(Map<String, dynamic> json) => Mp3QuranRead(
        id: json['id'] as int,
        name: (json['reciter_name'] ?? json['name'] ?? '').toString(),
        rewaya: (json['rewaya'] ?? '').toString(),
      );

  @override
  String toString() => 'Mp3QuranRead(id=$id, "$name / $rewaya")';
}

/// Une entrée moshaf d'un récitateur (une récitation = un server + un readId optionnel).
class Mp3QuranMoshaf {
  final String server;
  final int?   readId; // présent uniquement si l'API est appelée avec reads=on

  const Mp3QuranMoshaf({required this.server, this.readId});

  factory Mp3QuranMoshaf.fromJson(Map<String, dynamic> json) {
    // moshaf['id'] == read_id dans /ayat_timing/reads (même entité, deux endpoints)
    final rawId = json['id'];
    return Mp3QuranMoshaf(
      server: (json['server'] ?? '').toString().trim(),
      readId: rawId == null
          ? null
          : (rawId is int ? rawId : int.tryParse(rawId.toString())),
    );
  }
}

/// Un récitateur avec son URL serveur (endpoint /reciters).
class Mp3QuranReciter {
  final int                   id;
  final String                name;
  final String                rewaya;
  final List<Mp3QuranMoshaf>  moshafs;

  /// Raccourci : server du premier moshaf (rétrocompatibilité).
  String get server => moshafs.isNotEmpty ? moshafs.first.server : '';

  const Mp3QuranReciter({
    required this.id,
    required this.name,
    required this.rewaya,
    required this.moshafs,
  });

  factory Mp3QuranReciter.fromJson(Map<String, dynamic> json) {
    final moshafRaw = json['moshaf'];
    final moshafs = (moshafRaw is List)
        ? moshafRaw
            .map((e) => Mp3QuranMoshaf.fromJson(e as Map<String, dynamic>))
            .toList()
        : <Mp3QuranMoshaf>[];
    return Mp3QuranReciter(
      id:      json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      name:    (json['name'] ?? '').toString(),
      rewaya:  (json['rewaya'] ?? '').toString(),
      moshafs: moshafs,
    );
  }
}

class Mp3QuranTimingApi {
  Mp3QuranTimingApi._();
  static final Mp3QuranTimingApi instance = Mp3QuranTimingApi._();

  static const _base = 'https://mp3quran.net/api/v3';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Extrait une List depuis une réponse qui peut être :
  ///   - directement une List<dynamic>
  ///   - un Map contenant la liste sous une des [keys]
  List<dynamic> _extractList(dynamic data, List<String> keys) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final k in keys) {
        if (data[k] is List) return data[k] as List<dynamic>;
      }
    }
    throw StateError('Réponse API inattendue : ${data.runtimeType}');
  }

  /// Retourne tous les récitateurs avec leurs URLs serveur.
  /// [withReads] = true pour inclure le champ read_id dans chaque moshaf.
  /// [language] = 'eng' pour la version anglaise (noms + champs supplémentaires).
  Future<List<Mp3QuranReciter>> fetchReciters({
    bool withReads = false,
    String language = 'eng',
  }) async {
    try {
      final params = <String, dynamic>{'language': language};
      if (withReads) params['reads'] = 'on';
      final resp = await _dio.get('$_base/reciters', queryParameters: params);
      final raw = _extractList(resp.data, ['reciters', 'data']);
      return raw
          .map((e) => Mp3QuranReciter.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('Mp3QuranTimingApi.fetchReciters: $e');
      rethrow;
    }
  }

  Future<List<Mp3QuranRead>> fetchReads() async {
    try {
      final resp = await _dio.get('$_base/ayat_timing/reads');
      final raw = _extractList(resp.data, ['reads', 'data']);
      return raw
          .map((e) => Mp3QuranRead.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('Mp3QuranTimingApi.fetchReads: $e');
      rethrow;
    }
  }

  // ── Timings ────────────────────────────────────────────────────────────────

  /// Retourne les timings de tous les versets d'une sourate.
  Future<List<AyahTiming>> fetchTimings({
    required int surah,
    required int readId,
  }) async {
    try {
      final resp = await _dio.get(
        '$_base/ayat_timing',
        queryParameters: {'surah': surah, 'read': readId},
      );
      final raw = _extractList(resp.data, ['ayat_timing', 'data']);
      return raw
          .map((e) => AyahTiming.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('Mp3QuranTimingApi.fetchTimings($surah, $readId): $e');
      rethrow;
    }
  }
}
