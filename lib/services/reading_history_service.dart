import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReadingHistoryService {
  static final ReadingHistoryService instance = ReadingHistoryService._();
  ReadingHistoryService._();
  
  static const String _lastReadingKey = 'last_reading';
  static const String _historyKey = 'reading_history';
  static const String _statsKey = 'reading_stats';
  static const String _preferredReadingKey = 'preferred_reading';

  // Sauvegarder la lecture préférée (hafs/warsh)
  Future<void> setPreferredReading(String reading) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredReadingKey, reading);
  }

  // Récupérer la lecture préférée (hafs par défaut)
  Future<String> getPreferredReading() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredReadingKey) ?? 'hafs';
  }
  // Sauvegarder la dernière position de lecture
  Future<void> saveLastReading({
    required int page,
    required int surahId,
    required String surahName,
    String reading = 'hafs',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'page': page,
      'surahId': surahId,
      'surahName': surahName,
      'reading': reading,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_lastReadingKey, json.encode(data));
    await _addToHistory(data);
  }
  
  // Récupérer la dernière lecture
  Future<Map<String, dynamic>?> getLastReading() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_lastReadingKey);
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }
  
  // Ajouter à l'historique
  Future<void> _addToHistory(Map<String, dynamic> reading) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    List<dynamic> history = historyJson != null ? json.decode(historyJson) : [];
    
    // Éviter les doublons consécutifs
    if (history.isNotEmpty) {
      final last = history.first as Map<String, dynamic>;
      if (last['page'] == reading['page'] && 
          last['surahId'] == reading['surahId']) {
        return;
      }
    }
    
    // Ajouter au début et limiter à 50 entrées
    history.insert(0, reading);
    if (history.length > 50) {
      history = history.sublist(0, 50);
    }
    
    await prefs.setString(_historyKey, json.encode(history));
  }
  
  // Récupérer l'historique
  Future<List<Map<String, dynamic>>> getHistory({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson == null) return [];
    
    final history = json.decode(historyJson) as List<dynamic>;
    final limited = history.take(limit).toList();
    return limited.cast<Map<String, dynamic>>();
  }
  
  // Enregistrer les statistiques de lecture
  Future<void> recordReadingSession({
    required int page,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_statsKey);
    Map<String, dynamic> stats = statsJson != null ? json.decode(statsJson) : {};
    
    // Initialiser si nécessaire
    stats['totalSeconds'] = (stats['totalSeconds'] ?? 0) + duration.inSeconds;
    stats['pagesRead'] = (stats['pagesRead'] ?? <int>[]);
    
    // Ajouter la page lue (set pour éviter doublons)
    final pagesRead = Set<int>.from(stats['pagesRead'] as List);
    pagesRead.add(page);
    stats['pagesRead'] = pagesRead.toList();
    
    // Statistiques par jour
    final today = DateTime.now().toIso8601String().substring(0, 10);
    stats['dailyStats'] = stats['dailyStats'] ?? {};
    stats['dailyStats'][today] = {
      'seconds': (stats['dailyStats'][today]?['seconds'] ?? 0) + duration.inSeconds,
      'pages': (stats['dailyStats'][today]?['pages'] ?? 0) + 1,
    };
    
    await prefs.setString(_statsKey, json.encode(stats));
  }
  
  // Récupérer les statistiques
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_statsKey);
    if (statsJson == null) {
      return {
        'totalSeconds': 0,
        'pagesRead': [],
        'dailyStats': {},
      };
    }
    return json.decode(statsJson) as Map<String, dynamic>;
  }
  
  // Obtenir le nombre de pages lues
  Future<int> getPagesReadCount() async {
    final stats = await getStats();
    final pagesRead = stats['pagesRead'] as List? ?? [];
    return pagesRead.length;
  }
  
  // Obtenir le temps total de lecture
  Future<Duration> getTotalReadingTime() async {
    final stats = await getStats();
    final seconds = stats['totalSeconds'] as int? ?? 0;
    return Duration(seconds: seconds);
  }
  
  // Obtenir les stats d'aujourd'hui
  Future<Map<String, dynamic>> getTodayStats() async {
    final stats = await getStats();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final dailyStats = stats['dailyStats'] as Map<String, dynamic>? ?? {};
    return dailyStats[today] ?? {'seconds': 0, 'pages': 0};
  }
  
  // Nettoyer l'historique
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_lastReadingKey);
  }
}
