import 'package:flutter/material.dart';
import '../../services/font_download_service.dart';
import '../../services/quran_translation_pack_service.dart';
import '../widgets/download_progress_widget.dart';
import '../bottom_nav_shell.dart';

/// Écran de chargement initial avec progression de téléchargement
class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({super.key});

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
      final fontsReady       = await FontDownloadService.areFontsDownloaded();
      final translationReady = await QuranTranslationPackService.isPackReady(AppLang.fr);

      if (fontsReady && translationReady) {
        _navigateToReader();
        return;
      }

      // ── 1. Polices QCF ────────────────────────────────────────────────────
      if (!fontsReady) {
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _isDownloading = true;
            _downloadProgress = 0.0;
            _statusMessage = 'Polices calligraphiques (1/2)';
          });
        }

        await FontDownloadService.downloadAndExtractFonts(
          onDownloadProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
                _statusMessage = 'Polices QCF… (1/2)';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isExtracting = true;
            _statusMessage = 'Extraction des polices…';
          });
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // ── 2. Pack de traduction française ───────────────────────────────────
      if (!translationReady) {
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _isDownloading = true;
            _downloadProgress = 0.0;
            _statusMessage = 'Traduction française (2/2)';
          });
        }

        await QuranTranslationPackService.downloadPack(
          AppLang.fr,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
                _statusMessage = 'Traduction française… (2/2)';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isExtracting = false;
            _statusMessage = 'Finalisation…';
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
      MaterialPageRoute(builder: (context) => const BottomNavShell()),
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
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
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

    return Scaffold(
      body: DownloadProgressWidget(
        progress: _downloadProgress,
        message: _statusMessage,
        isExtracting: _isExtracting,
        subtitle: _isDownloading
            ? 'Installation unique — Les prochaines ouvertures seront instantanées'
            : null,
      ),
    );
  }
}
