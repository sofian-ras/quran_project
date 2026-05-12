import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bottom_nav_shell.dart';

const _kBeige = Color(0xFFF2ECE5);
const _kGold  = Color(0xFFD4AF77);

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
  final double angle;     // direction en radians (0–2π)
  final double distance;  // distance depuis le centre en px
  final double fontSize;  // taille du texte
  final double opacity;   // opacité max 0.10–0.28
  final int    delayMs;   // délai initial avant apparition

  const _ParticleConfig({
    required this.surahIndex,
    required this.angle,
    required this.distance,
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
  late final AnimationController   _ctrl;
  late final Animation<double>     _logoFade;
  late final Animation<double>     _logoSlide;
  late final Animation<double>     _textSlide;
  late final Animation<double>     _textFade;
  late final List<_ParticleConfig> _particles;

  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.33, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.33, 1.0, curve: Curves.easeInOut),
      ),
    );

    _textSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.33, 1.0, curve: Curves.easeInOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.33, 0.65, curve: Curves.easeOut),
      ),
    );

    final rng        = math.Random(42);
    _particles       = [];
    // Garder seulement 8 particules pour alléger le rendu
    const pickedKeys = [1, 18, 36, 55, 67, 78, 112, 114];

    for (int i = 0; i < pickedKeys.length; i++) {
      // Angles répartis uniformément sur 360°, avec légère variation aléatoire
      final baseAngle = (i / pickedKeys.length) * 2 * math.pi;
      final angle     = baseAngle + (rng.nextDouble() - 0.5) * 0.5;

      _particles.add(_ParticleConfig(
        surahIndex: pickedKeys[i],
        angle:      angle,
        distance:   100.0 + rng.nextDouble() * 140.0, // 100–240 px
        fontSize:   12.0  + rng.nextDouble() * 8.0,   // 12–20 px
        opacity:    0.07  + rng.nextDouble() * 0.08,  // 0.07–0.15
        delayMs:    rng.nextInt(1600),                 // 0–1 600 ms
      ));
    }

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), _navigate);
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
        transitionDuration: const Duration(milliseconds: 300),
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
    final logoWidth = size.width * 0.50;

    return Scaffold(
      backgroundColor: _kBeige,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — fond radial gradient
          const _SplashBackground(),

          // Layer 2 — noms de sourates qui partent du centre vers l'extérieur
          for (final p in _particles)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: _FloatingSurahText(config: p),
              ),
            ),

          // Layer 3 — halo + logo + titre animés
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingHalo(logoWidth: logoWidth),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final logoOffset = -_logoSlide.value * logoWidth * 0.35;
                    final textOffset =  logoWidth * 0.55 * (1.0 - _textSlide.value) + logoWidth * 0.30;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // "Quran App" sort de derrière le logo vers la droite
                        Transform.translate(
                          offset: Offset(textOffset, 0),
                          child: Opacity(
                            opacity: _textFade.value,
                            child: const Text(
                              'Quran App',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: _kGold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        // Logo glisse vers la gauche
                        Transform.translate(
                          offset: Offset(logoOffset, 0),
                          child: FadeTransition(
                            opacity: _logoFade,
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
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Layer 4 — bismillah en haut
          const Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 32),
                child: _BismillahTypewriter(startDelayMs: 400),
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
      decoration: BoxDecoration(color: _kBeige),
      child: SizedBox.expand(),
    );
  }
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
          ),
        ),
      ),
    );
  }
}

// ── Bismillah typewriter + pulse ──────────────────────────────────────────────

class _BismillahTypewriter extends StatefulWidget {
  final int startDelayMs;
  const _BismillahTypewriter({required this.startDelayMs});

  @override
  State<_BismillahTypewriter> createState() => _BismillahTypewriterState();
}

class _BismillahTypewriterState extends State<_BismillahTypewriter>
    with TickerProviderStateMixin {
  static const _text = 'بسم الله الرحمن الرحيم';

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.startDelayMs), _start);
  }

  void _start() {
    if (!mounted) return;
    _fadeCtrl.forward();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) { t.cancel(); return; }
      final total = _text.characters.length;
      if (_charCount >= total) {
        t.cancel();
        // Démarre le pulse une fois l'écriture terminée
        _pulseCtrl.repeat(reverse: true);
        return;
      }
      setState(() => _charCount++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _text.characters.take(_charCount).string;

    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Opacity(
          opacity: _pulseCtrl.isAnimating ? _pulseAnim.value : 0.85,
          child: Text(
            displayed,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'UthmanTahaNaskh',
              fontSize: 26,
              color: _kGold.withValues(alpha: 1.0),
              height: 1.4,
              shadows: [
                Shadow(color: _kGold.withValues(alpha: 0.9),          blurRadius: 12),
                Shadow(color: _kGold.withValues(alpha: 0.5),          blurRadius: 28),
                Shadow(color: Colors.white.withValues(alpha: 0.25),   blurRadius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Noms de sourates — partent du centre vers l'extérieur ────────────────────

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
  late final Animation<double>   _move;   // 0.0 → 1.0 (centre → destination)

  @override
  void initState() {
    super.initState();

    final rng         = math.Random(widget.config.surahIndex * 17 + widget.config.delayMs);
    final durationMs  = 1800 + rng.nextInt(800); // 1 800–2 600 ms par cycle

    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Opacité : apparaît → reste visible → disparaît
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: widget.config.opacity), weight: 20),
      TweenSequenceItem(tween: ConstantTween(widget.config.opacity),           weight: 55),
      TweenSequenceItem(tween: Tween(begin: widget.config.opacity, end: 0.0),  weight: 25),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.linear));

    // Mouvement : part vite du centre, décélère (easeOut)
    _move = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.config.delayMs), _startLoop);
  }

  void _startLoop() {
    if (!mounted) return;
    _anim.forward().then((_) => _scheduleNext());
  }

  void _scheduleNext() {
    if (!mounted) return;
    _anim.reset();
    final rng      = math.Random(
      widget.config.surahIndex + DateTime.now().millisecondsSinceEpoch % 10000,
    );
    final pauseMs  = 400 + rng.nextInt(1000);
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
      builder: (_, __) {
        final progress = _move.value;
        final dx = math.cos(widget.config.angle) * widget.config.distance * progress;
        final dy = math.sin(widget.config.angle) * widget.config.distance * progress;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              _kSurahNames[widget.config.surahIndex]!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: widget.config.fontSize,
                color: _kGold,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        );
      },
    );
  }
}
