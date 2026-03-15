import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class DailyVerse {
  final String arabic;
  final String french;
  final String surahName;
  final int surahNumber;
  final int verseNumber;
  
  DailyVerse({
    required this.arabic,
    required this.french,
    required this.surahName,
    required this.surahNumber,
    required this.verseNumber,
  });
}

class DailyVerseService {
  static final DailyVerseService instance = DailyVerseService._();
  DailyVerseService._();
  
  static const String _lastDateKey = 'daily_verse_date';
  static const String _lastVerseKey = 'daily_verse_data';
  
  // Collection de versets inspirants (à enrichir)
  static final List<Map<String, dynamic>> inspiringVerses = [
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'french': 'N\'est-ce point par l\'évocation d\'Allah que se tranquillisent les cœurs',
      'surah': 'Ar-Ra\'d',
      'surahNumber': 13,
      'verse': 28,
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'french': 'À côté de la difficulté est, certes, une facilité',
      'surah': 'Ash-Sharh',
      'surahNumber': 94,
      'verse': 5,
    },
    {
      'arabic': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      'french': 'Et dis : Ô mon Seigneur, accroît mes connaissances',
      'surah': 'Ta-Ha',
      'surahNumber': 20,
      'verse': 114,
    },
    {
      'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
      'french': 'Seigneur ! Accorde nous belle part ici-bas, et belle part aussi dans l\'au-delà',
      'surah': 'Al-Baqarah',
      'surahNumber': 2,
      'verse': 201,
    },
    {
      'arabic': 'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
      'french': 'Quiconque craint Allah, Il lui donnera une issue favorable',
      'surah': 'At-Talaq',
      'surahNumber': 65,
      'verse': 2,
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'french': 'Certes, Allah est avec les endurants',
      'surah': 'Al-Baqarah',
      'surahNumber': 2,
      'verse': 153,
    },
    {
      'arabic': 'وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ',
      'french': 'Ne désespérez pas de la miséricorde d\'Allah',
      'surah': 'Yusuf',
      'surahNumber': 12,
      'verse': 87,
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'french': 'Souvenez-vous de Moi donc, Je Me souviendrai de vous',
      'surah': 'Al-Baqarah',
      'surahNumber': 2,
      'verse': 152,
    },
    {
      'arabic': 'وَمَا أُوتِيتُم مِّنَ الْعِلْمِ إِلَّا قَلِيلًا',
      'french': 'Et on ne vous a donné que peu de connaissance',
      'surah': 'Al-Isra',
      'surahNumber': 17,
      'verse': 85,
    },
    {
      'arabic': 'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
      'french': 'Et Il est avec vous où que vous soyez',
      'surah': 'Al-Hadid',
      'surahNumber': 57,
      'verse': 4,
    },
    {
      'arabic': 'وَلَذِكْرُ اللَّهِ أَكْبَرُ',
      'french': 'Le rappel d\'Allah est certes ce qu\'il y a de plus grand',
      'surah': 'Al-Ankabut',
      'surahNumber': 29,
      'verse': 45,
    },
    {
      'arabic': 'قُلْ هُوَ اللَّهُ أَحَدٌ',
      'french': 'Dis : Il est Allah, Unique',
      'surah': 'Al-Ikhlas',
      'surahNumber': 112,
      'verse': 1,
    },
    {
      'arabic': 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
      'french': 'Et quiconque place sa confiance en Allah, Il lui suffit',
      'surah': 'At-Talaq',
      'surahNumber': 65,
      'verse': 3,
    },
    {
      'arabic': 'لَا إِكْرَاهَ فِي الدِّينِ',
      'french': 'Nulle contrainte en religion',
      'surah': 'Al-Baqarah',
      'surahNumber': 2,
      'verse': 256,
    },
    {
      'arabic': 'وَاصْبِرْ فَإِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ',
      'french': 'Et patiente, car Allah ne laisse pas perdre la récompense des bienfaisants',
      'surah': 'Hud',
      'surahNumber': 11,
      'verse': 115,
    },
  ];
  
  // Obtenir le verset du jour
  Future<DailyVerse> getDailyVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString(_lastDateKey);

    // Si c'est un nouveau jour, choisir un nouveau verset
    if (lastDate != today) {
      final verse = _selectRandomVerse(today);
      await _saveDailyVerse(verse, today, prefs);
      return verse;
    }

    // Sinon retourner le verset sauvegardé
    final savedVerse = prefs.getString(_lastVerseKey);
    if (savedVerse != null) {
      return _parseVerse(savedVerse);
    }

    // Fallback
    final verse = _selectRandomVerse(today);
    await _saveDailyVerse(verse, today, prefs);
    return verse;
  }
  
  // Sélectionner un verset pseudo-aléatoire basé sur la date
  DailyVerse _selectRandomVerse(String date) {
    // Utiliser la date comme seed pour avoir le même verset toute la journée
    final seed = date.hashCode;
    final random = Random(seed);
    final index = random.nextInt(inspiringVerses.length);
    final data = inspiringVerses[index];
    
    return DailyVerse(
      arabic: data['arabic'] as String,
      french: data['french'] as String,
      surahName: data['surah'] as String,
      surahNumber: data['surahNumber'] as int,
      verseNumber: data['verse'] as int,
    );
  }
  
  // Sauvegarder le verset du jour
  Future<void> _saveDailyVerse(DailyVerse verse, String date, SharedPreferences prefs) async {
    await prefs.setString(_lastDateKey, date);
    await prefs.setString(_lastVerseKey, _serializeVerse(verse));
  }
  
  // Sérialiser un verset
  String _serializeVerse(DailyVerse verse) {
    return '${verse.arabic}|${verse.french}|${verse.surahName}|${verse.surahNumber}|${verse.verseNumber}';
  }
  
  // Parser un verset
  DailyVerse _parseVerse(String data) {
    final parts = data.split('|');
    return DailyVerse(
      arabic: parts[0],
      french: parts[1],
      surahName: parts[2],
      surahNumber: int.parse(parts[3]),
      verseNumber: int.parse(parts[4]),
    );
  }
  
  // Forcer un nouveau verset (pour test)
  Future<DailyVerse> refreshVerse() async {
    final random = Random();
    final index = random.nextInt(inspiringVerses.length);
    final data = inspiringVerses[index];
    
    final verse = DailyVerse(
      arabic: data['arabic'] as String,
      french: data['french'] as String,
      surahName: data['surah'] as String,
      surahNumber: data['surahNumber'] as int,
      verseNumber: data['verse'] as int,
    );
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await _saveDailyVerse(verse, today, prefs);
    return verse;
  }
}
