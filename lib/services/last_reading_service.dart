import 'package:shared_preferences/shared_preferences.dart';

/// Service pour sauvegarder et récupérer la dernière position de lecture du Coran
class LastReadingService {
  static const String _keyLastSurah = 'last_reading_surah';
  static const String _keyLastPage = 'last_reading_page';
  static const String _keyLastTimestamp = 'last_reading_timestamp';

  /// Sauvegarde la dernière position de lecture
  static Future<void> saveLastReading({
    required int surahNumber,
    required int pageNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_keyLastSurah, surahNumber),
      prefs.setInt(_keyLastPage, pageNumber),
      prefs.setInt(_keyLastTimestamp, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Récupère la dernière position de lecture
  static Future<LastReadingPosition?> getLastReading() async {
    final prefs = await SharedPreferences.getInstance();
    
    final surahNumber = prefs.getInt(_keyLastSurah);
    final pageNumber = prefs.getInt(_keyLastPage);
    final timestamp = prefs.getInt(_keyLastTimestamp);

    if (surahNumber == null || pageNumber == null) {
      return null;
    }

    return LastReadingPosition(
      surahNumber: surahNumber,
      pageNumber: pageNumber,
      timestamp: timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now(),
    );
  }

  /// Efface la dernière position de lecture
  static Future<void> clearLastReading() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyLastSurah),
      prefs.remove(_keyLastPage),
      prefs.remove(_keyLastTimestamp),
    ]);
  }
}

/// Classe représentant la dernière position de lecture
class LastReadingPosition {
  final int surahNumber;
  final int pageNumber;
  final DateTime timestamp;

  const LastReadingPosition({
    required this.surahNumber,
    required this.pageNumber,
    required this.timestamp,
  });

  /// Retourne un texte relatif (il y a X jours/heures)
  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }
}
