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
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../services/mini_player_service.dart';

class MiniPlayerWidget extends StatefulWidget {
  final int currentSurah;
  const MiniPlayerWidget({super.key, required this.currentSurah});
  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  int get currentSurah => widget.currentSurah;

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
            ValueListenableBuilder<MiniRepeatMode>(
              valueListenable: svc.repeatMode,
              builder: (_, repeat, __) => _ChipBtn(
                label: _repeatLabel(repeat),
                onTap: svc.cycleRepeat,
              ),
            ),
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

  // ── Play avec vérification WiFi ───────────────────────────────────────────

  Future<void> _handlePlayTap(MiniPlayerService svc, bool autoAdvancing) async {
    // Si déjà en lecture ou en auto-avance → play/pause direct
    if (svc.currentAyahKey.value != null || autoAdvancing) {
      svc.playPause();
      return;
    }

    void startPlay() {
      if (svc.selectionStartKey != null) {
        final parts = svc.selectionStartKey!.split(':');
        final s = int.tryParse(parts[0]) ?? currentSurah;
        final a = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
        svc.playFrom(surah: s, ayah: a);
      } else {
        svc.playFrom(surah: currentSurah, ayah: 1);
      }
    }

    // Vérifier la connexion (fallback : jouer directement en cas d'erreur)
    bool isWifi = true;
    try {
      final result = await Connectivity().checkConnectivity();
      isWifi = result.contains(ConnectivityResult.wifi);
    } catch (_) {
      // Impossible de vérifier → on joue directement
      if (mounted) startPlay();
      return;
    }

    if (!mounted) return;

    if (isWifi) {
      startPlay();
      return;
    }

    // Pas en WiFi → demander confirmation
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: const Text(
          'Vous n\'êtes pas en Wi-Fi.\nTélécharger la sourate ?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('✕  Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('✔  Continuer'),
          ),
        ],
      ),
    );
    if (mounted && ok == true) startPlay();
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
    return ValueListenableBuilder<double?>(
      valueListenable: svc.prepProgress,
      builder: (_, prep, __) => ValueListenableBuilder<bool>(
        valueListenable: svc.isPlaying,
        builder: (_, playing, __) => ValueListenableBuilder<bool>(
          valueListenable: svc.isLoading,
          builder: (_, loading, __) => ValueListenableBuilder<bool>(
            valueListenable: svc.isRangeAutoAdvancing,
            builder: (_, autoAdvancing, __) {
              // Pendant la préparation : spinner avec progression circulaire.
              if (prep != null) {
                return SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: prep > 0 ? prep : null,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                );
              }
              // Pendant le buffering just_audio (hors auto-transition).
              if (loading && !autoAdvancing) {
                return SizedBox(
                  width: size,
                  height: size,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                );
              }
              final showPause = playing || autoAdvancing;
              return GestureDetector(
                onTap: () => _handlePlayTap(svc, autoAdvancing),
                child: Icon(
                  showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: size,
                ),
              );
            },
          ),
        ),
      ),
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

