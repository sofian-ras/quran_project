// lib/ui/widgets/mini_player_widget.dart
//
// Mini lecteur audio sobre pour le reader screen.
//
// État collapsed : [Récitateur ▼]  [▶]
// État expanded  : [Récitateur ▼] [Mode] [Repeat] [⬇]
//                  [⏮]  [⏸/▶]  [⏹]  [⏭]
//                  (message d'indisponibilité si applicable)
//
// Suit la visibilité des icônes du reader (_showUI).
// Fond : verre dépoli sombre (BackdropFilter).

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/mini_player_service.dart';
import '../../services/qul_audio/audio_download_manager.dart';

class MiniPlayerWidget extends StatelessWidget {
  /// Sourate actuellement visible (pour lancer la lecture depuis le début
  /// quand rien n'est encore en cours).
  final int currentSurah;

  const MiniPlayerWidget({super.key, required this.currentSurah});

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = MiniPlayerService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: svc.isExpanded,
      builder: (context, expanded, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: expanded
                  ? _expandedView(context, svc)
                  : _collapsedView(context, svc),
            ),
          ),
        );
      },
    );
  }

  // ── Vue collapsed ─────────────────────────────────────────────────────────

  Widget _collapsedView(BuildContext context, MiniPlayerService svc) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(child: _reciterButton(context, svc)),
          const SizedBox(width: 8),
          _buildPlayBtn(svc),
        ],
      ),
    );
  }

  // ── Vue expanded ──────────────────────────────────────────────────────────

  Widget _expandedView(BuildContext context, MiniPlayerService svc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ligne 1 : récitateur + mode + repeat + download
        Row(
          children: [
            Expanded(child: _reciterButton(context, svc)),
            const SizedBox(width: 6),
            ValueListenableBuilder<MiniPlayMode>(
              valueListenable: svc.playMode,
              builder: (_, mode, __) => _ChipBtn(
                label: _modeLabel(mode),
                onTap: svc.cycleMode,
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<MiniRepeatMode>(
              valueListenable: svc.repeatMode,
              builder: (_, repeat, __) => _ChipBtn(
                label: _repeatLabel(repeat),
                onTap: svc.cycleRepeat,
              ),
            ),
            const SizedBox(width: 4),
            _buildDownloadBtn(svc),
          ],
        ),
        const SizedBox(height: 8),
        // Ligne 2 : contrôles de lecture
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlBtn(icon: Icons.skip_previous_rounded, onTap: svc.prevVerse),
            _buildPlayBtn(svc, size: 34),
            _CtrlBtn(
              icon: Icons.stop_rounded,
              onTap: svc.stop,
              color: Colors.redAccent.shade100,
            ),
            _CtrlBtn(icon: Icons.skip_next_rounded, onTap: svc.nextVerse),
          ],
        ),
        // Ligne 2.5 : barre de pré-téléchargement
        ValueListenableBuilder<double?>(
          valueListenable: svc.prepProgress,
          builder: (_, prep, __) {
            if (prep == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: prep,
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(prep * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: svc.cancelPrep,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Préparation de la lecture…',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
        // Ligne 3 : message d'indisponibilité
        ValueListenableBuilder<String?>(
          valueListenable: svc.unavailableMessage,
          builder: (_, msg, __) {
            if (msg == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Bouton download ───────────────────────────────────────────────────────

  Widget _buildDownloadBtn(MiniPlayerService svc) {
    return ValueListenableBuilder<String?>(
      valueListenable: svc.currentAyahKey,
      builder: (_, key, __) {
        if (key == null) return const SizedBox.shrink();
        return ValueListenableBuilder<Map<String, DownloadEntry>>(
          valueListenable: AudioDownloadManager.instance.entriesNotifier,
          builder: (_, entries, __) {
            final dlKey = svc.currentDownloadKey;
            if (dlKey == null) return const SizedBox.shrink();
            final entry = entries[dlKey];
            return _DownloadButton(
              status:   entry?.status   ?? DownloadStatus.idle,
              progress: entry?.progress ?? 0.0,
              onTap: () => _handleDownloadTap(svc, entry),
            );
          },
        );
      },
    );
  }

  void _handleDownloadTap(MiniPlayerService svc, DownloadEntry? entry) {
    switch (entry?.status ?? DownloadStatus.idle) {
      case DownloadStatus.idle:
      case DownloadStatus.failed:
        svc.downloadCurrent();
      case DownloadStatus.downloading:
        svc.cancelCurrentDownload();
      case DownloadStatus.done:
        svc.deleteCurrentDownload();
    }
  }

  // ── Bouton récitateur ─────────────────────────────────────────────────────

  Widget _reciterButton(BuildContext context, MiniPlayerService svc) {
    return ValueListenableBuilder<MiniReciter>(
      valueListenable: svc.currentReciter,
      builder: (context, reciter, _) {
        return GestureDetector(
          onTap: () => _showReciterPicker(context, svc),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  reciter.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white60,
                size: 16,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Bouton play/pause ─────────────────────────────────────────────────────

  Widget _buildPlayBtn(MiniPlayerService svc, {double size = 26}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        svc.prepProgress,
        svc.isPlaying,
        svc.isLoading,
        svc.isRangeAutoAdvancing,
      ]),
      builder: (_, __) {
        final prep          = svc.prepProgress.value;
        final playing       = svc.isPlaying.value;
        final loading       = svc.isLoading.value;
        final autoAdvancing = svc.isRangeAutoAdvancing.value;

        // Pendant la préparation
        if (prep != null) {
          return SizedBox(
            width: size, height: size,
            child: CircularProgressIndicator(
              value: prep > 0 ? prep : null,
              strokeWidth: 2, color: Colors.white,
            ),
          );
        }
        // Pendant le buffering (hors auto-transition)
        if (loading && !autoAdvancing) {
          return SizedBox(
            width: size, height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white,
            ),
          );
        }
        final showPause = playing || autoAdvancing;
        return GestureDetector(
          onTap: () {
            if (svc.currentAyahKey.value != null || autoAdvancing) {
              svc.playPause();
            } else if (svc.selectionStartKey != null) {
              final parts = svc.selectionStartKey!.split(':');
              final s = int.tryParse(parts[0]) ?? currentSurah;
              final a = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
              svc.playFrom(surah: s, ayah: a);
            } else {
              svc.playFrom(surah: currentSurah, ayah: 1);
            }
          },
          child: Icon(
            showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white, size: size,
          ),
        );
      },
    );
  }

  // ── Sélecteur de récitateur ───────────────────────────────────────────────

  void _showReciterPicker(BuildContext context, MiniPlayerService svc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A0033) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ValueListenableBuilder<MiniReciter>(
        valueListenable: svc.currentReciter,
        builder: (context, current, _) => ListView.builder(
          itemCount: kMiniReciters.length,
          itemBuilder: (context, i) {
            final r        = kMiniReciters[i];
            final selected = r.folder == current.folder;
            return ListTile(
              title: Text(
                r.name,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                svc.setReciter(r);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  // ── Labels ────────────────────────────────────────────────────────────────

  String _modeLabel(MiniPlayMode mode) {
    switch (mode) {
      case MiniPlayMode.surah:        return 'Sourate';
      case MiniPlayMode.verseByVerse: return 'V / V';
      case MiniPlayMode.selection:    return 'Sélec.';
    }
  }

  String _repeatLabel(MiniRepeatMode mode) {
    switch (mode) {
      case MiniRepeatMode.x1:       return '×1';
      case MiniRepeatMode.x2:       return '×2';
      case MiniRepeatMode.x3:       return '×3';
      case MiniRepeatMode.infinite: return '∞';
    }
  }
}

// ── Chip bouton (mode / repeat) ───────────────────────────────────────────────

class _ChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChipBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Bouton de contrôle (prev / stop / next) ───────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _CtrlBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color ?? Colors.white, size: 30),
    );
  }
}

// ── Bouton download ───────────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  final DownloadStatus status;
  final double progress;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.status,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: switch (status) {
          DownloadStatus.idle => const Icon(
              Icons.cloud_download_outlined,
              color: Colors.white70,
              size: 20,
            ),
          DownloadStatus.downloading => Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
                const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 12),
              ],
            ),
          DownloadStatus.done => const Icon(
              Icons.cloud_done_rounded,
              color: Colors.greenAccent,
              size: 20,
            ),
          DownloadStatus.failed => const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
        },
      ),
    );
  }
}
