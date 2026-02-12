// lib/services/verse_favorites_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VerseFavoritesService {
  static const String _favoritesKey = 'verse_favorites';

  static final VerseFavoritesService _instance = VerseFavoritesService._internal();
  factory VerseFavoritesService() => _instance;
  VerseFavoritesService._internal();
  static VerseFavoritesService get instance => _instance;

  Set<String>? _cached;

  Future<Set<String>> getFavorites() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_favoritesKey);
    if (jsonStr == null) {
      _cached = <String>{};
      return _cached!;
    }
    try {
      final list = (json.decode(jsonStr) as List).cast<String>();
      _cached = list.toSet();
      return _cached!;
    } catch (_) {
      _cached = <String>{};
      return _cached!;
    }
  }

  Future<void> _save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(favorites.toList()));
    _cached = favorites;
  }

  Future<bool> isFavorite(String key) async {
    final favorites = await getFavorites();
    return favorites.contains(key);
  }

  Future<bool> toggleFavorite(String key) async {
    final favorites = await getFavorites();
    final isNowFavorite = !favorites.contains(key);
    if (isNowFavorite) {
      favorites.add(key);
    } else {
      favorites.remove(key);
    }
    await _save(favorites);
    return isNowFavorite;
  }

  void clearCache() {
    _cached = null;
  }
}
