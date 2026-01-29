import 'dart:io';
import 'package:flutter/material.dart';
import '../services/quran_image_service.dart';

class QuranPagePreloader {
  final Set<int> _inFlight = <int>{};
  final int range;

  QuranPagePreloader({this.range = 2});

  Future<void> preloadAround(BuildContext context, int page, String reading) async {
    final int start = (page - range).clamp(1, 604);
    final int end = (page + range).clamp(1, 604);

    for (int pageNum = start; pageNum <= end; pageNum++) {
      if (_inFlight.contains(pageNum)) continue;
      _inFlight.add(pageNum);

      try {
        final File file = await QuranImageService.getPageFile(reading, pageNum);
        if (!context.mounted) break;
        await precacheImage(FileImage(file), context);
      } catch (e) {
        debugPrint('Erreur preloading page $pageNum: $e');
      } finally {
        _inFlight.remove(pageNum);
      }
    }
  }
}
