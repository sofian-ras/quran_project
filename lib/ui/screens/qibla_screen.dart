import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMeccaLat = 21.4225;
const _kMeccaLon = 39.8262;

// ── Thèmes ─────────────────────────────────────────────────────────────────────

class _QiblaTheme {
  final String name;
  final Color  bg, card, accent, dialInner, northColor;
  final List<Color> bgGradient; // dégradé de fond visible
  const _QiblaTheme({
    required this.name,
    required this.bg,
    required this.card,
    required this.accent,
    required this.dialInner,
    required this.northColor,
    required this.bgGradient,
  });
}

const _kThemes = [
  _QiblaTheme(
    name:       'Émeraude',
    bg:         Color(0xFF0A1A0F),
    card:       Color(0xFF152A1A),
    accent:     Color(0xFFC8A165),
    dialInner:  Color(0xFF1E3A26),
    northColor: Color(0xFFE57373),
    bgGradient: [Color(0xFF0F2A18), Color(0xFF050E08)],
  ),
  _QiblaTheme(
    name:       'Nuit',
    bg:         Color(0xFF07091C),
    card:       Color(0xFF10153A),
    accent:     Color(0xFF7EC8E3),
    dialInner:  Color(0xFF141E50),
    northColor: Color(0xFF80CBC4),
    bgGradient: [Color(0xFF0D1440), Color(0xFF040610)],
  ),
  _QiblaTheme(
    name:       'Désert',
    bg:         Color(0xFF180E04),
    card:       Color(0xFF2C1C0A),
    accent:     Color(0xFFE8C07A),
    dialInner:  Color(0xFF3D2510),
    northColor: Color(0xFFFFAB40),
    bgGradient: [Color(0xFF2E1A07), Color(0xFF0E0803)],
  ),
];

// ── Écran ──────────────────────────────────────────────────────────────────────

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool    _loadingGps = true;
  String? _gpsError;
  double? _qiblaBearing;
  int     _themeIndex = 0;

  _QiblaTheme get _theme => _kThemes[_themeIndex];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadGps();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _themeIndex = (prefs.getInt('qibla_theme') ?? 0).clamp(0, 2));
  }

  Future<void> _saveTheme(int idx) async =>
      (await SharedPreferences.getInstance()).setInt('qibla_theme', idx);

  Future<void> _loadGps() async {
    setState(() { _loadingGps = true; _gpsError = null; _qiblaBearing = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _loadingGps = false; _gpsError = 'Permission de localisation refusée.'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() {
        _loadingGps   = false;
        _qiblaBearing = _calcBearing(pos.latitude, pos.longitude);
      });
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

  void _selectTheme(int idx) {
    setState(() => _themeIndex = idx);
    _saveTheme(idx);
  }

  void _showThemePicker() {
    final t = _theme;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thème', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_kThemes.length, (i) {
                  final th  = _kThemes[i];
                  final sel = i == _themeIndex;
                  return GestureDetector(
                    onTap: () { _selectTheme(i); Navigator.pop(ctx); },
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                              colors: th.bgGradient,
                            ),
                            border: Border.all(color: sel ? th.accent : Colors.white24, width: sel ? 3 : 1.5),
                            boxShadow: sel ? [BoxShadow(color: th.accent.withAlpha(120), blurRadius: 14)] : [],
                          ),
                          child: Center(
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: th.accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(th.name, style: TextStyle(
                          color: sel ? th.accent : Colors.white54,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        )),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: t.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar custom
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      color: Colors.white70,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text('Qibla',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
                    ),
                    IconButton(
                      tooltip: 'Recalculer',
                      icon: Icon(Icons.my_location_rounded, color: t.accent),
                      onPressed: _loadingGps ? null : _loadGps,
                    ),
                    IconButton(
                      tooltip: 'Thème',
                      icon: Icon(Icons.palette_outlined, color: t.accent),
                      onPressed: _showThemePicker,
                    ),
                  ],
                ),
              ),
              // Corps
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingGps) return Center(child: CircularProgressIndicator(color: _theme.accent));
    if (_gpsError  != null) return _ErrorView(message: _gpsError!, onRetry: _loadGps, theme: _theme);
    return _QiblaCompass(qiblaBearing: _qiblaBearing!, theme: _theme);
  }
}

// ── Boussole ───────────────────────────────────────────────────────────────────

