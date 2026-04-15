import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bottom_nav_shell.dart';

const _kBgCenter = Color(0xFF1A3528);
const _kBgEdge   = Color(0xFF0A1A10);
const _kGold     = Color(0xFFD4AF77);

// 18 surahs spread across all 114 — covers variety of name lengths and shapes
const _kSurahIndices = [1, 7, 12, 18, 23, 29, 36, 48, 55, 67, 78, 89, 93, 99, 103, 108, 112, 114];

// ── Particle config ──────────────────────────────────────────────────────────

class _ParticleConfig {
  final int    surahIndex;
  final double x;        // fraction of screen width  (top-left anchor)
  final double y;        // fraction of screen height (top-left anchor)
  final double size;     // SVG height in logical px
  final double opacity;  // peak opacity 0.10–0.22
  final int    delayMs;  // initial delay before first appearance

  const _ParticleConfig({
    required this.surahIndex,
    required this.x,
    required this.y,
    required this.size,
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
  late final AnimationController _ctrl;
  late final Animation<double>   _logoFade;
  late final Animation<double>   _logoReveal;
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

    // Logo fades in during the first 25% of the animation
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Logo reveals right-to-left from 17% to 100% of the animation
    _logoReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.17, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Fixed seed for reproducible layout across rebuilds
    final rng = math.Random(42);
    _particles = [];
    for (final idx in _kSurahIndices) {
      double x, y;
      // Avoid the central zone [20%–80% wide, 25%–75% tall] where the logo sits
      do {
        x = rng.nextDouble() * 0.82;
        y = rng.nextDouble() * 0.82;
      } while (x > 0.18 && x < 0.78 && y > 0.23 && y < 0.73);

      _particles.add(_ParticleConfig(
        surahIndex: idx,
        x: x,
        y: y,
        size:    40.0 + rng.nextDouble() * 50.0,   // 40–90 px
        opacity: 0.10 + rng.nextDouble() * 0.12,   // 0.10–0.22
        delayMs: rng.nextInt(2000),                 // 0–2 000 ms
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
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _kBgEdge,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — radial gradient background (static)
          const _SplashBackground(),

          // Layer 2 — floating surah names
          for (final p in _particles)
            Positioned(
              left: p.x * size.width,
              top:  p.y * size.height,
              child: _FloatingSurahName(config: p),
            ),

          // Layer 3 — central logo with fill-reveal
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => FadeTransition(
                opacity: _logoFade,
                child: ClipRect(
                  clipper: _RevealClipper(_logoReveal.value),
                  child: SvgPicture.asset(
                    'assets/images/navbar/Quran_Kareem.svg',
                    width: size.width * 0.70,
                    colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn),
                  ),
                ),
              ),
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

// ── Reveal clipper (right → left, natural Arabic direction) ──────────────────

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

// ── Floating surah name ───────────────────────────────────────────────────────

class _FloatingSurahName extends StatefulWidget {
  final _ParticleConfig config;

  const _FloatingSurahName({required this.config});

  @override
  State<_FloatingSurahName> createState() => _FloatingSurahNameState();
}

class _FloatingSurahNameState extends State<_FloatingSurahName>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();

    final rng = math.Random(widget.config.surahIndex * 17 + widget.config.delayMs);
    final durationMs = 1600 + rng.nextInt(800); // 1 600–2 400 ms per cycle

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

    // Start with the configured initial delay, then loop indefinitely
    Future.delayed(Duration(milliseconds: widget.config.delayMs), _startLoop);
  }

  void _startLoop() {
    if (!mounted) return;
    _anim.forward().then((_) => _scheduleNext());
  }

  void _scheduleNext() {
    if (!mounted) return;
    _anim.reset();
    // Vary the pause between cycles so particles don't pulse in sync
    final rng = math.Random(
      widget.config.surahIndex + DateTime.now().millisecondsSinceEpoch % 10000,
    );
    final pauseMs = 300 + rng.nextInt(900); // 300–1 200 ms pause
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
        child: SvgPicture.asset(
          'assets/images/Translated_Quran/surah_svg/${widget.config.surahIndex}.svg',
          height: widget.config.size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}
