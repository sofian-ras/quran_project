import 'dart:io';
import 'package:flutter/material.dart';
import 'quran_image_service.dart';

class QuranPagePreloader {
  final Set<int> _inFlight = <int>{};
  final int range;

  QuranPagePreloader({this.range = 2});

  Future<void> preloadAround(BuildContext context, int page, String reading) async {
    final int start = (page - range).clamp(1, 604);
    final int end = (page + range).clamp(1, 604);

    final futures = <Future<void>>[];
    for (int pageNum = start; pageNum <= end; pageNum++) {
      if (_inFlight.contains(pageNum)) continue;
      _inFlight.add(pageNum);
      futures.add(_preloadOne(context, pageNum, reading));
    }
    await Future.wait(futures);
  }

  Future<void> _preloadOne(BuildContext context, int pageNum, String reading) async {
    try {
      final File file = await QuranImageService.getPageFile(reading, pageNum);
      if (!context.mounted) return;
      await precacheImage(FileImage(file), context);
    } catch (e) {
      debugPrint('Erreur preloading page $pageNum: $e');
    } finally {
      _inFlight.remove(pageNum);
    }
  }
}