class _QiblaCompass extends StatefulWidget {
  final double qiblaBearing;
  final _QiblaTheme theme;
  const _QiblaCompass({required this.qiblaBearing, required this.theme});
  @override
  State<_QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<_QiblaCompass> with TickerProviderStateMixin {
  // Données boussole
  double? _heading;
  double? _accuracy;
  StreamSubscription<CompassEvent>? _sub;

  // État alignement
  bool _wasAligned = false;
  bool _isAligned  = false;

  // Animation lumière
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _glowCtrl.reverse();
      });
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

    // Un seul listener pour tout : données UI + vibration + animation
    _sub = FlutterCompass.events?.listen(_onCompass);
  }

  void _onCompass(CompassEvent event) {
    final h = event.heading;
    if (!mounted) return;

    setState(() {
      _heading  = h;
      _accuracy = event.accuracy;
    });

    if (h == null) return;
    final toQibla = ((widget.qiblaBearing - h) % 360 + 360) % 360;
    final aligned = toQibla < 5 || toQibla > 355;

    setState(() => _isAligned = aligned);

    if (aligned && !_wasAligned) {
      // Vibration
      HapticFeedback.vibrate();
      // Lumière
      _glowCtrl.forward(from: 0);
    }
    _wasAligned = aligned;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t        = widget.theme;
    final dialSize = MediaQuery.of(context).size.width * 0.82;
    final heading  = _heading;
    final accuracy = _accuracy;

    final poorAccuracy = heading == null || (accuracy != null && accuracy > 45);
    final dialAngle    = heading != null ? -(heading * math.pi / 180) : 0.0;
    final toQibla      = heading != null
        ? ((widget.qiblaBearing - heading) % 360 + 360) % 360
        : widget.qiblaBearing;

    return Column(
      children: [
        const SizedBox(height: 12),

        // ── Compteurs ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoTile(label: 'Cap',   value: heading != null ? '${heading.toStringAsFixed(0)}°' : '--', icon: Icons.explore_outlined,   theme: t),
              _InfoTile(label: 'Qibla', value: '${widget.qiblaBearing.toStringAsFixed(0)}°',              icon: Icons.mosque_rounded,       theme: t),
              _InfoTile(label: 'Reste', value: heading != null ? '${toQibla.toStringAsFixed(0)}°' : '--', icon: Icons.rotate_right_rounded, theme: t),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // ── Boussole + halo ───────────────────────────────────────────────
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Halo de lumière quand aligné
                if (_glowAnim.value > 0)
                  Opacity(
                    opacity: _glowAnim.value,
                    child: Container(
                      width:  dialSize * (1.0 + _glowAnim.value * 0.25),
                      height: dialSize * (1.0 + _glowAnim.value * 0.25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          t.accent.withAlpha((180 * _glowAnim.value).toInt()),
                          t.accent.withAlpha(0),
                        ]),
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: dialAngle,
                child: _DialWidget(
                  size:              dialSize,
                  qiblaBearing:      widget.qiblaBearing,
                  kaabaCounterAngle: -dialAngle,
                  theme:             t,
                ),
              ),
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: const Size(22, 16),
                  painter: _IndicatorPainter(color: t.accent),
                ),
              ),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Guidage ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: poorAccuracy
              ? _CalibrationHint(theme: t)
              : _GuidanceBanner(aligned: _isAligned, theme: t),
        ),
      ],
    );
  }
}

// ── Cadran ─────────────────────────────────────────────────────────────────────

class _DialWidget extends StatelessWidget {
  final double size, qiblaBearing, kaabaCounterAngle;
  final _QiblaTheme theme;
  const _DialWidget({required this.size, required this.qiblaBearing, required this.kaabaCounterAngle, required this.theme});

