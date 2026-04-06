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

  RadioStation get _station =>
      RadioService.instance.currentStationNotifier.value ?? widget.station;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    RadioService.instance
        .isFavorite(widget.station.id)
        .then((v) { if (mounted) setState(() => _isFavorite = v); });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_favLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _favLoading = true);
    final result = await RadioService.instance.toggleFavorite(_station);
    if (mounted) setState(() { _isFavorite = result; _favLoading = false; });
  }

  Future<void> _stop() async {
    await AudioService.instance.stopRadio();
    if (mounted) Navigator.of(context).pop();
  }

  void _skipTo(int delta) {
    final stations = RadioService.instance.cachedStations;
    if (stations.isEmpty) return;
    final idx = stations.indexWhere((s) => s.id == _station.id);
    if (idx < 0) return;
    final next = stations[(idx + delta) % stations.length];
    HapticFeedback.lightImpact();
    AudioService.instance.playRadio(next);
    RadioService.instance.currentStationNotifier.value = next;
    RadioService.instance.trackPlay(next);
    setState(() {
      RadioService.instance
          .isFavorite(next.id)
          .then((v) { if (mounted) setState(() => _isFavorite = v); });
    });
  }

  RadioStation? get _nextStation {
    final stations = RadioService.instance.cachedStations;
    if (stations.isEmpty) return null;
    final idx = stations.indexWhere((s) => s.id == _station.id);
    if (idx < 0) return null;
    return stations[(idx + 1) % stations.length];
  }

  @override
  Widget build(BuildContext context) {
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
              if (_dragDir == null) {
                if (d.delta.dx.abs() > d.delta.dy.abs() + 4) {
                  setState(() => _dragDir = 'h');
                } else if (d.delta.dy > 0 && d.delta.dy.abs() > d.delta.dx.abs() + 4) {
                  setState(() => _dragDir = 'v');
                }
              }
              if (_dragDir == 'h') { setState(() => _dragX = (_dragX + d.delta.dx).clamp(-160.0, 160.0)); }
              if (_dragDir == 'v') { setState(() => _dragY = (_dragY + d.delta.dy).clamp(0.0, 200.0)); }
            },
            onPanEnd: (d) {
              final vx = d.velocity.pixelsPerSecond.dx;
              final vy = d.velocity.pixelsPerSecond.dy;
              if (_dragDir == 'h') {
                if (_dragX < -60 || vx < -500) { _skipTo(1); }
                else if (_dragX > 60 || vx > 500) { _skipTo(-1); }
              } else if (_dragDir == 'v') {
                if (_dragY > 120 || vy > 600) { _stop(); return; }
              }
              setState(() { _dragX = 0; _dragY = 0; _dragDir = null; });
            },
            child: Stack(
              children: [
                // ── Fond image floue ─────────────────────────────────────
                Positioned.fill(
                  child: _BlurredBackground(station: _station, grad: grad, isDark: isDark),
                ),

                // ── Contenu (suit le drag) ────────────────────────────────
                Transform.translate(
                  offset: Offset(_dragX * 0.35, _dragY),
                  child: Opacity(
                    opacity: (1.0 - (_dragY / 300)).clamp(0.0, 1.0),
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(isDark, cat),
                          Expanded(child: _buildBody(isDark, cat, grad)),
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
    final textColor = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF111827);
    final mutedColor = isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          ),
          Expanded(
            child: Text(
              'En direct',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
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

          // ── Précédent / Play / Suivant ────────────────────────
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
                  // Précédent
                  IconButton(
                    onPressed: () => _skipTo(-1),
                    icon: Icon(Icons.skip_previous_rounded,
                        color: mutedColor, size: 36),
                    iconSize: 36,
                  ),
                  const SizedBox(width: 24),
                  // Play / Pause
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
                  // Suivant
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

          const SizedBox(height: 24),

          // ── Stop ─────────────────────────────────────────────────
          TextButton.icon(
            onPressed: _stop,
            icon: Icon(Icons.stop_circle_outlined, color: mutedColor, size: 18),
            label: Text('Arrêter', style: TextStyle(color: mutedColor, fontSize: 13)),
          ),

          // ── Preview station suivante ──────────────────────────
          if (_nextStation != null) ...[
            const SizedBox(height: 8),
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

  String get _catAsset => kCatAssets[categorizeStation(station)] ?? '';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image de catégorie en fond
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
        // Flou
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: const SizedBox.expand(),
          ),
        ),
        // Tint léger + fondu bas
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

  String get _catAsset => kCatAssets[categorizeStation(station)] ?? '';

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

    return _catAsset.isNotEmpty
        ? Image.asset(_catAsset, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback)
        : fallback;
  }
}

// ── Helpers réexportés depuis radio_browser_screen (évite import circulaire) ──
// categorizeStation et radioCategoryGradient sont publics dans radio_browser_screen.dart
// On les réexporte ici via l'import en tête de fichier.

String _stationLabel(RadioStation s) {
  if (categorizeStation(s) != '🌍 Traductions') return s.displayName;
  final n = s.name.toLowerCase();
  if (n.contains('français') || n.contains('french')) return 'Traduction française';
  if (n.contains('anglais')  || n.contains('english')) return 'Traduction anglaise';
  if (n.contains('urdu'))    return 'Traduction ourdou';
  if (n.contains('türk')    || n.contains('turc'))    return 'Traduction turque';
  if (n.contains('indonesia') || n.contains('malay')) return 'Traduction indonésienne';
  if (n.contains('bangla')  || n.contains('bengali')) return 'Traduction bengalie';
  if (n.contains('swahili')) return 'Traduction swahili';
  if (n.contains('farsi')   || n.contains('persan'))  return 'Traduction persane';
  if (n.contains('bosni'))   return 'Traduction bosniaque';
  final match = RegExp(r'traduct|translat', caseSensitive: false).firstMatch(s.name);
  if (match != null) {
    final from = s.name.substring(match.start).trim();
    final label = from[0].toUpperCase() + from.substring(1);
    return label.length > 26 ? '…${label.substring(label.length - 24)}' : label;
  }
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
