import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

class RadioService {
  RadioService._();
  static final RadioService instance = RadioService._();

  static const _kCacheKey     = 'radio_stations_cache';
  static const _kTimestampKey = 'radio_stations_timestamp';
  static const _kTtlMs        = 24 * 60 * 60 * 1000; // 24 h
  static const _kApiUrl       = 'https://mp3quran.net/api/v3/radios';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Station en cours de lecture (null = pas en mode radio).
  final ValueNotifier<RadioStation?> currentStationNotifier =
      ValueNotifier<RadioStation?>(null);

  List<RadioStation>? _memCache;

  /// Retourne la liste des stations.
  /// - Si le cache mémoire est présent : retour immédiat + refresh silencieux
  /// - Si cache SharedPreferences < 24 h : retour immédiat + refresh silencieux
  /// - Sinon : attend le réseau
  Future<List<RadioStation>> getStations() async {
    if (_memCache != null) {
      _refreshInBackground();
      return _memCache!;
    }

    final cached = await _loadFromCache();
    if (cached != null) {
      _memCache = cached;
      _refreshInBackground();
      return cached;
    }

    final fresh = await _fetchFromApi();
    _memCache = fresh;
    await _saveToCache(fresh);
    return fresh;
  }

  void _refreshInBackground() {
    _fetchFromApi().then((stations) async {
      _memCache = stations;
      await _saveToCache(stations);
    }).catchError((Object e) {
      debugPrint('RadioService: background refresh error: $e');
    });
  }

  Future<List<RadioStation>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts    = prefs.getInt(_kTimestampKey);
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _kTtlMs) return null;
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) return null;
      return RadioStation.listFromJson(raw);
    } catch (e) {
      debugPrint('RadioService: cache load error: $e');
      return null;
    }
  }

  Future<void> _saveToCache(List<RadioStation> stations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, RadioStation.listToJson(stations));
      await prefs.setInt(_kTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('RadioService: cache save error: $e');
    }
  }

  Future<List<RadioStation>> _fetchFromApi() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _kApiUrl,
      queryParameters: {'language': 'fr'},
    );
    final data    = response.data!;
    final list    = data['radios'] as List<dynamic>;
    return list
        .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