  @override
  Widget build(BuildContext context) {
    final r        = size / 2;
    final kaabaR   = r - 52;
    final qiblaRad = qiblaBearing * math.pi / 180;

    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _DialPainter(theme: theme)),
          ..._cardinals(r),
          Transform.translate(
            offset: Offset(kaabaR * math.sin(qiblaRad), -kaabaR * math.cos(qiblaRad)),
            child: Transform.rotate(
              angle: kaabaCounterAngle,
              child: Image.asset('assets/icon/kaaba.png', width: 44, height: 44, fit: BoxFit.contain),
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
    return List.generate(4, (i) => Transform.translate(
      offset: Offset(lr * math.sin(angles[i]), -lr * math.cos(angles[i])),
      child: Text(labels[i], style: TextStyle(
        color: labels[i] == 'N' ? theme.northColor : Colors.white70,
        fontWeight: FontWeight.bold, fontSize: 15,
      )),
    ));
  }
}

class _DialPainter extends CustomPainter {
  final _QiblaTheme theme;
  const _DialPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..shader = RadialGradient(colors: [theme.dialInner, theme.bg])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawCircle(Offset(cx, cy), r - 1,
      Paint()..color = theme.accent.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final tickPaint = Paint()..style = PaintingStyle.stroke;
    for (int i = 0; i < 360; i += 5) {
      final angle = i * math.pi / 180;
      final isMaj = i % 45 == 0;
      final isMed = i % 15 == 0;
      final len   = isMaj ? 14.0 : (isMed ? 9.0 : 5.0);
      tickPaint
        ..color       = isMaj ? theme.accent.withAlpha(200) : Colors.white.withAlpha(isMed ? 100 : 50)
        ..strokeWidth = isMaj ? 1.5 : 1.0;
      canvas.drawLine(
        Offset(cx + (r - 2)       * math.sin(angle), cy - (r - 2)       * math.cos(angle)),
        Offset(cx + (r - 2 - len) * math.sin(angle), cy - (r - 2 - len) * math.cos(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.theme != theme;
}

class _IndicatorPainter extends CustomPainter {
  final Color color;
  const _IndicatorPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()..moveTo(size.width / 2, size.height)..lineTo(0, 0)..lineTo(size.width, 0)..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }
  @override
  bool shouldRepaint(_IndicatorPainter old) => old.color != color;
}

// ── Calibration en 8 ───────────────────────────────────────────────────────────

class _CalibrationHint extends StatefulWidget {
  final _QiblaTheme theme;
  const _CalibrationHint({required this.theme});
  @override
  State<_CalibrationHint> createState() => _CalibrationHintState();
}

class _CalibrationHintState extends State<_CalibrationHint> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(); }
  @override
  void dispose()   { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.accent.withAlpha(60))),
      child: Column(children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: t.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Précision insuffisante — calibre le capteur',
            style: TextStyle(color: t.accent, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final a = _ctrl.value * 2 * math.pi;
            return SizedBox(
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: const Size(140, 90), painter: _Figure8Painter(progress: _ctrl.value, color: t.accent)),
                  Transform.translate(
                    offset: Offset(math.sin(a) * 44, math.sin(2 * a) * 22),
                    child: Transform.rotate(
                      angle: math.cos(a) * 0.3,
                      child: Icon(Icons.smartphone_rounded, color: t.accent, size: 34),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        const Text('Tiens le téléphone à plat et trace\nun mouvement en 8 dans les airs.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

class _Figure8Painter extends CustomPainter {
  final double progress, dummy = 0;
  final Color  color;
  const _Figure8Painter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    const rx = 44.0, ry = 22.0;

    final bg = Path();
    for (int i = 0; i <= 100; i++) {
      final a = i / 100 * 2 * math.pi;
      i == 0 ? bg.moveTo(cx + math.sin(a) * rx, cy + math.sin(2 * a) * ry)
             : bg.lineTo(cx + math.sin(a) * rx, cy + math.sin(2 * a) * ry);
    }
    canvas.drawPath(bg, Paint()..color = color.withAlpha(35)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);

    final trail = Path();
    bool started = false;
    for (int i = 0; i <= 60; i++) {
      final a = (progress - 0.3 + i / 60.0 * 0.3) * 2 * math.pi;
      final x = cx + math.sin(a) * rx, y = cy + math.sin(2 * a) * ry;
      if (!started) { trail.moveTo(x, y); started = true; } else { trail.lineTo(x, y); }
    }
    canvas.drawPath(trail, Paint()..color = color.withAlpha(180)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Figure8Painter old) => old.progress != progress || old.color != color;
}

// ── Widgets utilitaires ────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final _QiblaTheme theme;
  const _InfoTile({required this.label, required this.value, required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.accent.withAlpha(40))),
    child: Column(children: [
      Icon(icon, color: theme.accent, size: 16),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]),
  );
}

class _GuidanceBanner extends StatelessWidget {
  final bool aligned;
  final _QiblaTheme theme;
  const _GuidanceBanner({required this.aligned, required this.theme});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: aligned ? Colors.green.withAlpha(40) : theme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: aligned ? Colors.greenAccent.withAlpha(150) : theme.accent.withAlpha(40)),
    ),
    child: Row(children: [
      Icon(aligned ? Icons.check_circle_rounded : Icons.info_outline_rounded,
        color: aligned ? Colors.greenAccent : theme.accent, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(
        aligned ? 'Tu fais face à la Kaaba !' : 'Tourne le téléphone jusqu\'à ce que l\'icône Kaaba soit sous le triangle doré.',
        style: TextStyle(color: aligned ? Colors.greenAccent : Colors.white70, fontSize: 13, height: 1.4),
      )),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final _QiblaTheme theme;
  const _ErrorView({required this.message, required this.onRetry, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.location_off_rounded, color: Colors.white38, size: 64),
      const SizedBox(height: 20),
      Text(message, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(backgroundColor: theme.accent, foregroundColor: Colors.black),
      ),
    ]),
  );
}
