// lib/ui/widgets/mini_player_widget.dart
//
// Mini lecteur sobre — s'adapte à l'état de lecture :
//   Repos    : [avatar] [nom récitateur  ›]
//   Lecture  : [avatar] [nom / En lecture…] [×N]
//              [⏮]  [⏸/▶ cercle]  [⏹]  [⏭]
//              (barre pré-téléchargement si applicable)
//              (message d'indisponibilité si applicable)
//
// Tap repos  → lance la lecture (vérification WiFi)
// Tap actif  → ouvre le sélecteur de récitateur

import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../services/mini_player_service.dart';
import 'reciter_picker_sheet.dart';


class MiniPlayerWidget extends StatefulWidget {
  final int currentSurah;
  const MiniPlayerWidget({super.key, required this.currentSurah});
  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  int get currentSurah => widget.currentSurah;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    MiniPlayerService.instance.isPlaying.addListener(_onPlayingChanged);
    MiniPlayerService.instance.isRangeAutoAdvancing.addListener(_onPlayingChanged);
    MiniPlayerService.instance.prepProgress.addListener(_onPrepChanged);
  }

  @override
  void dispose() {
    MiniPlayerService.instance.isPlaying.removeListener(_onPlayingChanged);
    MiniPlayerService.instance.isRangeAutoAdvancing.removeListener(_onPlayingChanged);
    MiniPlayerService.instance.prepProgress.removeListener(_onPrepChanged);
    super.dispose();
  }

  void _onPlayingChanged() {
    final svc = MiniPlayerService.instance;
    if (svc.isPlaying.value || svc.isRangeAutoAdvancing.value) {
      if (!_showControls && mounted) setState(() => _showControls = true);
    }
  }

  void _onPrepChanged() {
    final svc = MiniPlayerService.instance;
    // Quand le téléchargement se termine → passer en mode contrôles
    if (svc.prepProgress.value == null && mounted) {
      setState(() => _showControls = true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = MiniPlayerService.instance;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: _body(svc),
        ),
      ),
    );
  }

  // ── Corps principal ───────────────────────────────────────────────────────

  Widget _body(MiniPlayerService svc) {
    return ValueListenableBuilder<double?>(
      valueListenable: svc.prepProgress,
      builder: (_, prep, __) =>
          ValueListenableBuilder<bool>(
            valueListenable: svc.isPlaying,
            builder: (_, playing, __) =>
                ValueListenableBuilder<bool>(
                  valueListenable: svc.isRangeAutoAdvancing,
                  builder: (_, autoAdv, __) =>
                      ValueListenableBuilder<bool>(
                        valueListenable: svc.isLoading,
                        builder: (_, loading, __) {
                          final isActive =
                              playing || autoAdv || loading || prep != null;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: prep != null
                                ? _prepOnly(
                                    key: const ValueKey('prep'),
                                    prep: prep,
                                    svc: svc,
                                  )
                                : _showControls
                                    ? _allControls(
                                        key: const ValueKey('ctrl'),
                                        svc: svc,
                                        playing: playing,
                                        autoAdv: autoAdv,
                                        loading: loading,
                                        prep: prep,
                                      )
                                    : Column(
                                        key: const ValueKey('name'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _header(svc, isActive, playing, autoAdv, loading, prep),
                                          AnimatedSize(
                                            duration: const Duration(milliseconds: 260),
                                            curve: Curves.easeOut,
                                            child: isActive
                                                ? _controls(svc, playing, autoAdv, loading, prep)
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                          );
                        },
                      ),
                ),
          ),
    );
  }

  Widget _prepOnly({required Key key, required double prep, required MiniPlayerService svc}) {
    const gold = Color(0xFFD4A855);
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.downloading_rounded, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Téléchargement…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(prep * 100).round()}%',
              style: const TextStyle(
                color: gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: svc.cancelPrep,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: prep > 0 ? prep : null,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(gold),
          ),
        ),
      ],
    );
  }

  Widget _allControls({
    required Key key,
    required MiniPlayerService svc,
    required bool playing,
    required bool autoAdv,
    required bool loading,
    required double? prep,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlBtn(icon: Icons.skip_previous_rounded, onTap: svc.prevVerse),
            _playBtn(svc, playing, autoAdv, loading, prep, size: 30),
            _CtrlBtn(
              icon: Icons.stop_rounded,
              onTap: () { svc.stop(); setState(() => _showControls = false); },
              color: Colors.redAccent.shade100,
            ),
            _CtrlBtn(icon: Icons.skip_next_rounded, onTap: svc.nextVerse),
          ],
        ),
        const SizedBox(height: 8),
        _chipsRow(svc),
      ],
    );
  }

  // ── Ligne d'en-tête : avatar + nom + indicateur ───────────────────────────

  Widget _header(MiniPlayerService svc, bool isActive,
      bool playing, bool autoAdv, bool loading, double? prep) {
    return ValueListenableBuilder<MiniReciter>(
      valueListenable: svc.currentReciter,
      builder: (_, reciter, __) {
        return Row(
          children: [
            // Bouton play/pause circulaire — tap lance lecture + affiche contrôles
            GestureDetector(
              onTap: () {
                _handlePlayTap(svc, autoAdv);
                setState(() => _showControls = true);
              },
              child: _playCircle(playing, autoAdv, loading, prep),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _nameColumn(
                reciter: reciter,
                isActive: isActive,
                playing: playing,
                autoAdv: autoAdv,
                svc: svc,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _playCircle(bool playing, bool autoAdv, bool loading, double? prep) {
    final isActive = playing || autoAdv || loading || prep != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: isActive
              ? const Color(0xFFD4A855).withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: prep != null
          ? Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    value: prep > 0 ? prep : null,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                if (prep > 0)
                  Text(
                    '${(prep * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
              ],
            )
          : loading && !autoAdv
              ? const Padding(
                  padding: EdgeInsets.all(7),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  (playing || autoAdv) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isActive
                      ? const Color(0xFFD4A855).withValues(alpha: 0.9)
                      : Colors.white70,
                  size: 18,
                ),
    );
  }

  Widget _nameColumn({
    required MiniReciter reciter,
    required bool isActive,
    required bool playing,
    required bool autoAdv,
    required MiniPlayerService svc,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showReciterPicker(context, svc),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reciter.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isActive)
                  Text(
                    playing || autoAdv ? 'En lecture…' : 'Chargement…',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isActive)
            _chipsRow(svc)
          else
            const Icon(Icons.keyboard_arrow_right_rounded,
                color: Colors.white38, size: 18),
        ],
      ),
    );
  }

  // ── Contrôles de lecture ──────────────────────────────────────────────────

  Widget _controls(MiniPlayerService svc, bool playing, bool autoAdv,
      bool loading, double? prep) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlBtn(icon: Icons.skip_previous_rounded, onTap: svc.prevVerse),
            _playBtn(svc, playing, autoAdv, loading, prep),
            _CtrlBtn(
              icon: Icons.stop_rounded,
              onTap: () { svc.stop(); setState(() => _showControls = false); },
              color: Colors.redAccent.shade100,
            ),
            _CtrlBtn(icon: Icons.skip_next_rounded, onTap: svc.nextVerse),
          ],
        ),
        const SizedBox(height: 8),
        _chipsRow(svc),
        _unavailableMsg(svc),
      ],
    );
  }

  /// Ligne repeat + vitesse, utilisée dans le header et les deux modes de contrôles.
  Widget _chipsRow(MiniPlayerService svc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<MiniRepeatMode>(
          valueListenable: svc.repeatMode,
          builder: (_, repeat, __) => _ChipBtn(
            label: _repeatLabel(repeat),
            onTap: svc.cycleRepeat,
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<double>(
          valueListenable: svc.playbackSpeed,
          builder: (_, speed, __) => _ChipBtn(
            label: _speedLabel(speed),
            onTap: svc.cycleSpeed,
            active: speed != 1.0,
          ),
        ),
      ],
    );
  }

  // ── Bouton play/pause ─────────────────────────────────────────────────────

  Widget _playBtn(MiniPlayerService svc, bool playing, bool autoAdv,
      bool loading, double? prep,
      {double size = 36}) {
    if (prep != null) {
      return SizedBox(
        width: size, height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: prep > 0 ? prep : null,
              strokeWidth: 2,
              color: Colors.white,
            ),
            if (prep > 0)
              Text(
                '${(prep * 100).round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
          ],
        ),
      );
    }
    if (loading && !autoAdv) {
      return SizedBox(
        width: size, height: size,
        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    final showPause = playing || autoAdv;
    return GestureDetector(
      onTap: () => _handlePlayTap(svc, autoAdv),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.16),
        ),
        child: Icon(
          showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.62,
        ),
      ),
    );
  }

  // ── Message d'indisponibilité ─────────────────────────────────────────────

  Widget _unavailableMsg(MiniPlayerService svc) {
    return ValueListenableBuilder<String?>(
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
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.orangeAccent, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Play avec vérification WiFi ───────────────────────────────────────────

  Future<void> _handlePlayTap(MiniPlayerService svc, bool autoAdv) async {
    if (svc.currentAyahKey.value != null || autoAdv) {
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

    // Si l'audio est déjà téléchargé localement, pas besoin de vérifier le WiFi.
    final surahToCheck = svc.selectionStartKey != null
        ? (int.tryParse(svc.selectionStartKey!.split(':')[0]) ?? currentSurah)
        : currentSurah;
    if (await svc.isAudioCached(surahToCheck)) {
      if (mounted) startPlay();
      return;
    }

    bool isWifi = true;
    try {
      final result = await Connectivity().checkConnectivity();
      isWifi = result.contains(ConnectivityResult.wifi);
    } catch (_) {
      if (mounted) startPlay();
      return;
    }

    if (!mounted) return;
    if (isWifi) { startPlay(); return; }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1035) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: Text(
          'Vous n\'êtes pas en Wi-Fi.\nTélécharger la sourate ?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('✕  Annuler',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('✔  Continuer',
                style: TextStyle(color: Color(0xFFC8A165))),
          ),
        ],
      ),
    );
    if (mounted && ok == true) startPlay();
  }

  // ── Sélecteur de récitateur ───────────────────────────────────────────────

  void _showReciterPicker(BuildContext context, MiniPlayerService svc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReciterPickerSheet(svc: svc, isDark: isDark),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _repeatLabel(MiniRepeatMode mode) {
    switch (mode) {
      case MiniRepeatMode.x1:       return '×1';
      case MiniRepeatMode.x2:       return '×2';
      case MiniRepeatMode.x3:       return '×3';
      case MiniRepeatMode.infinite: return '∞';
    }
  }

  String _speedLabel(double speed) {
    if (speed == speed.truncateToDouble()) return '×${speed.toInt()}';
    return '×$speed';
  }
}

// ── Chip bouton (repeat / vitesse) ───────────────────────────────────────────

class _ChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ChipBtn({required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFD4A855).withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(color: const Color(0xFFD4A855).withValues(alpha: 0.55), width: 1)
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? const Color(0xFFD4A855) : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Bouton de contrôle ────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _CtrlBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color ?? Colors.white, size: 28),
    );
  }
}
