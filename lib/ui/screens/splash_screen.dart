import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bottom_nav_shell.dart';

const _kBgCenter = Color(0xFF1A3528);
const _kBgEdge   = Color(0xFF0A1A10);
const _kGold     = Color(0xFFD4AF77);

// Noms arabes des 18 sourates utilisées comme particules flottantes
const _kSurahNames = {
  1:   'الفاتحة',
  7:   'الأعراف',
  12:  'يوسف',
  18:  'الكهف',
  23:  'المؤمنون',
  29:  'العنكبوت',
  36:  'يس',
  48:  'الفتح',
  55:  'الرحمن',
  67:  'الملك',
  78:  'النبأ',
  89:  'الفجر',
  93:  'الضحى',
  99:  'الزلزلة',
  103: 'العصر',
  108: 'الكوثر',
  112: 'الإخلاص',
  114: 'الناس',
};

// ── Particle config ──────────────────────────────────────────────────────────

class _ParticleConfig {
  final int    surahIndex;
  final double x;         // fraction of screen width  (top-left anchor)
  final double y;         // fraction of screen height (top-left anchor)
  final double fontSize;  // text size in logical px
  final double opacity;   // peak opacity 0.10–0.22
  final int    delayMs;   // initial delay before first appearance

  const _ParticleConfig({
    required this.surahIndex,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.opacity,
    required this.delayMs,
  });
}

// ── SplashScreen ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController  _ctrl;
  late final Animation<double>    _logoFade;
  late final Animation<double>    _logoReveal;
  late final List<_ParticleConfig> _particles;

  @override
  void initState() {
    super.initState();

    // Retire le splash natif : Flutter est prêt, notre widget prend le relais.
    FlutterNativeSplash.remove();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _logoReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.17, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Positions fixes (seed 42) pour un layout stable entre rebuilds
    final rng = math.Random(42);
    _particles = [];
    for (final idx in _kSurahNames.keys) {
      double x, y;
      // Évite la zone centrale où se trouve le logo + bismillah
      do {
        x = rng.nextDouble() * 0.82;
        y = rng.nextDouble() * 0.82;
      } while (x > 0.18 && x < 0.78 && y > 0.20 && y < 0.80);

      _particles.add(_ParticleConfig(
        surahIndex: idx,
        x: x,
        y: y,
        fontSize: 14.0 + rng.nextDouble() * 12.0,  // 14–26 px
        opacity:  0.10 + rng.nextDouble() * 0.12,  // 0.10–0.22
        delayMs:  rng.nextInt(2000),                // 0–2 000 ms
      ));
    }

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1600), _navigate);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const BottomNavShell(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.sizeOf(context);
    final logoWidth = size.width * 0.70;

    return Scaffold(
      backgroundColor: _kBgEdge,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — fond radial gradient (statique)
          const _SplashBackground(),

          // Layer 2 — noms de sourates flottants en texte
          for (final p in _particles)
            Positioned(
              left: p.x * size.width,
              top:  p.y * size.height,
              child: _FloatingSurahText(config: p),
            ),

          // Layer 3 — logo + halo + bismillah (centré verticalement)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Halo pulsant derrière le logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _PulsingHalo(logoWidth: logoWidth),
                    // Logo avec reveal droite→gauche
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => FadeTransition(
                        opacity: _logoFade,
                        child: ClipRect(
                          clipper: _RevealClipper(_logoReveal.value),
                          child: SvgPicture.asset(
                            'assets/images/navbar/Quran_Kareem.svg',
                            width: logoWidth,
                            colorFilter: const ColorFilter.mode(
                              _kGold,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Bismillah qui s'écrit lettre par lettre
                const _BismillahTypewriter(startDelayMs: 900),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background ───────────────────────────────────────────────────────────────

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [_kBgCenter, _kBgEdge],
          stops: [0.0, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ── Reveal clipper (droite → gauche, sens naturel de l'arabe) ────────────────

class _RevealClipper extends CustomClipper<Rect> {
  final double progress;

  const _RevealClipper(this.progress);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    size.width * (1.0 - progress),
    0,
    size.width,
    size.height,
  );

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}

// ── Halo pulsant ─────────────────────────────────────────────────────────────

class _PulsingHalo extends StatefulWidget {
  final double logoWidth;

  const _PulsingHalo({required this.logoWidth});

  @override
  State<_PulsingHalo> createState() => _PulsingHaloState();
}

class _PulsingHaloState extends State<_PulsingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.20, end: 0.55).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haloSize = widget.logoWidth * 1.4;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width:  haloSize,
        height: haloSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _kGold.withValues(alpha: _opacity.value),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ── Bismillah typewriter ──────────────────────────────────────────────────────

class _BismillahTypewriter extends StatefulWidget {
  final int startDelayMs;

  const _BismillahTypewriter({required this.startDelayMs});

  @override
  State<_BismillahTypewriter> createState() => _BismillahTypewriterState();
}

class _BismillahTypewriterState extends State<_BismillahTypewriter>
    with SingleTickerProviderStateMixin {
  static const _text = 'بسم الله الرحمن الرحيم';

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  Timer? _timer;
  int    _charCount = 0;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: widget.startDelayMs), _start);
  }

  void _start() {
    if (!mounted) return;
    _fadeCtrl.forward();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) { t.cancel(); return; }
      final chars = _text.characters;
      if (_charCount >= chars.length) {
        t.cancel();
        return;
      }
      setState(() => _charCount++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _text.characters.take(_charCount).string;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Text(
        displayed,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'UthmanTahaNaskh',
          fontSize: 22,
          color: _kGold.withValues(alpha: 0.85),
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Noms de sourates flottants (texte) ───────────────────────────────────────

class _FloatingSurahText extends StatefulWidget {
  final _ParticleConfig config;

  const _FloatingSurahText({required this.config});

  @override
  State<_FloatingSurahText> createState() => _FloatingSurahTextState();
}

class _FloatingSurahTextState extends State<_FloatingSurahText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();

    final rng = math.Random(widget.config.surahIndex * 17 + widget.config.delayMs);
    final durationMs = 1600 + rng.nextInt(800); // 1 600–2 400 ms par cycle

    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: widget.config.opacity),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween(widget.config.opacity),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.config.opacity, end: 0.0),
        weight: 25,
      ),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.config.delayMs), _startLoop);
  }

  void _startLoop() {
    if (!mounted) return;
    _anim.forward().then((_) => _scheduleNext());
  }

  void _scheduleNext() {
    if (!mounted) return;
    _anim.reset();
    final rng = math.Random(
      widget.config.surahIndex + DateTime.now().millisecondsSinceEpoch % 10000,
    );
    final pauseMs = 300 + rng.nextInt(900); // 300–1 200 ms de pause
    Future.delayed(Duration(milliseconds: pauseMs), _startLoop);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Text(
          _kSurahNames[widget.config.surahIndex]!,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'ScheherazadeNew',
            fontSize: widget.config.fontSize,
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
