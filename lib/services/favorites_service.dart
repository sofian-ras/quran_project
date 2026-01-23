import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service pour gérer les sourates favorites
class FavoritesService {
  static const String _favoritesKey = 'user_favorites';
  
  // Singleton
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();
  static FavoritesService get instance => _instance;
  
  // Cache en mémoire
  Set<int>? _cachedFavorites;
  
  /// Récupérer la liste des favoris (IDs de sourates)
  Future<Set<int>> getFavorites() async {
    if (_cachedFavorites != null) {
      return _cachedFavorites!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null) {
      _cachedFavorites = <int>{};
      return _cachedFavorites!;
    }
    
    try {
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      _cachedFavorites = favoritesList.cast<int>().toSet();
      return _cachedFavorites!;
    } catch (e) {
      _cachedFavorites = <int>{};
      return _cachedFavorites!;
    }
  }
  
  /// Sauvegarder les favoris
  Future<void> _saveFavorites(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesList = favorites.toList();
    await prefs.setString(_favoritesKey, json.encode(favoritesList));
    _cachedFavorites = favorites;
  }
  
  /// Ajouter une sourate aux favoris
  Future<void> addFavorite(int surahId) async {
    final favorites = await getFavorites();
    favorites.add(surahId);
    await _saveFavorites(favorites);
  }
  
  /// Retirer une sourate des favoris
  Future<void> removeFavorite(int surahId) async {
    final favorites = await getFavorites();
    favorites.remove(surahId);
    await _saveFavorites(favorites);
  }
  
  /// Toggle: ajouter si pas présent, retirer sinon
  Future<bool> toggleFavorite(int surahId) async {
    final favorites = await getFavorites();
    final isNowFavorite = !favorites.contains(surahId);
    
    if (isNowFavorite) {
      favorites.add(surahId);
    } else {
      favorites.remove(surahId);
    }
    
    await _saveFavorites(favorites);
    return isNowFavorite;
  }
  
  /// Vérifier si une sourate est favorite
  Future<bool> isFavorite(int surahId) async {
    final favorites = await getFavorites();
    return favorites.contains(surahId);
  }
  
  /// Obtenir le nombre de favoris
  Future<int> getFavoritesCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }
  
  /// Effacer tous les favoris
  Future<void> clearFavorites() async {
    await _saveFavorites(<int>{});
  }
  
  /// Vider le cache (utile pour forcer un rechargement)
  void clearCache() {
    _cachedFavorites = null;
  }
}
