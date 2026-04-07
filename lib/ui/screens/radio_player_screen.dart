import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/radio_station.dart';
import '../../services/audio_service.dart';
import '../../services/radio_service.dart';
import 'radio_browser_screen.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;

  const RadioPlayerScreen({super.key, required this.station});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double>    _pulseAnim;
  bool _isFavorite = false;
  bool _favLoading = false;

  // Gestures swipe
  double  _dragX   = 0;
  double  _dragY   = 0;
  String? _dragDir;

  // Volume
  double _volume = 1.0;

  // Sleep timer
  Duration? _sleepRemaining;
  Timer?    _sleepCountdown;

  // Mode simple
  bool      _simpleMode = false;
  Timer?    _clockTimer;
  DateTime  _now = DateTime.now();

  RadioStation get _station =>
      RadioService.instance.currentStationNotifier.value ?? widget.station;

  String get _sleepCountdownStr {
    final r = _sleepRemaining;
    if (r == null) return '';
    final m = r.inMinutes;
    final s = r.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _volume = AudioService.instance.volume;

    RadioService.instance
        .isFavorite(widget.station.id)
        .then((v) { if (mounted) setState(() => _isFavorite = v); });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _sleepCountdown?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Favori ───────────────────────────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    if (_favLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _favLoading = true);
    final result = await RadioService.instance.toggleFavorite(_station);
    if (mounted) setState(() { _isFavorite = result; _favLoading = false; });
  }

  // ── Stop ─────────────────────────────────────────────────────────────────

  Future<void> _stop() async {
    _cancelSleepTimer();
    await AudioService.instance.stopRadio();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Skip ─────────────────────────────────────────────────────────────────

  void _skipTo(int delta) {
    final stations = RadioService.instance.cachedStations;
    if (stations.isEmpty) return;
    final idx = stations.indexWhere((s) => s.id == _station.id);
    if (idx < 0) return;
    final n    = stations.length;
    final next = stations[((idx + delta) % n + n) % n];
    HapticFeedback.lightImpact();
    AudioService.instance.playRadio(next);
    RadioService.instance.currentStationNotifier.value = next;
    RadioService.instance.trackPlay(next);
    RadioService.instance
        .isFavorite(next.id)
        .then((v) { if (mounted) setState(() => _isFavorite = v); });
  }

  RadioStation? get _nextStation {
    final stations = RadioService.instance.cachedStations;
    if (stations.isEmpty) return null;
    final idx = stations.indexWhere((s) => s.id == _station.id);
    if (idx < 0) return null;
    return stations[(idx + 1) % stations.length];
  }

  // ── Sleep timer ───────────────────────────────────────────────────────────

  void _showTimerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepTimerSheet(
        remaining: _sleepRemaining,
        countdownStr: _sleepCountdownStr,
        onSelect: (d) { Navigator.pop(context); _startSleepTimer(d); },
        onCancel: () { Navigator.pop(context); _cancelSleepTimer(); },
      ),
    );
  }

  void _startSleepTimer(Duration d) {
    _cancelSleepTimer();
    setState(() => _sleepRemaining = d);
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _sleepRemaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        _stop();
        return;
      }
      setState(() => _sleepRemaining = remaining - const Duration(seconds: 1));
    });
  }

  void _cancelSleepTimer() {
    _sleepCountdown?.cancel();
    _sleepCountdown = null;
    if (mounted) setState(() => _sleepRemaining = null);
  }

  // ── Mode simple ───────────────────────────────────────────────────────────

  void _toggleSimpleMode() {
    if (!_simpleMode) {
      _now = DateTime.now();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
    setState(() => _simpleMode = !_simpleMode);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_simpleMode) return _buildSimpleMode();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat    = categorizeStation(_station);
    final grad   = radioCategoryGradient(cat);

    return ValueListenableBuilder<RadioStation?>(
      valueListenable: RadioService.instance.currentStationNotifier,
      builder: (_, __, ___) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF080D1A) : const Color(0xFFF5F0E8),
          body: GestureDetector(
            onPanStart: (_) {
              _dragDir = null; _dragX = 0; _dragY = 0;
            },
            onPanUpdate: (d) {
              setState(() {
                if (_dragDir == null) {
                  if (d.delta.dx.abs() > d.delta.dy.abs() + 4) {
                    _dragDir = 'h';
                  } else if (d.delta.dy > 0 && d.delta.dy.abs() > d.delta.dx.abs() + 4) {
                    _dragDir = 'v';
                  }
                }
                if (_dragDir == 'h') _dragX = (_dragX + d.delta.dx).clamp(-160.0, 160.0);
                if (_dragDir == 'v') _dragY = (_dragY + d.delta.dy).clamp(0.0, 200.0);
              });
            },
            onPanEnd: (d) {
              final vx = d.velocity.pixelsPerSecond.dx;
              final vy = d.velocity.pixelsPerSecond.dy;
              if (_dragDir == 'h') {
                if (_dragX < -60 || vx < -500) { _skipTo(1); }
                else if (_dragX > 60 || vx > 500) { _skipTo(-1); }
              } else if (_dragDir == 'v') {
                if (_dragY > 120 || vy > 600) { if (mounted) Navigator.of(context).pop(); return; }
              }
              setState(() { _dragX = 0; _dragY = 0; _dragDir = null; });
            },
            child: Stack(
              children: [
                // ── Fond image floue ───────────────────────────────────
                Positioned.fill(
                  child: _BlurredBackground(station: _station, grad: grad, isDark: isDark),
                ),

                // ── Contenu principal (suit le drag) ───────────────────
                Transform.translate(
                  offset: Offset(_dragX * 0.35, _dragY),
                  child: Opacity(
                    opacity: (1.0 - (_dragY / 300)).clamp(0.0, 1.0),
                    child: SafeArea(
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              _buildHeader(isDark, cat),
                              Expanded(child: _buildBody(isDark, cat, grad)),
                            ],
                          ),
                          // ── Slider volume vertical gauche ──────────
                          _buildVolumeSlider(grad),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, String cat) {
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final timerActive = _sleepRemaining != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'En direct',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          // Colonne droite : favori + minuteur + compte à rebours
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Favori
              _favLoading
                  ? const SizedBox(
                      width: 44, height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Color(0xFFDC2626), strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _isFavorite ? const Color(0xFFDC2626) : mutedColor,
                        size: 26,
                      ),
                    ),
              // Minuteur
              IconButton(
                onPressed: _showTimerSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                icon: Icon(
                  timerActive ? Icons.timer_rounded : Icons.timer_outlined,
                  color: timerActive ? const Color(0xFF38C172) : mutedColor,
                  size: 22,
                ),
              ),
              // Compte à rebours
              if (timerActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _sleepCountdownStr,
                    style: const TextStyle(
                      color: Color(0xFF38C172),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Slider volume vertical ────────────────────────────────────────────────

  Widget _buildVolumeSlider(List<Color> grad) {
    return Positioned(
      left: 0,
      top: 110,
      width: 48,
      height: 180,
      child: Column(
        children: [
          Icon(Icons.volume_up_rounded, size: 13,
              color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: grad[0].withValues(alpha: 0.75),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  trackHeight: 2.5,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _volume,
                  onChanged: (v) {
                    setState(() => _volume = v);
                    AudioService.instance.setVolume(v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Icon(Icons.volume_down_rounded, size: 13,
              color: Colors.white.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark, String cat, List<Color> grad) {
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final spaceIdx   = cat.indexOf(' ');
    final catLabel   = spaceIdx > 0 ? cat.substring(spaceIdx + 1) : cat;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // ── Miniature avec halo pulsant ────────────────────────────
          StreamBuilder<PlayerState>(
            stream: AudioService.instance.playerStateStream,
            builder: (_, snap) {
              final playing = snap.data?.playing ?? false;
              return AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: playing ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Container(
                  width: 210, height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: grad[0].withValues(alpha: playing ? 0.5 : 0.2),
                        blurRadius: playing ? 48 : 24,
                        spreadRadius: playing ? 8 : 2,
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'radio_thumb_${widget.station.id}',
                    child: ClipOval(
                      child: _PlayerThumbnail(station: _station, grad: grad),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 36),

          // ── Nom de la station ──────────────────────────────────────
          Text(
            _stationLabel(_station),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor, fontSize: 26,
              fontWeight: FontWeight.w800, letterSpacing: -0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // ── Badges: catégorie + LIVE ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  catLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 56),

          // ── Précédent / Play / Suivant ─────────────────────────────
          StreamBuilder<PlayerState>(
            stream: AudioService.instance.playerStateStream,
            builder: (_, snap) {
              final state   = snap.data;
              final playing = state?.playing ?? false;
              final loading = state?.processingState == ProcessingState.loading ||
                  state?.processingState == ProcessingState.buffering;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _skipTo(-1),
                    icon: Icon(Icons.skip_previous_rounded,
                        color: mutedColor, size: 36),
                    iconSize: 36,
                  ),
                  const SizedBox(width: 24),
                  if (loading)
                    SizedBox(
                      width: 80, height: 80,
                      child: Center(
                        child: SizedBox(
                          width: 36, height: 36,
                          child: CircularProgressIndicator(
                              color: grad[0], strokeWidth: 3),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        AudioService.instance.togglePlayPause();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: playing ? grad[0] : (isDark
                              ? const Color(0xFF1E2A3A)
                              : const Color(0xFFE5E0D8)),
                          boxShadow: playing
                              ? [BoxShadow(
                                  color: grad[0].withValues(alpha: 0.45),
                                  blurRadius: 24, spreadRadius: 4)]
                              : [],
                        ),
                        child: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: playing ? Colors.white : mutedColor,
                          size: 40,
                        ),
                      ),
                    ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: () => _skipTo(1),
                    icon: Icon(Icons.skip_next_rounded,
                        color: mutedColor, size: 36),
                    iconSize: 36,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Arrêter + Mode simple ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _stop,
                icon: Icon(Icons.stop_circle_outlined, color: mutedColor, size: 18),
                label: Text('Arrêter',
                    style: TextStyle(color: mutedColor, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _toggleSimpleMode,
                icon: Icon(Icons.dark_mode_outlined, color: mutedColor, size: 18),
                label: Text('Mode simple',
                    style: TextStyle(color: mutedColor, fontSize: 13)),
              ),
            ],
          ),

          // ── Preview station suivante ───────────────────────────────
          if (_nextStation != null) ...[
            const SizedBox(height: 4),
            _NextStationPreview(
              station: _nextStation!,
              isDark: isDark,
              grad: grad,
              onTap: () => _skipTo(1),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Mode simple ───────────────────────────────────────────────────────────

  Widget _buildSimpleMode() {
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: _toggleSimpleMode,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _stationLabel(_station),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 56,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              // Compte à rebours si actif
              if (_sleepRemaining != null)
                Positioned(
                  bottom: 24,
                  left: 0, right: 0,
                  child: Text(
                    'Arrêt dans $_sleepCountdownStr',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                  ),
                ),
              // Hint tap
              Positioned(
                top: 16, left: 0, right: 0,
                child: Text(
                  'Toucher pour revenir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.15),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet minuteur de sommeil ─────────────────────────────────────────────────

class _SleepTimerSheet extends StatelessWidget {
  final Duration?    remaining;
  final String       countdownStr;
  final void Function(Duration) onSelect;
  final VoidCallback onCancel;

  const _SleepTimerSheet({
    required this.remaining,
    required this.countdownStr,
    required this.onSelect,
    required this.onCancel,
  });

  static const _presets = <(String, Duration)>[
    ('15 min',  Duration(minutes: 15)),
    ('30 min',  Duration(minutes: 30)),
    ('45 min',  Duration(minutes: 45)),
    ('1 h',     Duration(hours: 1)),
    ('1 h 30',  Duration(hours: 1, minutes: 30)),
    ('2 h',     Duration(hours: 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor  = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: mutedColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Minuteur de sommeil',
            style: TextStyle(
              color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _presets.map(((String, Duration) p) {
              return GestureDetector(
                onTap: () => onSelect(p.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF252542)
                        : const Color(0xFFF0EEF8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF38C172).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    p.$1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.timer_off_outlined,
                  color: Color(0xFFDC2626), size: 18),
              label: Text(
                'Annuler ($countdownStr)',
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Fond flouté avec image de la station ─────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  final RadioStation station;
  final List<Color>  grad;
  final bool         isDark;

  const _BlurredBackground({
    required this.station,
    required this.grad,
    required this.isDark,
  });

  String get _catAsset =>
      reciterAssetForStation(station) ??
      kCatAssets[categorizeStation(station)] ??
      '';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_catAsset.isNotEmpty)
          Image.asset(
            _catAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: grad,
              ),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark
                      ? Colors.black.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.08),
                  isDark
                      ? const Color(0xFF080D1A).withValues(alpha: 0.72)
                      : const Color(0xFFF5F0E8).withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.80],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Miniature centrale (cercle) ───────────────────────────────────────────────

class _PlayerThumbnail extends StatelessWidget {
  final RadioStation station;
  final List<Color>  grad;

  const _PlayerThumbnail({required this.station, required this.grad});

  String get _asset =>
      reciterAssetForStation(station) ??
      kCatAssets[categorizeStation(station)] ??
      '';

  @override
  Widget build(BuildContext context) {
    Widget fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
      ),
      child: Center(
        child: Icon(Icons.radio_rounded,
            color: Colors.white.withValues(alpha: 0.6), size: 80),
      ),
    );

    return _asset.isNotEmpty
        ? Image.asset(_asset, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback)
        : fallback;
  }
}

// ── Label station ─────────────────────────────────────────────────────────────

String _stationLabel(RadioStation s) {
  if (categorizeStation(s) != '🌍 Traductions') return s.displayName;
  final slug = s.url.split('/').last.toLowerCase();
  if (slug.contains('french'))    return 'Traduction française';
  if (slug.contains('english'))   return 'Traduction anglaise';
  if (slug.contains('urdu'))      return 'Traduction ourdou';
  if (slug.contains('turkish'))   return 'Traduction turque';
  if (slug.contains('farsi'))     return 'Traduction persane';
  if (slug.contains('russia'))    return 'Traduction russe';
  if (slug.contains('chinese'))   return 'Traduction chinoise';
  if (slug.contains('german'))    return 'Traduction allemande';
  if (slug.contains('spanish'))   return 'Traduction espagnole';
  if (slug.contains('albanian'))  return 'Traduction albanaise';
  if (slug.contains('bosnia'))    return 'Traduction bosniaque';
  if (slug.contains('portuguese')) return 'Traduction portugaise';
  if (slug.contains('kurdish'))   return 'Traduction kurde';
  if (slug.contains('korean'))    return 'Traduction coréenne';
  if (slug.contains('hungarian')) return 'Traduction hongroise';
  if (slug.contains('greek'))     return 'Traduction grecque';
  if (slug.contains('tamazight')) return 'Traduction amazighe';
  if (slug.contains('hausa'))     return 'Traduction haoussa';
  final dn = s.displayName;
  return dn.length > 26 ? '…${dn.substring(dn.length - 24)}' : dn;
}

// ── Preview station suivante ──────────────────────────────────────────────────

class _NextStationPreview extends StatelessWidget {
  final RadioStation station;
  final bool         isDark;
  final List<Color>  grad;
  final VoidCallback onTap;

  const _NextStationPreview({
    required this.station,
    required this.isDark,
    required this.grad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg      = isDark ? const Color(0xFF0F1825) : const Color(0xFFEDE8E0);
    final muted   = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);
    final primary = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.skip_next_rounded, color: muted, size: 16),
            const SizedBox(width: 8),
            Text('Suivant', style: TextStyle(color: muted, fontSize: 10)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _stationLabel(station),
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            ClipOval(
              child: StationThumbnail(station: station, size: 32, circular: true),
            ),
          ],
        ),
      ),
    );
  }
}
