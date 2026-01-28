import 'package:flutter/material.dart';
import '../../services/quran_image_service.dart';
import '../reader_screen.dart';

/// Écran de chargement initial pour le téléchargement des images du Coran
class QuranLoader extends StatefulWidget {
  final String reading;
  final int initialPage;

  const QuranLoader({
    super.key,
    this.reading = 'hafs',
    this.initialPage = 1,
  });

  @override
  State<QuranLoader> createState() => _QuranLoaderState();
}

class _QuranLoaderState extends State<QuranLoader> {
  bool _isLoading = true;
  double _downloadProgress = 0.0;
  bool _isExtracting = false;
  String? _errorMessage;
  bool _hasNavigated = false;
  void _goToReaderOnce() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          reading: widget.reading,
          initialPage: widget.initialPage,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeQuranData();
    });
  }


  Future<void> _initializeQuranData() async {
    try {
      // Vérifier si les images sont déjà téléchargées
      final isReady = await QuranImageService.areImagesDownloaded();

      if (isReady) {
        // Déjà prêt, charger directement
        if (mounted) {
          setState(() => _isLoading = false);
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _goToReaderOnce();
            });
          }
        }
        return;
      }

      // Télécharger et extraire avec progression
      await QuranImageService.downloadAndExtractImages(
        onDownloadProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
            _isExtracting = false;
          });
        },
      );


      // Vérifier une dernière fois que tout est bien téléchargé
      final finalCheck = await QuranImageService.areImagesDownloaded();
      if (!finalCheck) {
        throw Exception('Les images n\'ont pas été correctement extraites');
      }

      // Terminer le chargement
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _goToReaderOnce();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    // Si ce n'est pas en cours de chargement, permettre de revenir
    if (!_isLoading) {
      return true;
    }

    // Afficher un dialogue de confirmation pendant le téléchargement
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Téléchargement en cours'),
        content: const Text(
          'Le téléchargement des pages du Coran est en cours. '
          'Si vous quittez maintenant, le téléchargement continuera en arrière-plan '
          'et sera disponible lors de votre prochaine visite.\n\n'
          'Voulez-vous vraiment quitter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Affichage d'erreur
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9F6), // Beige clair
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'خطأ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'ScheherazadeNew',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isLoading = true;
                      _downloadProgress = 0.0;
                    });
                    _initializeQuranData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32), // Vert islamique
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Écran de chargement élégant
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6), // Beige clair
        body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicateur de progression circulaire
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cercle de fond
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    // Indicateur avec pourcentage ou animation
                    if (_isExtracting)
                      const SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFD4AF37), // Or
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: _downloadProgress,
                          strokeWidth: 5,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D32), // Vert islamique
                          ),
                        ),
                      ),
                    // Pourcentage au centre
                    if (!_isExtracting)
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 60),

                // Texte arabe - Verset
                const Text(
                  '﴾إِنَّا سَنُلْقِي عَلَيْكَ قَوْلًا ثَقِيلًا﴿',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ScheherazadeNew',
                    color: Color(0xFF1B5E20), // Vert foncé
                    height: 1.8,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 24),

                // Texte français - Traduction
                const Text(
                  'Patientez, les paroles d\'Allah sont lourdes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF424242),
                    height: 1.5,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Message de statut
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExtracting ? Icons.inventory_2_outlined : Icons.cloud_download_outlined,
                        size: 18,
                        color: const Color(0xFFD4AF37), // Or
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isExtracting
                            ? 'Installation des pages...'
                            : _downloadProgress > 0
                                ? 'Téléchargement en cours...'
                                : 'Préparation...',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF424242),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info supplémentaire
                if (!_isExtracting && _downloadProgress > 0)
                  Text(
                    _getDownloadSize(_downloadProgress),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),

                const SizedBox(height: 32),

                // Note en bas
                Text(
                  'Téléchargement unique · Les prochaines ouvertures seront instantanées',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    ); // Fin du PopScope
  }

  String _getDownloadSize(double progress) {
    const totalSizeMB = 80.0;
    final downloadedMB = totalSizeMB * progress;
    return '${downloadedMB.toStringAsFixed(1)} MB / ${totalSizeMB.toStringAsFixed(0)} MB';
  }
}
