import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

const _kMeccaLat = 21.4225;
const _kMeccaLon = 39.8262;
const _kGold  = Color(0xFFC8A165);
const _kGreen = Color(0xFF1A6B2A);
const _kBg    = Color(0xFF0D1B12);
const _kCard  = Color(0xFF1A2E1F);

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool    _loadingGps = true;
  String? _gpsError;
  double? _qiblaBearing;

  @override
  void initState() {
    super.initState();
    _loadGps();
  }

  Future<void> _loadGps() async {
    setState(() { _loadingGps = true; _gpsError = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _loadingGps = false; _gpsError = 'Permission de localisation refusée.'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() { _loadingGps = false; _qiblaBearing = _calcBearing(pos.latitude, pos.longitude); });
    } catch (e) {
      if (mounted) setState(() { _loadingGps = false; _gpsError = 'Erreur GPS : $e'; });
    }
  }

  static double _calcBearing(double lat, double lon) {
    final lat1 = lat * math.pi / 180;
    const lat2 = _kMeccaLat * math.pi / 180;
    final dLon = (_kMeccaLon - lon) * math.pi / 180;
    final y    = math.sin(dLon) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: const Text('Qibla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingGps) return const Center(child: CircularProgressIndicator(color: _kGold));
    if (_gpsError != null) return _ErrorView(message: _gpsError!, onRetry: _loadGps);
    return _QiblaCompass(qiblaBearing: _qiblaBearing!);
  }
}

// ── Boussole principale ────────────────────────────────────────────────────────

class _QiblaCompass extends StatefulWidget {
  final double qiblaBearing;
  const _QiblaCompass({required this.qiblaBearing});
  @override
  State<_QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<_QiblaCompass> {
  bool _wasAligned = false;
  StreamSubscription<CompassEvent>? _vibrationSub;

  @override
  void initState() {
    super.initState();
    // Vibration dans un listener séparé — jamais dans build()
    _vibrationSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null) return;
      final toQibla = ((widget.qiblaBearing - heading) % 360 + 360) % 360;
      final aligned = toQibla < 5 || toQibla > 355;
      if (aligned && !_wasAligned) {
        HapticFeedback.mediumImpact();
      }
      _wasAligned = aligned;
    });
  }

  @override
  void dispose() {
    _vibrationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialSize = MediaQuery.of(context).size.width * 0.82;

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snap) {
        final heading  = snap.data?.heading;
        final accuracy = snap.data?.accuracy; // degrés, null si indisponible
        final poorAccuracy = heading == null || (accuracy != null && accuracy > 45);

        final dialAngle = heading != null ? -(heading * math.pi / 180) : 0.0;
        final toQibla   = heading != null
            ? ((widget.qiblaBearing - heading) % 360 + 360) % 360
            : widget.qiblaBearing;
        final aligned = toQibla < 5 || toQibla > 355;


        return Column(
          children: [
            const SizedBox(height: 16),

            // ── Compteurs temps réel ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoTile(
                    label: 'Cap',
                    value: heading != null ? '${heading.toStringAsFixed(0)}°' : '--',
                    icon: Icons.explore_outlined,
                  ),
                  _InfoTile(
                    label: 'Qibla',
                    value: '${widget.qiblaBearing.toStringAsFixed(0)}°',
                    icon: Icons.mosque_rounded,
                  ),
                  _InfoTile(
                    label: 'Reste',
                    value: heading != null ? '${toQibla.toStringAsFixed(0)}°' : '--',
                    icon: Icons.rotate_right_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Boussole ──────────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                // Cadran rotatif (N toujours vers le Nord)
                Transform.rotate(
                  angle: dialAngle,
                  child: _DialWidget(
                    size: dialSize,
                    qiblaBearing: widget.qiblaBearing,
                    // Counter-rotation pour garder la Kaaba droite
                    kaabaCounterAngle: -dialAngle,
                  ),
                ),
                // Triangle indicateur fixe en haut
                Positioned(
                  top: 0,
                  child: CustomPaint(size: const Size(22, 16), painter: _IndicatorPainter()),
                ),
                // Centre
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGold),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Calibration ou guidage ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: poorAccuracy
                  ? const _CalibrationHint()
                  : _GuidanceBanner(aligned: aligned),
            ),
          ],
        );
      },
    );
  }
}

// ── Cadran ─────────────────────────────────────────────────────────────────────

class _DialWidget extends StatelessWidget {
  final double size;
  final double qiblaBearing;
  final double kaabaCounterAngle; // annule la rotation du cadran → icône toujours droite

  const _DialWidget({
    required this.size,
    required this.qiblaBearing,
    required this.kaabaCounterAngle,
  });

