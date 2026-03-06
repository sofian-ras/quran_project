// lib/services/tafsir_download_manager.dart
//
// Singleton qui gère les téléchargements de tafsir en arrière-plan.
// Les téléchargements survivent à la fermeture de l'écran bibliothèque.
// Une SnackBar globale est affichée à la fin via NavigationService.navigatorKey.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'tafsir_service.dart';
import 'navigation_service.dart';

class TafsirDownloadManager {
  static final instance = TafsirDownloadManager._();
  TafsirDownloadManager._();

  /// Progression par slug : null = inactif, 0.0–1.0 = en cours
  final Map<String, ValueNotifier<double?>> _progress = {};
  final Map<String, CancelToken> _tokens = {};

  ValueNotifier<double?> progressFor(String slug) =>
      _progress.putIfAbsent(slug, () => ValueNotifier(null));

  bool isDownloading(String slug) => _tokens.containsKey(slug);

  /// Lance le téléchargement. No-op si déjà en cours.
  Future<void> start(TafsirBook book) async {
    if (_tokens.containsKey(book.slug)) return;

    final token = CancelToken();
    _tokens[book.slug] = token;
    progressFor(book.slug).value = 0.0;

    bool success = false;
    try {
      await TafsirService.download(
        book,
        cancelToken: token,
        onProgress: (p, _) => progressFor(book.slug).value = p,
      );
      success = true;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        debugPrint('[TafsirDownloadManager] erreur: $e');
      }
    } catch (e) {
      debugPrint('[TafsirDownloadManager] erreur: $e');
    } finally {
      _tokens.remove(book.slug);
      progressFor(book.slug).value = null;
    }

    if (success) _notifyCompletion(book.nameAr);
  }

  void cancel(String slug) => _tokens[slug]?.cancel();

  void _notifyCompletion(String bookNameAr) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          content: Text('« $bookNameAr » téléchargé'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }
}
