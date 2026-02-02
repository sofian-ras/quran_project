import 'dart:convert';
import 'package:http/http.dart' as http;

class YoutubeVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  YoutubeVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    return YoutubeVideo(
      videoId: json['id']['videoId'] as String,
      title: json['snippet']['title'] as String,
      channelTitle: json['snippet']['channelTitle'] as String,
      thumbnailUrl: json['snippet']['thumbnails']['high']['url'] as String,
    );
  }
}

class YoutubeService {
  // TODO: Remplacez par votre clé API YouTube Data v3
  static const String _apiKey = 'YOUR_YOUTUBE_API_KEY_HERE';

  // Allowlist des chaînes pour Abdul Rashid Ali Sufi
  static const Set<String> allowedSufiChannelIds = {
    // TODO: Ajoutez les channelIds exacts des chaînes officielles de Abdul Rashid Ali Sufi
    'TODO_SUFI_CHANNEL_ID_1',
    'TODO_SUFI_CHANNEL_ID_2',
    // Exemple: 'UCxxxxxxxxxxxxxxxxxxxx',
  };

  // Allowlist des chaînes pour Taraweeh Makkah
  static const Set<String> allowedMakkahChannelIds = {
    // TODO: Ajoutez les channelIds exacts des chaînes officielles de Masjid al-Haram
    'TODO_MAKKAH_CHANNEL_ID_1',
    'TODO_MAKKAH_CHANNEL_ID_2',
    // Exemple: 'UCxxxxxxxxxxxxxxxxxxxx',
  };

  // Mots-clés requis (au moins un doit être présent)
  static const Set<String> _requiredKeywords = {
    'quran',
    'surah',
    'taraweeh',
    'masjid',
    'haram',
    'recitation',
  };

  // Mots-clés à exclure
  static const Set<String> _excludedKeywords = {
    'remix',
    'instrumental',
    'music',
    'cover',
  };

  /// Récupère les vidéos de Abdul Rashid Ali Sufi
  Future<List<YoutubeVideo>> fetchSufiVideos() async {
    return _fetchVideos(
      query: 'quran recitation abdurashid sufi',
      allowedChannelIds: allowedSufiChannelIds,
    );
  }

  /// Récupère les vidéos Taraweeh de La Mecque
  Future<List<YoutubeVideo>> fetchMakkahTaraweehVideos() async {
    return _fetchVideos(
      query: 'taraweeh makkah masjid al haram',
      allowedChannelIds: allowedMakkahChannelIds,
    );
  }

  /// Méthode privée pour récupérer et filtrer les vidéos
  Future<List<YoutubeVideo>> _fetchVideos({
    required String query,
    required Set<String> allowedChannelIds,
  }) async {
    try {
      final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
        'part': 'snippet',
        'type': 'video',
        'videoEmbeddable': 'true',
        'maxResults': '20',
        'q': query,
        'key': _apiKey,
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('YouTube API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];

      final videos = <YoutubeVideo>[];

      for (final item in items) {
        final snippet = item['snippet'] as Map<String, dynamic>;
        final channelId = snippet['channelId'] as String;
        final title = (snippet['title'] as String).toLowerCase();
        final description = (snippet['description'] as String).toLowerCase();
        final combined = '$title $description';

        // Filtre 1: Vérifier que le channelId est dans l'allowlist
        if (!allowedChannelIds.contains(channelId)) {
          continue;
        }

        // Filtre 2: Vérifier qu'au moins un mot-clé requis est présent
        final hasRequiredKeyword = _requiredKeywords.any(
          (keyword) => combined.contains(keyword),
        );
        if (!hasRequiredKeyword) {
          continue;
        }

        // Filtre 3: Vérifier qu'aucun mot-clé exclu n'est présent
        final hasExcludedKeyword = _excludedKeywords.any(
          (keyword) => combined.contains(keyword),
        );
        if (hasExcludedKeyword) {
          continue;
        }

        // Vidéo valide, l'ajouter à la liste
        videos.add(YoutubeVideo.fromJson(item));
      }

      return videos;
    } catch (e) {
      print('Erreur lors de la récupération des vidéos YouTube: $e');
      return [];
    }
  }
}
