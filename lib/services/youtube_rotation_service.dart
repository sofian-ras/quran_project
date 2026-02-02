import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class YoutubeRotationService {
  static const Duration rotationPeriod = Duration(hours: 8);

  /// Obtient ou fait tourner l'ID vidéo selon la période de 8h
  /// 
  /// [mode]: Identifiant du mode (ex: 'sufi', 'makkah')
  /// [allowedVideoIds]: Liste des IDs vidéo autorisés
  /// 
  /// Retourne l'ID vidéo à afficher, ou null si aucune vidéo disponible
  static Future<String?> getOrRotateVideoId({
    required String mode,
    required List<String> allowedVideoIds,
  }) async {
    if (allowedVideoIds.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final currentIdKey = 'yt_current_video_id_$mode';
    final lastChangeKey = 'yt_last_change_ms_$mode';

    final currentId = prefs.getString(currentIdKey);
    final lastChangeMs = prefs.getInt(lastChangeKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Si on a déjà une vidéo et qu'elle est encore valide (< 8h)
    if (currentId != null && lastChangeMs != null) {
      final elapsedMs = now - lastChangeMs;
      final elapsed = Duration(milliseconds: elapsedMs);

      if (elapsed < rotationPeriod && allowedVideoIds.contains(currentId)) {
        // Vidéo toujours valide, on la garde
        return currentId;
      }
    }

    // Besoin de changer de vidéo
    String selectedId;
    
    if (allowedVideoIds.length > 1) {
      // Essayer de choisir une vidéo différente de la précédente
      final availableIds = allowedVideoIds.where((id) => id != currentId).toList();
      selectedId = availableIds.isNotEmpty
          ? availableIds[Random().nextInt(availableIds.length)]
          : allowedVideoIds[Random().nextInt(allowedVideoIds.length)];
    } else {
      // Une seule vidéo disponible
      selectedId = allowedVideoIds.first;
    }

    // Sauvegarder la nouvelle vidéo
    await prefs.setString(currentIdKey, selectedId);
    await prefs.setInt(lastChangeKey, now);

    return selectedId;
  }

  /// Force une nouvelle rotation immédiatement
  static Future<void> forceRotate({required String mode}) async {
    final prefs = await SharedPreferences.getInstance();
    final currentIdKey = 'yt_current_video_id_$mode';
    final lastChangeKey = 'yt_last_change_ms_$mode';

    await prefs.remove(currentIdKey);
    await prefs.remove(lastChangeKey);
  }
}
