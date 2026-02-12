import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/youtube_rotation_service.dart';

enum QuranVideoMode {
  sufi, // Abdul Rashid Ali Sufi
  makkah, // Taraweeh Makkah
}

class YoutubeVideoCard extends StatefulWidget {
  final QuranVideoMode mode;

  const YoutubeVideoCard({
    super.key,
    this.mode = QuranVideoMode.sufi,
  });

  @override
  State<YoutubeVideoCard> createState() => _YoutubeVideoCardState();
}

class _YoutubeVideoCardState extends State<YoutubeVideoCard> {
  // Ratio (adaptatif selon téléphone) :
  // - 16/9 = YouTube classique
  // - 18/9 ou 2/1 = plus compact (moins haut)
  static const double _aspectRatio = 16 / 9;

  static const List<String> allowedSufiVideoIds = [
    'tRnuRmK9vuY',
    'qKZr7jTN-Ns',
    'UZo8dbjOg70',
    '0jZDhopMHdE',
    'wjpI6cHrwP8',
    'YMzSi5ugXUE',
  ];

  static const List<String> allowedMakkahVideoIds = [
    'ZehqB0mb9PI',
    'LU2knnAmirk',
    'rL3dTkOvbyg',
    'R7Af9hGsaVU',
  ];

  Timer? _rotationCheckTimer;
  String? _currentVideoId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _loadOrRotate();

    _rotationCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route?.isCurrent == false) return;
        _loadOrRotate();
      },
    );
  }

  @override
  void dispose() {
    _rotationCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrRotate() async {
    if (!mounted) return;

    try {
      final mode = widget.mode == QuranVideoMode.sufi ? 'sufi' : 'makkah';
      final allowedIds =
          widget.mode == QuranVideoMode.sufi ? allowedSufiVideoIds : allowedMakkahVideoIds;

      final videoId = await YoutubeRotationService.getOrRotateVideoId(
        mode: mode,
        allowedVideoIds: allowedIds,
      );

      if (!mounted) return;

      if (videoId == null) {
        setState(() {
          _currentVideoId = null;
          _isInitialized = true;
        });
        return;
      }

      if (videoId != _currentVideoId) {
        setState(() {
          _currentVideoId = videoId;
          _isInitialized = true;
        });

        // Précharge thumbnail (léger)
        final thumb = NetworkImage('https://img.youtube.com/vi/$videoId/sddefault.jpg');
        // ignore: unawaited_futures
        precacheImage(thumb, context);
      } else if (!_isInitialized) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Erreur chargement vidéo YouTube: $e');
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  Future<void> _openYoutubeVideo() async {
    final id = _currentVideoId;
    if (id == null) return;

    final url = Uri.parse('https://www.youtube.com/watch?v=$id');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erreur ouverture YouTube: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFFFAFAFA), const Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: _buildInner(context, isDark),
        ),
      ),
    );
  }

  Widget _buildInner(BuildContext context, bool isDark) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8A165)),
      );
    }

    if (_currentVideoId == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              'Aucune vidéo configurée',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _openYoutubeVideo,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: _ThumbnailWithFallback(videoId: _currentVideoId!),
            ),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailWithFallback extends StatefulWidget {
  final String videoId;
  const _ThumbnailWithFallback({required this.videoId});

  @override
  State<_ThumbnailWithFallback> createState() => _ThumbnailWithFallbackState();
}

class _ThumbnailWithFallbackState extends State<_ThumbnailWithFallback> {
  bool _useFallback = false;

  @override
  Widget build(BuildContext context) {
    final url = !_useFallback
        ? 'https://img.youtube.com/vi/${widget.videoId}/sddefault.jpg'
        : 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';

    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFFC8A165),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_useFallback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useFallback = true);
          });
          return const SizedBox.shrink();
        }
        return Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.white.withOpacity(0.5),
            size: 48,
          ),
        );
      },
    );
  }
}
