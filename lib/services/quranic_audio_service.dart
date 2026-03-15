import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service pour QuranicAudio via l'API Quran.com v4
/// Documentation: https://api.quran.com/api/v4/
class QuranicAudioService {
  static const String _baseUrl = 'https://api.quran.com/api/v4';
  static const String _audioBaseUrl = 'https://download.quranicaudio.com';
  
  final Dio _dio;

  QuranicAudioService({Dio? dio}) : _dio = dio ?? Dio();

  /// Récupère la liste de toutes les récitations disponibles
  /// Retourne: List<Map<String, dynamic>> avec structure:
  /// {
  ///   "id": int,
  ///   "reciter_name": String,
  ///   "style": String?,
  ///   "translated_name": {"name": String, "language_name": String}
  /// }
  Future<List<Map<String, dynamic>>> getRecitations() async {
    try {
      final response = await _dio.get('$_baseUrl/resources/recitations');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final recitations = data['recitations'] as List<dynamic>?;
        return recitations?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des récitations: $e');
      return [];
    }
  }

  /// Récupère l'URL audio d'une sourate spécifique pour un réciteur
  /// @param recitationId: ID du réciteur (1-12)
  /// @param chapterNumber: Numéro de la sourate (1-114)
  /// Retourne: URL audio directe ou null
  Future<String?> getChapterAudioUrl(int recitationId, int chapterNumber) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/chapter_recitations/$recitationId/$chapterNumber',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final audioFile = data['audio_file'] as Map<String, dynamic>?;
        return audioFile?['audio_url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur récupération audio sourate $chapterNumber pour récitation $recitationId: $e');
      return null;
    }
  }

  /// Récupère toutes les URLs audio (114 sourates) pour un réciteur
  /// @param recitationId: ID du réciteur (1-12)
  /// Retourne: Map<int, String> où key = chapter number, value = audio URL
  Future<Map<int, String>> getAllChapterUrls(int recitationId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/chapter_recitations/$recitationId',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final audioFiles = data['audio_files'] as List<dynamic>?;
        
        final Map<int, String> urls = {};
        if (audioFiles != null) {
          for (final file in audioFiles) {
            final fileMap = file as Map<String, dynamic>;
            final chapterId = fileMap['chapter_id'] as int?;
            final audioUrl = fileMap['audio_url'] as String?;
            if (chapterId != null && audioUrl != null) {
              urls[chapterId] = audioUrl;
            }
          }
        }
        return urls;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Erreur récupération URLs pour récitation $recitationId: $e');
      return {};
    }
  }

  /// Récupère les URLs audio verset par verset pour une sourate
  /// @param recitationId: ID du réciteur
  /// @param chapterNumber: Numéro de la sourate
  /// Retourne: List<Map<String, String>> avec {"verse_key": "1:1", "url": "..."}
  Future<List<Map<String, String>>> getVerseAudioUrls(
    int recitationId,
    int chapterNumber,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/recitations/$recitationId/by_chapter/$chapterNumber',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final audioFiles = data['audio_files'] as List<dynamic>?;
        
        if (audioFiles != null) {
          return audioFiles.map((file) {
            final fileMap = file as Map<String, dynamic>;
            return {
              'verse_key': fileMap['verse_key'] as String? ?? '',
              'url': 'https://verses.quran.com/${fileMap['url'] as String? ?? ''}',
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur récupération versets audio: $e');
      return [];
    }
  }

  /// Construction rapide d'URL audio pour une sourate
  /// Format: https://download.quranicaudio.com/qdc/{reciter_folder}/{chapter}.mp3
  /// Cette méthode est un fallback si l'API ne répond pas
  /// 
  /// Mapping des réciteurs principaux (à ajuster selon vos besoins):
  /// - 1: AbdulBaset (Mujawwad)
  /// - 2: AbdulBaset (Murattal)  
  /// - 3: Sudais
  /// - 4: Abu Bakr al-Shatri
  /// - 7: Mishari al-Afasy
  /// - etc.
  String? buildChapterUrlFallback(int recitationId, int chapterNumber) {
    final Map<int, String> reciterFolders = {
      1: 'abdul_basit_mujawwad',
      2: 'abdulbaset',
      3: 'abdurrahmaan_as-sudays',
      4: 'abu_bakr_ash-shaatree',
      5: 'hani_ar-rifai',
      6: 'mahmood_khaleel_al-husaree',
      7: 'mishari_al_afasy/murattal',
      8: 'muhammad_siddeeq_al-minshaawee_mujawwad',
      9: 'muhammad_siddiq_al-minshawi',
      10: 'saud_ash-shuraim',
      11: 'mohammad_al_tablaway',
      12: 'mahmood_khaleel_al-husaree_teach',
    };

    final folder = reciterFolders[recitationId];
    if (folder == null) return null;

    final paddedChapter = chapterNumber.toString().padLeft(3, '0');
    return '$_audioBaseUrl/qdc/$folder/$paddedChapter.mp3';
  }
}
