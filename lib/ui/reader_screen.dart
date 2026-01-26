// ============================
// READER SCREEN FINAL V4
// ============================

import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../asset_manager.dart';
import '../hizb_juzz.dart';
import '../surah_name.dart';
import '../services/reading_history_service.dart';
import '../services/bookmark_service.dart';
import 'dart:async';


class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText(this.text, {Key? key, this.style, required this.gradient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final int initialPage;
  final String reading;

  const ReaderScreen({super.key, this.initialPage = 1, this.reading = 'hafs'}) : super();

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int currentPage;
  String currentReading = 'hafs';
  late PageController _pageController;
  bool _isReady = false;
  List<Map<String, dynamic>> fullSurahList = [];
  bool _showUI = true;
  Timer? _saveTimer;
  
  // Cache pour les images préchargées
  final Map<int, File?> _imageCache = {};
  final int _preloadRange = 3; // Nombre de pages à précharger avant/après
  
  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    currentReading = widget.reading;
    final startPage = (widget.initialPage < 1) ? 1 : (widget.initialPage > 604 ? 604 : widget.initialPage);
    _pageController = PageController(initialPage: startPage - 1);
    _pageController.addListener(_onPageScroll);
    _initApp();
  }
  
  void _onPageScroll() {
    // Précharger les pages adjacentes pendant le scroll
    final currentIndex = _pageController.page?.round() ?? 0;
    _preloadPages(currentIndex + 1);
  }
  
  Future<void> _preloadPages(int centerPage) async {
    // Précharger les pages dans une plage autour de la page actuelle
    for (int offset = -_preloadRange; offset <= _preloadRange; offset++) {
      final pageNum = centerPage + offset;
      if (pageNum >= 1 && pageNum <= 604 && !_imageCache.containsKey(pageNum)) {
        _loadPageIntoCache(pageNum);
      }
    }
    
    // Nettoyer le cache des pages trop éloignées
    _cleanDistantPages(centerPage);
  }
  
  Future<void> _loadPageIntoCache(int pageNum) async {
    try {
      final file = await AssetManager.getPageFile(currentReading, pageNum);
      if (mounted) {
        setState(() {
          _imageCache[pageNum] = file;
        });
      }
    } catch (e) {
      debugPrint('Erreur préchargement page $pageNum: $e');
    }
  }
  
  void _cleanDistantPages(int centerPage) {
    final pagesToRemove = <int>[];
    _imageCache.forEach((pageNum, _) {
      if ((pageNum - centerPage).abs() > _preloadRange * 2) {
        pagesToRemove.add(pageNum);
      }
    });
    
    for (final pageNum in pagesToRemove) {
      _imageCache.remove(pageNum);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _imageCache.clear();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Plus besoin de télécharger tout le ZIP !
    // Les pages seront téléchargées à la demande via getPageFile()
    
    // Charger uniquement les données JSON
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;
    final added = <int>{};
    final List<Map<String, dynamic>> list = [];
    for (final v in quranData) {
      final id = v['surah'] as int;
      if (!added.contains(id)) {
        list.add({
          'id': id,
          'nameAr': v['sura_name'] ?? 'Sourate $id',
          'nameFr': surahFr[id] ?? 'Sourate $id',
          'page': v['page'] ?? 1,
        });
        added.add(id);
      }
    }
    
    // Précharger la page initiale en arrière-plan
    _preloadPages(currentPage);
    
    setState(() {
      fullSurahList = list;
      _isReady = true; // Prêt immédiatement !
    });
  }

  void _jumpToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              int? p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= 604) {
                _pageController.jumpToPage(p - 1);
              }
              Navigator.pop(context);
            },
            child: const Text('Aller'),
          )
        ],
      ),
    );
  }

  void _showSurahSelection() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: fullSurahList.length,
        itemBuilder: (context, index) {
          final s = fullSurahList[index];
          return ListTile(
            leading: Text('${s['id']}'),
            title: Text(s['nameFr']),
            trailing: Text(s['nameAr'], style: const TextStyle(fontFamily: 'Amiri')),
            onTap: () {
              _pageController.jumpToPage(s['page'] - 1);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  String _hizbText(int page) {
    if (hizbMap.isEmpty) return '';
    final h = hizbMap.lastWhere(
      (e) => e['start_page']! <= page,
      orElse: () => hizbMap.first,
    );
    return 'Hizb ${h['hizb']}';
  }

  String _juzzText(int page) {
    if (juzzMap.isEmpty) return '';
    final j = juzzMap.lastWhere(
      (e) => e['start_page']! <= page,
      orElse: () => juzzMap.first,
    );
    return 'Juzz ${j['juz']}';
  }
  
  // Sauvegarder dans l'historique
  void _saveToHistory(int page) {
    // Trouver la sourate correspondante
    if (fullSurahList.isEmpty) return;
    final surah = fullSurahList.firstWhere(
      (s) => s['page'] == page,
      orElse: () => fullSurahList.last,
    );

    
    ReadingHistoryService.instance.saveLastReading(
      page: page,
      surahId: surah['id'] as int,
      surahName: surah['nameFr'] as String,
      reading: currentReading,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Plus d'écran de chargement ! L'app démarre immédiatement
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    // Précharger les pages autour de la page actuelle
    if (_isReady) {
      _preloadPages(currentPage);
    }

    final surahNameFr = fullSurahList.isEmpty
      ? ''
      : (fullSurahList.lastWhere(
          (s) => (s['page'] as int) <= currentPage,
          orElse: () => fullSurahList.first,
        )['nameFr'] as String? ?? '');

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _showUI = !_showUI),
        child: Stack(
          children: [
            // PageView avec chargement optimisé
            PageView.builder(
              controller: _pageController,
              reverse: true,
              itemCount: 604,
              onPageChanged: (p) {
                setState(() => currentPage = p + 1);
                _preloadPages(p + 1);

                _saveTimer?.cancel();
                _saveTimer = Timer(const Duration(milliseconds: 350), () {
                  if (!mounted) return;
                  _saveToHistory(p + 1);
                });
              },

              itemBuilder: (context, i) {
                final pageNum = i + 1;
                
                // Utiliser le cache si disponible
                if (_imageCache.containsKey(pageNum) && _imageCache[pageNum] != null) {
                  final imageFile = _imageCache[pageNum]!;
                  return _buildPageContent(imageFile, isLandscape, context);
                }
                
                // Sinon charger de manière asynchrone
                return FutureBuilder<File>(
                  future: AssetManager.getPageFile(currentReading, pageNum),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Affichage élégant pendant le chargement
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Indicateur circulaire animé
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      strokeWidth: 6,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    Center(
                                      child: Icon(
                                        Icons.menu_book_outlined,
                                        size: 36,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Numéro de page
                              Text(
                                'Page $pageNum',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Message de chargement
                              Text(
                                'Chargement en cours...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Info additionnelle
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.hourglass_bottom,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Première ouverture',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.orange),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de téléchargement',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vérifiez votre connexion Internet',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => setState(() {
                                // Force le rechargement
                                _imageCache.remove(pageNum);
                              }),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final imageFile = snapshot.data!;
                    // Mettre en cache après chargement
                    _imageCache[pageNum] = imageFile;
                    return _buildPageContent(imageFile, isLandscape, context);
                  },
                );
              },
            ),

            // Barre supérieure : flèche retour + Juzz/Hizb
            if (_showUI)
              Positioned(
                top: 20,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Opacity(
                      opacity: 0.5,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_juzzText(currentPage)} ${_hizbText(currentPage)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    FutureBuilder<bool>(
                      future: BookmarkService.instance.isBookmarked(currentPage),
                      builder: (context, snapshot) {
                        final isBookmarked = snapshot.data ?? false;
                        return Opacity(
                          opacity: 0.5,
                          child: IconButton(
                            icon: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              size: 24,
                              color: isBookmarked ? Colors.amber : Colors.black54,
                            ),
                            onPressed: () async {
                              if (isBookmarked) {
                                await BookmarkService.instance.removeBookmark(currentPage);
                              } else {
                                if (fullSurahList.isEmpty) return;
                                final surah = fullSurahList.lastWhere(
                                  (s) => s['page'] <= currentPage,
                                  orElse: () => fullSurahList.first,
                                );

                                await BookmarkService.instance.addBookmark(
                                  Bookmark(
                                    page: currentPage,
                                    surahId: surah['id'] as int,
                                    surahName: surah['nameFr'] as String,
                                    createdAt: DateTime.now(),
                                  ),
                                );
                              }
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Barre inférieure 
            if (_showUI)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: isLandscape
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // plus fin
                            decoration: BoxDecoration(
                              color: Colors.black54.withOpacity(0.25), // plus transparent
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Sourate
                                TextButton.icon(
                                  onPressed: () => _showSurahSelection(),
                                  icon: const Icon(Icons.menu_book, color: Colors.white, size: 18),
                                  label: Text(
                                    fullSurahList.isEmpty
                                        ? ''
                                        : fullSurahList.lastWhere(
                                            (s) => s['page'] <= currentPage,
                                            orElse: () => fullSurahList.first,
                                          )['nameFr'],
                                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // Numéro de page
                                InkWell(
                                  onTap: () => _jumpToPageDialog(),
                                  child: CircleAvatar(
                                    radius: 18, // légèrement plus petit
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    child: Text(
                                      '$currentPage',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                                // Hafs/Warsh
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      currentReading = (currentReading == 'hafs') ? 'warsh' : 'hafs';
                                      // Vider le cache pour recharger les images du nouveau type de lecture
                                      _imageCache.clear();
                                      // Précharger les pages autour de la page actuelle
                                      _preloadPages(currentPage);
                                    });
                                  },
                                  icon: Icon(Icons.auto_stories, color: Colors.brown.shade100, size: 18),
                                  label: Text(
                                    currentReading.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    
                    : SizedBox(
                        height: 40,
                        child: Stack(
                          children: [
                            // Bouton Sourate à gauche
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _showSurahSelection(),
                                icon: const Icon(Icons.menu_book, color: Colors.black54, size: 20),
                                label: Text(
                                  surahNameFr,
                                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // Bouton Hafs/Warsh à droite
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    currentReading = (currentReading == 'hafs') ? 'warsh' : 'hafs';
                                    // Vider le cache pour recharger les images du nouveau type de lecture
                                    _imageCache.clear();
                                    // Précharger les pages autour de la page actuelle
                                    _preloadPages(currentPage);
                                  });
                                },
                                icon: Icon(Icons.auto_stories, color: Colors.brown.shade300),
                                label: Text(
                                  currentReading.toUpperCase(),
                                  style: TextStyle(color: Colors.brown.shade400, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // Numéro de page au centre
                            Align(
                              alignment: Alignment.center,
                              child: InkWell(
                                onTap: () => _jumpToPageDialog(),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.transparent,
                                  child: Text(
                                    '$currentPage',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  // Méthode pour construire le contenu de la page avec optimisation
  Widget _buildPageContent(File imageFile, bool isLandscape, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLandscape) {
          return SingleChildScrollView(
            child: Image.file(
              imageFile,
              width: constraints.maxWidth,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
              // Pas de cache resize pour préserver la qualité maximale
            ),
          );
        } else {
          return Center(
            child: Image.file(
              imageFile,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              // Pas de cache resize pour préserver la qualité maximale
            ),
          );
        }
      },
    );
  }
}