  @override
  Widget build(BuildContext context) {
    final r        = size / 2;
    final kaabaR   = r - 52;
    final qiblaRad = qiblaBearing * math.pi / 180;
    final kaabaX   = kaabaR * math.sin(qiblaRad);
    final kaabaY   = -kaabaR * math.cos(qiblaRad);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fond + graduations
          CustomPaint(size: Size(size, size), painter: _DialPainter()),
          // Points cardinaux
          ..._cardinals(r),
          // Icône Kaaba counter-rotée pour rester droite
          Transform.translate(
            offset: Offset(kaabaX, kaabaY),
            child: Transform.rotate(
              angle: kaabaCounterAngle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGold,
                      boxShadow: [BoxShadow(color: _kGold.withAlpha(140), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.mosque_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(height: 2),
                  const Text('Kaaba', style: TextStyle(color: _kGold, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cardinals(double r) {
    const labels = ['N', 'E', 'S', 'O'];
    const angles = [0.0, math.pi / 2, math.pi, -math.pi / 2];
    final lr = r - 18;
    return List.generate(4, (i) {
      final dx = lr * math.sin(angles[i]);
      final dy = -lr * math.cos(angles[i]);
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Text(
          labels[i],
          style: TextStyle(
            color: labels[i] == 'N' ? Colors.red[300] : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );
    });
  }
}

// ── Dessin du cadran ───────────────────────────────────────────────────────────

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..shader = const RadialGradient(
        colors: [Color(0xFF1E3A26), _kBg],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawCircle(Offset(cx, cy), r - 1,
      Paint()..color = _kGold.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final tickPaint = Paint()..style = PaintingStyle.stroke;
    for (int i = 0; i < 360; i += 5) {
      final angle = i * math.pi / 180;
      final isMaj = i % 45 == 0;
      final isMed = i % 15 == 0;
      final len   = isMaj ? 14.0 : (isMed ? 9.0 : 5.0);
      tickPaint
        ..color       = isMaj ? _kGold.withAlpha(200) : Colors.white.withAlpha(isMed ? 100 : 50)
        ..strokeWidth = isMaj ? 1.5 : 1.0;
      final x1 = cx + (r - 2)         * math.sin(angle);
      final y1 = cy - (r - 2)         * math.cos(angle);
      final x2 = cx + (r - 2 - len)   * math.sin(angle);
      final y2 = cy - (r - 2 - len)   * math.cos(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => false;
}

// ── Triangle indicateur fixe ───────────────────────────────────────────────────

class _IndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = _kGold..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_IndicatorPainter old) => false;
}

// ── Animation calibration en 8 ─────────────────────────────────────────────────

class _CalibrationHint extends StatefulWidget {
  const _CalibrationHint();
  @override
  State<_CalibrationHint> createState() => _CalibrationHintState();
}

class _CalibrationHintState extends State<_CalibrationHint> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withAlpha(60)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _kGold, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Précision insuffisante — calibre le capteur',
                  style: TextStyle(color: _kGold, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Téléphone animé en mouvement en 8
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value * 2 * math.pi;
              // Lissajous figure-8 : x = sin(t), y = sin(2t)/2
              final px = math.sin(t) * 44.0;
              final py = math.sin(2 * t) * 22.0;
              // Inclinaison légère selon le mouvement
              final tilt = math.cos(t) * 0.3;

              return SizedBox(
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Tracé du 8
                    CustomPaint(
                      size: const Size(140, 90),
                      painter: _Figure8Painter(progress: _ctrl.value),
                    ),
                    // Téléphone
                    Transform.translate(
                      offset: Offset(px, py),
                      child: Transform.rotate(
                        angle: tilt,
                        child: const Icon(Icons.smartphone_rounded, color: _kGold, size: 34),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Tiens le téléphone à plat et trace\nun mouvement en 8 dans les airs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Figure8Painter extends CustomPainter {
  final double progress; // 0..1

  const _Figure8Painter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    const rx = 44.0;
    const ry = 22.0;

    // Tracé complet du 8 (atténué)
    final bgPath = Path();
    for (int i = 0; i <= 100; i++) {
      final a = i / 100 * 2 * math.pi;
      final x = cx + math.sin(a) * rx;
      final y = cy + math.sin(2 * a) * ry;
      i == 0 ? bgPath.moveTo(x, y) : bgPath.lineTo(x, y);
    }
    canvas.drawPath(
      bgPath,
      Paint()
        ..color       = _kGold.withAlpha(35)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap   = StrokeCap.round,
    );

    // Traînée lumineuse (dernier 30 % du tracé)
    final trailPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap   = StrokeCap.round;

    const trailLen = 0.30;
    final trailPath = Path();
    bool started = false;
    for (int i = 0; i <= 60; i++) {
      final frac = i / 60.0;
      final a    = (progress - trailLen + frac * trailLen) * 2 * math.pi;
      final x    = cx + math.sin(a) * rx;
      final y    = cy + math.sin(2 * a) * ry;
      final alpha = (frac * 200).toInt().clamp(0, 200);
      if (!started) { trailPath.moveTo(x, y); started = true; }
      else           { trailPath.lineTo(x, y); }
      trailPaint.color = _kGold.withAlpha(alpha);
      // draw segment by segment for gradient effect
    }
    // draw trail in one shot with max alpha
    trailPaint.color = _kGold.withAlpha(180);
    canvas.drawPath(trailPath, trailPaint);
  }

  @override
  bool shouldRepaint(_Figure8Painter old) => old.progress != progress;
}

// ── Tuile info ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kGold, size: 16),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Bannière guidage ───────────────────────────────────────────────────────────

class _GuidanceBanner extends StatelessWidget {
  final bool aligned;
  const _GuidanceBanner({required this.aligned});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: aligned ? _kGreen.withAlpha(60) : _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: aligned ? Colors.greenAccent.withAlpha(150) : _kGold.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(
            aligned ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: aligned ? Colors.greenAccent : _kGold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              aligned
                  ? 'Tu fais face à la Kaaba !'
                  : 'Tourne le téléphone jusqu\'à ce que l\'icône Kaaba soit sous le triangle doré.',
              style: TextStyle(
                color: aligned ? Colors.greenAccent : Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Erreur GPS ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off_rounded, color: Colors.white38, size: 64),
          const SizedBox(height: 20),
          Text(message,
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}
