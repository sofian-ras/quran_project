import 'quran_text_db.dart';
import '../data/surah_name.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<QVerse> verses;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.verses = const [],
    required this.timestamp,
  });
}

class RagChatService {
  static final RagChatService instance = RagChatService._();
  RagChatService._();

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  // Expansion thématique : un mot-clé utilisateur active des synonymes de recherche
  static const Map<String, List<String>> _topicMap = {
    'patience': ['patience', 'patient', 'endurance', 'persévère', 'épreuve'],
    'sabr': ['patience', 'patient', 'endurance'],
    'prière': ['prière', 'prostration', 'adoration', 'invoquer'],
    'salat': ['prière', 'prostration', 'adoration'],
    'paradis': ['paradis', 'récompense', 'vertueux', 'bien'],
    'janna': ['paradis', 'récompense', 'bien'],
    'enfer': ['châtiment', 'punition', 'péché', 'feu'],
    'foi': ['croyant', 'croire', 'iman', 'confiance'],
    'iman': ['croyant', 'croire', 'foi', 'confiance'],
    'piété': ['piété', 'pieux', 'craindre', 'vertueux'],
    'taqwa': ['piété', 'pieux', 'craindre'],
    'pardon': ['pardon', 'repentir', 'miséricorde', 'péché'],
    'repentir': ['pardon', 'repentir', 'miséricorde'],
    'tawba': ['pardon', 'repentir', 'miséricorde'],
    'mort': ['mort', 'décès', 'âme', 'ressusciter'],
    'gratitude': ['gratitude', 'remercier', 'bienfait'],
    'shukr': ['gratitude', 'remercier', 'bienfait'],
    'justice': ['justice', 'équité', 'équitable', 'droit'],
    'paix': ['paix', 'tranquillité', 'sérénité', 'confiance'],
    'famille': ['famille', 'parent', 'mère', 'père', 'enfant'],
    'richesse': ['richesse', 'bien', 'argent', 'aumône', 'dépense'],
    'zakat': ['aumône', 'richesse', 'pauvre', 'dépense'],
    'jihad': ['effort', 'lutte', 'striv'],
    'connaissance': ['science', 'savoir', 'connaissance', 'sagesse'],
    'ilm': ['science', 'savoir', 'connaissance'],
  };

  static const Set<String> _stopWords = {
    'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'est', 'et',
    'en', 'au', 'aux', 'que', 'qui', 'quoi', 'comment', 'pourquoi',
    'dit', 'sur', 'ce', 'coran', 'islam', 'dieu', 'allah', 'quran',
    'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles', 'me',
    'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses',
    'par', 'pour', 'dans', 'avec', 'mais', 'ou', 'donc', 'or',
    'ni', 'car', 'à', 'a', 'si', 'même', 'très', 'plus', 'bien',
    'parle', 'mentionne', 'trouve', 'cherche',
  };

  List<String> _extractKeywords(String query) {
    final q = query.toLowerCase()
        .replaceAll(RegExp(r'[?!.,;:]'), '');

    final words = q.split(RegExp(r'\s+'));
    final Set<String> result = {};

    for (final word in words) {
      if (word.length < 4) continue;
      if (_stopWords.contains(word)) continue;
      result.add(word);

      // Expansion thématique
      final expanded = _topicMap[word];
      if (expanded != null) result.addAll(expanded);
    }

    // Expansion thématique sur les sous-chaînes si pas de match exact
    if (result.isEmpty) {
      for (final entry in _topicMap.entries) {
        if (q.contains(entry.key)) {
          result.addAll(entry.value);
          break;
        }
      }
    }

    return result.toList();
  }

