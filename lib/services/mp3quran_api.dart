import 'package:dio/dio.dart';

class Mp3QuranApi {
  Mp3QuranApi._();
  static final Mp3QuranApi instance = Mp3QuranApi._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Récupère la baseUrl pour un réciteur donné
  /// Préfère un moshaf avec "hafs" et "murattal" dans le nom, sinon prend le premier
  /// Normalise l'URL en enlevant le slash final si présent
  Future<String?> fetchBaseUrlForReciter(int reciterId) async {
    try {
      final response = await _dio.get(
        'https://www.mp3quran.net/api/v3/reciters',
        queryParameters: {
          'language': 'eng',
          'reciter': reciterId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final reciters = data['reciters'] as List<dynamic>?;

        if (reciters != null && reciters.isNotEmpty) {
          final reciter = reciters.first as Map<String, dynamic>;
          final moshafs = reciter['moshaf'] as List<dynamic>?;

          if (moshafs != null && moshafs.isNotEmpty) {
            // Chercher un moshaf avec "hafs" et "murattal" dans le nom
            Map<String, dynamic>? preferredMoshaf;
            
            for (final m in moshafs) {
              final moshaf = m as Map<String, dynamic>;
              final name = (moshaf['name'] ?? '').toString().toLowerCase();
              
              if (name.contains('hafs') && name.contains('murattal')) {
                preferredMoshaf = moshaf;
                break;
              }
            }

            // Si pas trouvé, prendre le premier
            preferredMoshaf ??= moshafs.first as Map<String, dynamic>;

            // Extraire et normaliser l'URL
            String? server = preferredMoshaf['server'] as String?;
            if (server != null && server.isNotEmpty) {
              // Enlever le slash final si présent
              if (server.endsWith('/')) {
                server = server.substring(0, server.length - 1);
              }
              return server;
            }
          }
        }
      }
    } catch (e) {
      // Log l'erreur mais ne crash pas
      print('Mp3QuranApi: Erreur lors de la récupération de baseUrl pour reciter $reciterId: $e');
    }

    return null;
  }

  /// Précharge les baseUrl pour une liste de reciterIds
  /// Retourne un Map<int, String> avec les baseUrl récupérées
  Future<Map<int, String>> preloadBaseUrls(List<int> reciterIds) async {
    final Map<int, String> result = {};

    // Exécuter les requêtes en parallèle pour être plus rapide
    final futures = reciterIds.map((id) async {
      final baseUrl = await fetchBaseUrlForReciter(id);
      if (baseUrl != null) {
        result[id] = baseUrl;
      }
    });

    await Future.wait(futures);
    return result;
  }
}
