import 'package:flutter/material.dart';
import '../../services/quran_image_service.dart';
import '../../services/font_download_service.dart';
import '../widgets/download_progress_widget.dart';
import '../reader_screen.dart';

/// Écran de chargement initial avec progression de téléchargement
class InitialLoadingScreen extends StatefulWidget {
  final String reading;
  final int initialPage;

  const InitialLoadingScreen({
    super.key,
    this.reading = 'hafs',
    this.initialPage = 1,
  });

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen> {
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isExtracting = false;
  String _statusMessage = 'Vérification...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    try {
      final imagesReady = await QuranImageService.areImagesDownloaded();
      final fontsReady  = await FontDownloadService.areFontsDownloaded();

      if (imagesReady && fontsReady) {
        _navigateToReader();
        return;
      }

      // ── 1. Téléchargement des images ─────────────────────────────────────
      if (!imagesReady) {
        setState(() {
          _isDownloading = true;
          _statusMessage = 'Téléchargement des pages du Coran';
        });

        await QuranImageService.downloadAndExtractImages(
          onDownloadProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
                _statusMessage = 'Téléchargement des pages…';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isExtracting = true;
            _statusMessage = 'Extraction des fichiers';
          });
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // ── 2. Téléchargement des polices ─────────────────────────────────────
      if (!fontsReady) {
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _isDownloading = true;
            _downloadProgress = 0.0;
            _statusMessage = 'Téléchargement des polices';
          });
        }

        await FontDownloadService.downloadAndExtractFonts(
          onDownloadProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
                _statusMessage = 'Téléchargement des polices…';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isExtracting = true;
            _statusMessage = 'Extraction des polices';
          });
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _navigateToReader();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isExtracting = false;
          _errorMessage = 'Erreur lors du téléchargement: $e';
        });
      }
    }
  }

  void _navigateToReader() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          reading: widget.reading,
          initialPage: widget.initialPage,
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _downloadProgress = 0.0;
    });
    _checkAndDownload();
  }

  @override
  Widget build(BuildContext context) {
    // Affichage d'erreur
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Erreur de téléchargement',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Affichage de progression
    return Scaffold(
      body: DownloadProgressWidget(
        progress: _downloadProgress,
        message: _statusMessage,
        isExtracting: _isExtracting,
        subtitle: _isDownloading
            ? 'Téléchargement unique - Les prochaines ouvertures seront instantanées'
            : null,
      ),
    );
  }
}
