import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Bookmark {
  final int page;
  final int? surahId;
  final String? surahName;
  final String? note;
  final String category;
  final DateTime createdAt;
  
  Bookmark({
    required this.page,
    this.surahId,
    this.surahName,
    this.note,
    this.category = 'default',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'page': page,
    'surahId': surahId,
    'surahName': surahName,
    'note': note,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    page: json['page'] as int,
    surahId: json['surahId'] as int?,
    surahName: json['surahName'] as String?,
    note: json['note'] as String?,
    category: json['category'] as String? ?? 'default',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class BookmarkService {
  static final BookmarkService instance = BookmarkService._();
  BookmarkService._();
  
  static const String _bookmarksKey = 'bookmarks';
  static const String _categoriesKey = 'bookmark_categories';
  
  // Catégories prédéfinies
  static const List<String> defaultCategories = [
    'À réviser',
    'Important',
    'Favoris',
    'À mémoriser',
    'Notes',
  ];
  
  // Ajouter un marque-page
  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();
    
    // Vérifier si la page n'est pas déjà marquée
    final exists = bookmarks.any((b) => b.page == bookmark.page);
    if (exists) {
      // Mettre à jour au lieu d'ajouter
      await updateBookmark(bookmark);
      return;
    }
    
    bookmarks.add(bookmark);
    await _saveBookmarks(bookmarks);
  }
  
  // Mettre à jour un marque-page
  Future<void> updateBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();
    final index = bookmarks.indexWhere((b) => b.page == bookmark.page);
    
    if (index != -1) {
      bookmarks[index] = bookmark;
      await _saveBookmarks(bookmarks);
    }
  }
  
  // Supprimer un marque-page
  Future<void> removeBookmark(int page) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.page == page);
    await _saveBookmarks(bookmarks);
  }
  
  // Vérifier si une page est marquée
  Future<bool> isBookmarked(int page) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b.page == page);
  }
  
  // Obtenir un marque-page spécifique
  Future<Bookmark?> getBookmark(int page) async {
    final bookmarks = await getBookmarks();
    final match = bookmarks.where((b) => b.page == page);
    return match.isEmpty ? null : match.first;

  }
  
  // Récupérer tous les marque-pages
  Future<List<Bookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_bookmarksKey);
    if (jsonStr == null) return [];
    
    final list = json.decode(jsonStr) as List<dynamic>;
    return list.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
  }
  
  // Récupérer les marque-pages par catégorie
  Future<List<Bookmark>> getBookmarksByCategory(String category) async {
    final bookmarks = await getBookmarks();
    return bookmarks.where((b) => b.category == category).toList();
  }
  
  // Sauvegarder les marque-pages
  Future<void> _saveBookmarks(List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = bookmarks.map((b) => b.toJson()).toList();
    await prefs.setString(_bookmarksKey, json.encode(jsonList));
  }
  
  // Obtenir les catégories personnalisées
  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_categoriesKey);
    if (jsonStr == null) return List.from(defaultCategories);
    
    final custom = (json.decode(jsonStr) as List).cast<String>();
    return [...defaultCategories, ...custom];
  }
  
  // Ajouter une catégorie personnalisée
  Future<void> addCategory(String category) async {
    final categories = await getCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      final custom = categories.where((c) => !defaultCategories.contains(c)).toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_categoriesKey, json.encode(custom));
    }
  }
  
  // Rechercher dans les notes
  Future<List<Bookmark>> searchInNotes(String query) async {
    final bookmarks = await getBookmarks();
    final lowerQuery = query.toLowerCase();
    
    return bookmarks.where((b) {
      final note = b.note?.toLowerCase() ?? '';
      final surah = b.surahName?.toLowerCase() ?? '';
      return note.contains(lowerQuery) || surah.contains(lowerQuery);
    }).toList();
  }
  
  // Exporter les marque-pages en JSON
  Future<String> exportBookmarks() async {
    final bookmarks = await getBookmarks();
    return json.encode(bookmarks.map((b) => b.toJson()).toList());
  }
  
  // Importer les marque-pages depuis JSON
  Future<void> importBookmarks(String jsonStr) async {
    try {
      final list = json.decode(jsonStr) as List<dynamic>;
      final bookmarks = list.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
      await _saveBookmarks(bookmarks);
    } catch (e) {
      throw Exception('Format de données invalide');
    }
  }
  
  // Nettoyer tous les marque-pages
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarksKey);
  }
}
