// lib/ui/widgets/quran_page_view.dart
//
// REMPLACEMENT COMPLET de ton quran_page_view.dart existant.
// Ajoute : overlay verset sélectionnable par-dessus l'image PNG.
//
// Changements vs version originale :
//  - _buildPageImage() remplace InteractiveViewer par un Stack
//    avec AyahSelectionOverlay par-dessus l'image
//  - LayoutBuilder pour récupérer la taille d'affichage exacte
//  - Gestion de selectedVerseKey + appel de AyahActionSheet
//  - InteractiveViewer conservé mais son child est le Stack

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/quran_pages_hitbox_db.dart';
import '../../services/quran_image_service.dart';
import 'ayah_selection_overlay.dart';
import 'ayah_bubble.dart';

class QuranPageView extends StatefulWidget {
  final String reading; // 'hafs' ou 'warsh'
  final int initialPage;
  final int totalPages;
  final Function(int)? onPageChanged;
  final bool enablePrecaching;

  /// Taille réelle des images PNG (en pixels).
  /// Hafs  : 1300 × 2103 (vérifie avec tes fichiers)
  /// Warsh : peut différer
  /// Si null → coordonnées normalisées [0..1] attendues dans la DB
  final Size imagePxSize;

  const QuranPageView({
    super.key,
    required this.reading,
    this.initialPage = 1,
    this.totalPages = 604,
    this.onPageChanged,
    this.enablePrecaching = true,
    this.imagePxSize = const Size(1024, 1657), // Hafs 1024px
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  final Set<int> _loadingPages = {};
  Timer? _precacheDebounce;
  int _lastCenterPage = -1;
  late PageController _pageController;
  final Map<int, File> _imageCache = {};
  bool _isLoading = true;
  String? _errorMessage;

  /// Verset actuellement sélectionné (format "surah:ayah"), null = aucun
  String? _selectedVerseKey;

  static const int _precacheRange = 3;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        await QuranPagesHitboxDb.instance.ensureFromAsset(
          assetPath: 'assets/data/quranpages1024.sqlite',
        );
      } catch (e) {
        debugPrint('Erreur chargement hitbox: $e');
      }
    }();
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _initializeImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.addListener(_onPageScroll);
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _imageCache.clear();
    _precacheDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeImages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imagesAvailable = await QuranImageService.areImagesDownloaded();
      if (!imagesAvailable) {
        await QuranImageService.downloadAndExtractImages(
          onDownloadProgress: (p) =>
              debugPrint('Téléchargement: ${(p * 100).toStringAsFixed(1)}%'),
        );
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _precachePages(widget.initialPage);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des images: $e';
      });
    }
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final int currentPage = (_pageController.page?.round() ?? 0) + 1;
    if (currentPage == _lastCenterPage) return;
    _lastCenterPage = currentPage;
    // Désélectionner quand on tourne la page
    if (_selectedVerseKey != null) {
      AyahBubble.dismiss();
      setState(() => _selectedVerseKey = null);
    }
    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _precachePages(currentPage);
    });
  }

  Future<void> _precachePages(int centerPage) async {
    if (!widget.enablePrecaching) return;
    for (int i = -_precacheRange; i <= _precacheRange; i++) {
      final pageNum = centerPage + i;
      if (pageNum >= 1 && pageNum <= widget.totalPages) {
        if (!_imageCache.containsKey(pageNum) &&
            !_loadingPages.contains(pageNum)) {
          _loadingPages.add(pageNum);
          _loadPageIntoCache(pageNum)
              .whenComplete(() => _loadingPages.remove(pageNum));
        }
      }
    }
    _cleanDistantPages(centerPage);
  }

  Future<void> _loadPageIntoCache(int pageNum) async {
    try {
      final file =
          await QuranImageService.getPageFile(widget.reading, pageNum);
      if (!mounted) return;
      _imageCache[pageNum] = file;
      if (context.mounted) {
        await precacheImage(FileImage(file), context);
      }
    } catch (e) {
      debugPrint('Erreur chargement page $pageNum: $e');
    }
  }

  void _cleanDistantPages(int centerPage) {
    final toRemove = <int>[];
    _imageCache.forEach((pageNum, _) {
      if ((pageNum - centerPage).abs() > _precacheRange * 2) {
        toRemove.add(pageNum);
      }
    });
    for (final p in toRemove) {
      _imageCache.remove(p);
    }
  }

  // ── Gestion de la sélection ──────────────────────────────────────────────

  void _onAyahTapped(int surah, int ayah, Rect? globalRect) {
    if (surah == -1) {
      AyahBubble.dismiss();
      setState(() => _selectedVerseKey = null);
      return;
    }

    final key = '$surah:$ayah';
    setState(() => _selectedVerseKey = key);

    if (globalRect != null) {
      AyahBubble.show(
        context,
        surah: surah,
        ayah: ayah,
        anchorGlobalRect: globalRect,
        onDismiss: () {
          if (mounted) setState(() => _selectedVerseKey = null);
        },
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Préparation des pages du Coran...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeImages,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      reverse: true, // sens arabe droite → gauche
      itemCount: widget.totalPages,
      onPageChanged: (index) {
        widget.onPageChanged?.call(index + 1);
        _precachePages(index + 1);
      },
      itemBuilder: (context, index) => _buildPage(index + 1),
    );
  }

  Widget _buildPage(int pageNum) {
    final cached = _imageCache[pageNum];

    if (cached != null) {
      return _buildPageWithOverlay(cached, pageNum);
    }

    if (!_loadingPages.contains(pageNum)) {
      _loadingPages.add(pageNum);
      _loadPageIntoCache(pageNum).whenComplete(() {
        _loadingPages.remove(pageNum);
        if (mounted) setState(() {});
      });
    }

    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }

  /// ── Cœur de la fonctionnalité ────────────────────────────────────────────
  ///
  /// Stack : image PNG + overlay Positioned DIRECTEMENT dans le Stack.
  /// Le Positioned doit être enfant direct du Stack pour que left/top/
  /// width/height soient pris en compte. Sinon les coordonnées locales
  /// du GestureDetector sont relatives au coin supérieur gauche de l'écran
  /// au lieu du coin supérieur gauche de l'image → conversion fausse.
  Widget _buildPageWithOverlay(File imageFile, int pageNum) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      panEnabled: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final displaySize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          // Zone réelle de l'image dans le conteneur (BoxFit.contain).
          final rect = _imageRect(displaySize);

          return Stack(
            children: [
              // ── 1. Image PNG ──────────────────────────────
              SizedBox(
                width: displaySize.width,
                height: displaySize.height,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
              ),

              // ── 2. Overlay des versets — Positioned DIRECT dans Stack ──
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: AyahSelectionOverlay(
                  page: pageNum,
                  displaySize: Size(rect.width, rect.height),
                  imageSize: widget.imagePxSize,
                  selectedVerseKey: _selectedVerseKey,
                  onAyahTap: _onAyahTapped,
                  onAyahLongPress: _onAyahTapped,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Calcule la Rect dans laquelle l'image est réellement dessinée
  /// (BoxFit.contain centre l'image et laisse des marges letterbox).
  Rect _imageRect(Size displaySize) {
    final imgAspect = widget.imagePxSize.width / widget.imagePxSize.height;
    final dispAspect = displaySize.width / displaySize.height;

    double imgW, imgH, offsetX, offsetY;

    if (imgAspect > dispAspect) {
      imgW = displaySize.width;
      imgH = imgW / imgAspect;
      offsetX = 0;
      offsetY = (displaySize.height - imgH) / 2;
    } else {
      imgH = displaySize.height;
      imgW = imgH * imgAspect;
      offsetX = (displaySize.width - imgW) / 2;
      offsetY = 0;
    }

    return Rect.fromLTWH(offsetX, offsetY, imgW, imgH);
  }
}
