import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HadithFavoritesService {
  static const String _key = 'hadith_favorites';

  static final HadithFavoritesService instance = HadithFavoritesService._();
  HadithFavoritesService._();

  Set<int>? _cache;

  Future<Set<int>> getAll() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _cache = {};
      return _cache!;
    }
    try {
      _cache = (jsonDecode(raw) as List).cast<int>().toSet();
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  Future<bool> isFavorite(int id) async {
    return (await getAll()).contains(id);
  }

  Future<bool> toggle(int id) async {
    final favs = await getAll();
    final added = !favs.contains(id);
    if (added) {
      favs.add(id);
    } else {
      favs.remove(id);
    }
    await _save(favs);
    return added;
  }

  Future<void> _save(Set<int> favs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(favs.toList()));
    _cache = favs;
  }
}
