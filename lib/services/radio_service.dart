import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

class RadioService {
  RadioService._();
  static final RadioService instance = RadioService._();

  static const _kCacheKey      = 'radio_stations_cache';
  static const _kTimestampKey  = 'radio_stations_timestamp';
  static const _kTtlMs         = 24 * 60 * 60 * 1000; // 24 h
  static const _kApiUrl        = 'https://mp3quran.net/api/v3/radios';
  static const _kRecentIdsKey  = 'radio_recent_ids_v1';
  static const _kPlayCountsKey = 'radio_play_counts_v1';
  static const _kFavoritesKey  = 'radio_favorites_v1';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Station en cours de lecture (null = pas en mode radio).
  final ValueNotifier<RadioStation?> currentStationNotifier =
      ValueNotifier<RadioStation?>(null);

  List<RadioStation>? _memCache;

  /// Accès synchrone au cache (vide si pas encore chargé).
  List<RadioStation> get cachedStations => _memCache ?? [];

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

  // ── Tracking récents + popularité ──────────────────────────────────────────

  /// Enregistre une lecture : met la station en tête des récents + incrémente son compteur.
  Future<void> trackPlay(RadioStation station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Récents (max 10)
      final ids = prefs.getStringList(_kRecentIdsKey) ?? [];
      ids.remove(station.id.toString());
      ids.insert(0, station.id.toString());
      if (ids.length > 10) ids.removeRange(10, ids.length);
      await prefs.setStringList(_kRecentIdsKey, ids);
      // Compteur
      final raw    = prefs.getString(_kPlayCountsKey);
      final counts = raw != null
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      final k = station.id.toString();
      counts[k] = ((counts[k] as int?) ?? 0) + 1;
      await prefs.setString(_kPlayCountsKey, jsonEncode(counts));
    } catch (e) {
      debugPrint('RadioService: trackPlay error: $e');
    }
  }

  /// Retourne les stations récemment écoutées (dans l'ordre chronologique).
  Future<List<RadioStation>> getRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids   = prefs.getStringList(_kRecentIdsKey) ?? [];
      if (ids.isEmpty) return [];
      final all  = await getStations();
      final byId = {for (final s in all) s.id: s};
      return ids
          .map((id) => byId[int.tryParse(id) ?? -1])
          .whereType<RadioStation>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Retourne les stations les plus écoutées (triées par nombre de lectures).
  Future<List<RadioStation>> getPopular({int limit = 8}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPlayCountsKey);
      if (raw == null) return [];
      final counts = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final sorted = counts.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      final topIds = sorted
          .take(limit)
          .map((e) => int.tryParse(e.key) ?? -1)
          .where((id) => id != -1)
          .toList();
      final all  = await getStations();
      final byId = {for (final s in all) s.id: s};
      return topIds.map((id) => byId[id]).whereType<RadioStation>().toList();
    } catch (e) {
      return [];
    }
  }

  // ── Favoris ────────────────────────────────────────────────────────────────

  Future<Set<int>> getFavoriteIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kFavoritesKey) ?? [];
      return ids.map((s) => int.tryParse(s) ?? -1).where((id) => id != -1).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<List<RadioStation>> getFavorites() async {
    try {
      final results = await Future.wait([getFavoriteIds(), getStations()]);
      final ids  = results[0] as Set<int>;
      final all  = results[1] as List<RadioStation>;
      if (ids.isEmpty) return [];
      final byId = {for (final s in all) s.id: s};
      return ids.map((id) => byId[id]).whereType<RadioStation>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Ajoute ou retire la station des favoris. Retourne true si désormais en favori.
  Future<bool> toggleFavorite(RadioStation station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids   = prefs.getStringList(_kFavoritesKey) ?? [];
      final key   = station.id.toString();
      if (ids.contains(key)) {
        ids.remove(key);
        await prefs.setStringList(_kFavoritesKey, ids);
        return false;
      } else {
        ids.add(key);
        await prefs.setStringList(_kFavoritesKey, ids);
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFavorite(int stationId) async {
    final ids = await getFavoriteIds();
    return ids.contains(stationId);
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
