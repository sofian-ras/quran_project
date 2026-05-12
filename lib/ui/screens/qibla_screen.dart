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
  final Color  textPrimary, textSecondary; // adaptés clair/sombre
  final List<Color> bgGradient;
  const _QiblaTheme({
    required this.name,
    required this.bg,
    required this.card,
    required this.accent,
    required this.dialInner,
    required this.northColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.bgGradient,
  });
}

const _kThemes = [
  // ── Classique : fond blanc cassé, accents verts et or ──────────────────────
  _QiblaTheme(
    name:          'Classique',
    bg:            Color(0xFFF5F2EA),
    card:          Color(0xFFFFFFFF),
    accent:        Color(0xFF2E7D32),
    dialInner:     Color(0xFFE8F5E9),
    northColor:    Color(0xFFC62828),
    textPrimary:   Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    bgGradient:    [Color(0xFFF0ECD8), Color(0xFFFAF8F0)],
  ),
  // ── Ciel : fond bleu clair, accents bleu marine ────────────────────────────
  _QiblaTheme(
    name:          'Ciel',
    bg:            Color(0xFFE8F4FD),
    card:          Color(0xFFFFFFFF),
    accent:        Color(0xFF1565C0),
    dialInner:     Color(0xFFDCEEFA),
    northColor:    Color(0xFFC62828),
    textPrimary:   Color(0xFF0D2137),
    textSecondary: Color(0xFF546E7A),
    bgGradient:    [Color(0xFFBBDEFB), Color(0xFFE8F4FD)],
  ),
  // ── Sable : fond beige chaud, accents terre cuite ──────────────────────────
  _QiblaTheme(
    name:          'Sable',
    bg:            Color(0xFFFFF8EC),
    card:          Color(0xFFFFFFFF),
    accent:        Color(0xFF8D5524),
    dialInner:     Color(0xFFFFF3E0),
    northColor:    Color(0xFFB71C1C),
    textPrimary:   Color(0xFF3E2000),
    textSecondary: Color(0xFF795548),
    bgGradient:    [Color(0xFFFFE0B2), Color(0xFFFFF8EC)],
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
    _loadCachedBearingThenRefresh();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _themeIndex = (prefs.getInt('qibla_theme') ?? 0).clamp(0, 2));
  }

  Future<void> _saveTheme(int idx) async =>
      (await SharedPreferences.getInstance()).setInt('qibla_theme', idx);

  Future<void> _loadCachedBearingThenRefresh() async {
    final prefs     = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble('qibla_last_lat');
    final cachedLon = prefs.getDouble('qibla_last_lon');
    if (cachedLat != null && cachedLon != null && mounted) {
      setState(() {
        _loadingGps   = false;
        _qiblaBearing = _calcBearing(cachedLat, cachedLon);
      });
    }
    _loadGps();
  }

  Future<void> _loadGps() async {
    if (_qiblaBearing == null && mounted) {
      setState(() { _loadingGps = true; _gpsError = null; });
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loadingGps = false;
            if (_qiblaBearing == null) _gpsError = 'Permission de localisation refusée.';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('qibla_last_lat', pos.latitude);
      await prefs.setDouble('qibla_last_lon', pos.longitude);
      if (mounted) {
        setState(() {
          _loadingGps   = false;
          _qiblaBearing = _calcBearing(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingGps = false;
          if (_qiblaBearing == null) _gpsError = 'Erreur GPS : $e';
        });
      }
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
                            border: Border.all(color: sel ? th.accent : th.textSecondary.withAlpha(80), width: sel ? 3 : 1.5),
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
                          color: sel ? th.accent : th.textSecondary,
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
                      color: t.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text('Qibla',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
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
  late final Widget _kaabaImage = Image.asset('assets/icon/kaaba.png', width: 44, height: 44, fit: BoxFit.contain);

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

    // Throttle: skip if heading unchanged beyond 0.5°
    if (h != null && _heading != null && (h - _heading!).abs() < 0.5) return;

    final toQibla = h != null ? ((widget.qiblaBearing - h) % 360 + 360) % 360 : null;
    final aligned = toQibla != null && (toQibla < 5 || toQibla > 355);

    setState(() {
      _heading  = h;
      _accuracy = event.accuracy;
      _isAligned = aligned;
    });

    if (aligned && !_wasAligned) {
      HapticFeedback.vibrate();
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
    final t           = widget.theme;
    final screenWidth = MediaQuery.of(context).size.width;
    final heading     = _heading;
    final accuracy    = _accuracy;

    final poorAccuracy = heading == null || (accuracy != null && accuracy > 45);
    final dialAngle    = heading != null ? -(heading * math.pi / 180) : 0.0;
    final toQibla      = heading != null
        ? ((widget.qiblaBearing - heading) % 360 + 360) % 360
        : widget.qiblaBearing;

    return LayoutBuilder(
      builder: (context, constraints) {
        // CalibrationHint (~200px) is much taller than GuidanceBanner (~60px)
        final double kFixedOverhead = poorAccuracy ? 336.0 : 194.0;
        final double maxFromHeight  = (constraints.maxHeight - kFixedOverhead) / 1.28;
        final double dialSize       = math.min(screenWidth * 0.82, maxFromHeight).clamp(120.0, 400.0);

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
        // SizedBox fixe = pas de layout shift quand le halo pulse
        SizedBox(
          width:  dialSize * 1.28,
          height: dialSize * 1.28,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Halo sur le cadran
                  if (_glowAnim.value > 0)
                    Container(
                      width:  dialSize * (1.0 + _glowAnim.value * 0.28),
                      height: dialSize * (1.0 + _glowAnim.value * 0.28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          t.accent.withAlpha((160 * _glowAnim.value).toInt()),
                          t.accent.withAlpha(0),
                        ]),
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
                    kaabaWidget:       _kaabaImage,
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
      },
    );
  }
}

// ── Cadran ─────────────────────────────────────────────────────────────────────

class _DialWidget extends StatelessWidget {
  final double size, qiblaBearing, kaabaCounterAngle;
  final _QiblaTheme theme;
  final Widget kaabaWidget;
  const _DialWidget({required this.size, required this.qiblaBearing, required this.kaabaCounterAngle, required this.theme, required this.kaabaWidget});

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
              child: kaabaWidget,
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
        color: labels[i] == 'N' ? theme.northColor : theme.textSecondary,
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
        ..color       = isMaj ? theme.accent.withAlpha(200) : theme.textSecondary.withAlpha(isMed ? 100 : 50)
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
        Text('Tiens le téléphone à plat et trace\nun mouvement en 8 dans les airs.',
          textAlign: TextAlign.center,
          style: TextStyle(color: widget.theme.textSecondary, fontSize: 12, height: 1.4)),
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
      Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
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
        style: TextStyle(color: aligned ? Colors.green[700] : theme.textSecondary, fontSize: 13, height: 1.4),
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
      Icon(Icons.location_off_rounded, color: theme.textSecondary, size: 64),
      const SizedBox(height: 20),
      Text(message, style: TextStyle(color: theme.textSecondary, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(backgroundColor: theme.accent, foregroundColor: Colors.white),
      ),
    ]),
  );
}
