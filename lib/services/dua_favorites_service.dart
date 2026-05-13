import 'package:shared_preferences/shared_preferences.dart';

class DuaFavoritesService {
  static const String _key = 'dua_favorites';
  static final DuaFavoritesService instance = DuaFavoritesService._();
  DuaFavoritesService._();

  Set<String>? _cache;

  Future<Set<String>> getAll() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = (prefs.getStringList(_key) ?? []).toSet();
    return _cache!;
  }

  Future<bool> isFavorite(String id) async => (await getAll()).contains(id);

  Future<bool> toggle(String id) async {
    final favs = await getAll();
    final added = !favs.contains(id);
    if (added) { favs.add(id); } else { favs.remove(id); }
    await _save(favs);
    return added;
  }

  Future<void> remove(String id) async {
    final favs = await getAll();
    favs.remove(id);
    await _save(favs);
  }

  Future<void> add(String id) async {
    final favs = await getAll();
    favs.add(id);
    await _save(favs);
  }

  Future<void> _save(Set<String> favs) async {
    _cache = favs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favs.toList());
  }
}
