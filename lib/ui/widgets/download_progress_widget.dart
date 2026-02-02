import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget élégant pour afficher la progression du téléchargement
class DownloadProgressWidget extends StatefulWidget {
  final double progress; // 0.0 à 1.0
  final String message;
  final String? subtitle;
  final bool isExtracting;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
    this.message = 'Téléchargement en cours...',
    this.subtitle,
    this.isExtracting = false,
  });

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation de rotation avec icône
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: widget.isExtracting
                        ? _controller.value * 2 * math.pi
                        : 0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.isExtracting
                              ? Icons.inventory_2_outlined
                              : Icons.cloud_download_outlined,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Message principal
              Text(
                widget.message,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Pourcentage et barre de progression
              if (!widget.isExtracting) ...[
                // Grand pourcentage
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0, end: widget.progress),
                  builder: (context, value, child) {
                    final percent = (value * 100).toInt();
                    return Text(
                      '$percent%',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 72,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Barre de progression personnalisée
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      // Barre
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 12,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween(begin: 0, end: widget.progress),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: theme.brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Taille téléchargée estimée
                      if (widget.progress > 0)
                        Text(
                          _getDownloadedSize(widget.progress),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                // Animation pour l'extraction
                const SizedBox(
                  width: 300,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Extraction des fichiers en cours...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[700],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Sous-titre ou conseil
              if (widget.subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_bottom,
                      size: 16,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isExtracting
                          ? 'Cela peut prendre quelques minutes...'
                          : 'Première installation - Téléchargement unique',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDownloadedSize(double progress) {
    // Estimation: ZIP fait environ 80 MB
    const totalSizeMB = 80.0;
    final downloadedMB = totalSizeMB * progress;
    return '${downloadedMB.toStringAsFixed(1)} MB / ${totalSizeMB.toStringAsFixed(0)} MB';
  }
}

/// Widget compact pour affichage dans un dialog
class CompactDownloadProgress extends StatelessWidget {
  final double progress;
  final String? message;

  const CompactDownloadProgress({
    super.key,
    required this.progress,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicateur circulaire avec pourcentage
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[300],
                  ),
                  Center(
                    child: Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              message ?? 'Téléchargement en cours...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Veuillez patienter',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
