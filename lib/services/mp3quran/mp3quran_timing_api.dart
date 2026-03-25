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
