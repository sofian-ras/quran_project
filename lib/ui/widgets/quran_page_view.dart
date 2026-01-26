import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/quran_image_service.dart';
import 'dart:async';

/// Widget PageView pour afficher les pages du Coran avec pre-caching intelligent
class QuranPageView extends StatefulWidget {
  final String reading; // 'hafs' ou 'warsh'
  final int initialPage;
  final int totalPages;
  final Function(int)? onPageChanged;
  final bool enablePrecaching;

  const QuranPageView({
    super.key,
    required this.reading,
    this.initialPage = 1,
    this.totalPages = 604,
    this.onPageChanged,
    this.enablePrecaching = true,
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

  // Plage de pre-caching (pages avant et après)
  static const int _precacheRange = 3;

  @override
  void initState() {
    super.initState();
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
    _precacheDebounce = null;
    super.dispose();
  }

  /// Initialise les images (télécharge si nécessaire)
  Future<void> _initializeImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Vérifier si les images sont disponibles
      final imagesAvailable = await QuranImageService.areImagesDownloaded();

      if (!imagesAvailable) {
        // Télécharger et extraire les images
        await QuranImageService.downloadAndExtractImages(
          onDownloadProgress: (progress) {
            // Optionnel: afficher la progression
            debugPrint('Téléchargement: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );
      }

      // Pre-charger la page initiale et les pages suivantes
      setState(() {
        _isLoading = false;
      });
      // Lancer le precache après la 1ère frame (ne bloque pas l'entrée)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _precachePages(widget.initialPage);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des images: $e';
      });
      debugPrint('Erreur d\'initialisation: $e');
    }
  }

  /// Écoute le défilement pour pre-cacher les pages
  void _onPageScroll() {
    if (!_pageController.hasClients) return;

    final int currentPage = (_pageController.page?.round() ?? 0) + 1;

    // évite de refaire la même chose
    if (currentPage == _lastCenterPage) return;
    _lastCenterPage = currentPage;

    // debounce: attendre la fin d’un petit mouvement
    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _precachePages(currentPage);
    });
  }


  /// Pre-cache les pages autour de la page courante
  Future<void> _precachePages(int centerPage) async {
    if (!widget.enablePrecaching) return;

    // Déterminer les pages à pre-cacher
    final pagesToCache = <int>[];
    for (int i = -_precacheRange; i <= _precacheRange; i++) {
      final pageNum = centerPage + i;
      if (pageNum >= 1 && pageNum <= widget.totalPages) {
        pagesToCache.add(pageNum);
      }
    }

    // Charger les pages en cache
    for (final pageNum in pagesToCache) {
      if (!_imageCache.containsKey(pageNum) && !_loadingPages.contains(pageNum)) {
        _loadingPages.add(pageNum);
        _loadPageIntoCache(pageNum).whenComplete(() {
          _loadingPages.remove(pageNum);
        });
      }
    }

    // Nettoyer les pages trop éloignées
    _cleanDistantPages(centerPage);
  }

  /// Charge une page dans le cache
  Future<void> _loadPageIntoCache(int pageNum) async {
    try {
      final file = await QuranImageService.getPageFile(widget.reading, pageNum);

      if (!mounted) return;

      // juste remplir le cache mémoire (pas besoin de rebuild)
      _imageCache[pageNum] = file;

      // Pre-cacher l'image dans le cache de Flutter
      if (context.mounted) {
        await precacheImage(FileImage(file), context);
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la page $pageNum: $e');
    }
  }

  /// Nettoie les pages trop éloignées du cache
  void _cleanDistantPages(int centerPage) {
    final pagesToRemove = <int>[];
    
    _imageCache.forEach((pageNum, _) {
      if ((pageNum - centerPage).abs() > _precacheRange * 2) {
        pagesToRemove.add(pageNum);
      }
    });

    for (final pageNum in pagesToRemove) {
      _imageCache.remove(pageNum);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Affichage pendant le chargement initial
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Préparation des pages du Coran...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Première utilisation, cela peut prendre quelques minutes',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Affichage en cas d'erreur
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
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

    // PageView principal
    return PageView.builder(
      controller: _pageController,
      reverse: true, // Défilement de droite à gauche (sens arabe)
      itemCount: widget.totalPages,
      onPageChanged: (index) {
        final pageNum = index + 1;
        widget.onPageChanged?.call(pageNum);
        _precachePages(pageNum);
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return _buildPage(pageNum);
      },
    );
  }

  /// Construit une page individuelle
  Widget _buildPage(int pageNum) {
    final cached = _imageCache[pageNum];
    if (cached != null) {
      return _buildPageImage(cached);
    }

    // Lancer le chargement en arrière-plan (sans FutureBuilder)
    if (!_loadingPages.contains(pageNum)) {
      _loadingPages.add(pageNum);
      _loadPageIntoCache(pageNum).whenComplete(() {
        _loadingPages.remove(pageNum);
        if (mounted) {
          setState(() {});
        }
      });
    }

    // Placeholder léger et discret
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }



  /// Construit l'affichage de l'image de la page
  Widget _buildPageImage(File imageFile) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Image corrompue',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
