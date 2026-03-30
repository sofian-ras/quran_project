import 'package:flutter/material.dart';
import '../widgets/quran_page_view.dart';
import '../../services/quran_image_service.dart';

/// Exemple d'écran de lecture du Coran
class QuranReaderExampleScreen extends StatefulWidget {
  final String reading;
  final int initialPage;

  const QuranReaderExampleScreen({
    super.key,
    this.reading = 'hafs',
    this.initialPage = 1,
  });

  @override
  State<QuranReaderExampleScreen> createState() =>
      _QuranReaderExampleScreenState();
}

class _QuranReaderExampleScreenState extends State<QuranReaderExampleScreen> {
  int _currentPage = 1;
  String _currentReading = 'hafs';
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _currentReading = widget.reading;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView principal
            GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: QuranPageView(
                reading: _currentReading,
                initialPage: _currentPage,
                totalPages: 604,
                enablePrecaching: true,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
              ),
            ),

            // Contrôles overlay
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),

            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(),
              ),
          ],
        ),
      ),
    );
  }

  /// Barre supérieure avec titre et actions
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Page $_currentPage',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Sélecteur de lecture
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_book, color: Colors.white),
            onSelected: (reading) {
              setState(() {
                _currentReading = reading;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'hafs',
                child: Text('Hafs'),
              ),
              const PopupMenuItem(
                value: 'warsh',
                child: Text('Warsh'),
              ),
            ],
          ),

          // Paramètres
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
    );
  }

  /// Barre inférieure avec informations et navigation
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur de progression
          Row(
            children: [
              Text(
                'Page $_currentPage / 604',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: _currentPage / 604,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Infos lecture
          Text(
            'Lecture: ${_currentReading.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Dialogue des paramètres
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paramètres'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton pour vider le cache
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Vider le cache'),
              subtitle: FutureBuilder<int>(
                future: QuranImageService.instance.getCacheSize(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final sizeMB = (snapshot.data! / (1024 * 1024)).toStringAsFixed(1);
                    return Text('$sizeMB MB utilisés');
                  }
                  return const Text('Calcul...');
                },
              ),
              onTap: () async {
                Navigator.pop(context);
                await _clearCache();
              },
            ),

            // Bouton pour re-télécharger
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Re-télécharger les images'),
              subtitle: const Text('En cas de problème d\'affichage'),
              onTap: () async {
                Navigator.pop(context);
                await _redownloadImages();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Vide le cache des images
  Future<void> _clearCache() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await QuranImageService.instance.clearCache();

      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache vidé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Re-télécharge les images
  Future<void> _redownloadImages() async {
    try {
      // Vider le cache d'abord
      await QuranImageService.instance.clearCache();

      // Relancer l'écran
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuranReaderExampleScreen(
              reading: _currentReading,
              initialPage: _currentPage,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