  // Retourne une réponse directe si la question est conversationnelle,
  // null sinon (→ on passe à la recherche coranique).
  String? _conversationalReply(String query) {
    final q = query.toLowerCase().trim();

    final greetings = ['salam', 'salut', 'bonjour', 'bonsoir', 'assalam', 'as-salam', 'alsalam'];
    if (greetings.any(q.contains)) {
      return 'Wa alaykum assalam wa rahmatullahi wa barakatuh 🌿\n\n'
          'Je suis votre assistant coranique. Posez-moi une question sur le Coran, '
          'l\'islam, ou un thème comme la patience, la prière, le pardon… et je '
          'trouverai les versets les plus pertinents pour vous.';
    }

    final wellness = ['ça va', 'ca va', 'comment vas', 'comment tu vas', 'comment allez'];
    if (wellness.any(q.contains)) {
      return 'Alhamdulillah, tout va bien ! Et vous ?\n\n'
          'Je suis prêt à vous aider à explorer le Coran. Quel sujet vous '
          'intéresse ? (ex: patience, gratitude, prière, famille…)';
    }

    final thanks = ['merci', 'jazak', 'shukran', 'barak'];
    if (thanks.any(q.contains)) {
      return 'Wa iyyak ! C\'est un plaisir.\n\n'
          'N\'hésitez pas à poser d\'autres questions sur le Coran.';
    }

    final farewell = ['au revoir', 'bye', 'à bientôt', 'a bientot', 'bonne nuit', 'bonne soirée'];
    if (farewell.any(q.contains)) {
      return 'Fi amanillah ! Qu\'Allah vous garde et vous guide. À bientôt insha\'Allah.';
    }

    final who = ['qui es-tu', 'qui etes', 'c\'est quoi', 'c\'est qui', 'tu es quoi', 'tu fais quoi'];
    if (who.any(q.contains)) {
      return 'Je suis un assistant coranique.\n\n'
          'Je recherche les versets du Coran les plus pertinents en fonction '
          'de vos questions. Je ne génère pas de texte inventé : tout ce que '
          'je partage vient directement du Coran.\n\n'
          'Essayez : "patience", "prière du soir", "qu\'est-ce que la taqwa ?"…';
    }

    // Question trop courte ou hors-sujet sans mots-clés islamiques
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).length;
    if (words <= 1 && _extractKeywords(query).isEmpty) {
      return 'Je suis un assistant spécialisé dans le Coran.\n\n'
          'Posez-moi une question sur un thème islamique et je rechercherai '
          'les versets correspondants pour vous. 📖';
    }

    return null;
  }

  String _buildIntro(String query) {
    final q = query.toLowerCase();
    if (q.contains('comment') || q.contains('pourquoi')) {
      return 'Voici ce que le Coran nous enseigne à ce sujet :';
    }
    if (q.contains('dit') || q.contains('parle') || q.contains('mentionne')) {
      return 'Le Coran en parle dans ces versets :';
    }
    if (q.contains('trouv') || q.contains('cherch')) {
      return 'Voici les versets les plus pertinents :';
    }
    return 'Le Coran aborde ce sujet dans ces versets :';
  }

  Future<ChatMessage> processQuery(String userQuery) async {
    _history.add(ChatMessage(
      text: userQuery,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // Réponse conversationnelle directe si hors-sujet coranique
    final directReply = _conversationalReply(userQuery);
    if (directReply != null) {
      final msg = ChatMessage(
        text: directReply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _history.add(msg);
      return msg;
    }

    final keywords = _extractKeywords(userQuery);

    final Set<String> seenKeys = {};
    final List<Map<String, int>> rawResults = [];

    for (final kw in keywords.take(5)) {
      if (rawResults.length >= 6) break;
      final hits = await QuranTextDb.instance.searchFr(kw);
      for (final r in hits) {
        final key = '${r['surah']}:${r['ayah']}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          rawResults.add(r);
        }
        if (rawResults.length >= 6) break;
      }
    }

    final verseKeys = rawResults
        .take(3)
        .map((r) => '${r['surah']}:${r['ayah']}')
        .toList();

    final verseMap = await QuranTextDb.instance.getVersesByKeys(verseKeys);
    final verses = verseKeys
        .map((k) => verseMap[k])
        .whereType<QVerse>()
        .toList();

    String responseText;
    if (verses.isEmpty) {
      responseText =
          'Je n\'ai pas trouvé de versets spécifiques pour cette question.\n\n'
          'Conseil : essayez un mot-clé plus simple (ex: "patience", "prière", "pardon").\n\n'
          'Assurez-vous également d\'avoir téléchargé la traduction française '
          'dans Paramètres → Téléchargements.';
    } else {
      responseText = _buildIntro(userQuery);
    }

    final assistantMsg = ChatMessage(
      text: responseText,
      isUser: false,
      verses: verses,
      timestamp: DateTime.now(),
    );
    _history.add(assistantMsg);
    return assistantMsg;
  }

  void clearHistory() => _history.clear();
}

/// Retourne le nom français d'une sourate (ex: "Al-Baqarah")
String surahNameFr(int surahNum) => surahFr[surahNum] ?? 'Sourate $surahNum';
