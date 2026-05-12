import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'bottom_nav_shell.dart';

const _kBeige = Color(0xFFF2ECE5);
const _kGold  = Color(0xFFD4AF77);

const _kAppName  = 'Quran App';
const _kLogoPath = 'assets/icon/logo_app_v6.png';
const _kLogoSize = 56.0;
const _kGap      = 14.0;
const _kTextStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w600,
  color: _kGold,
  letterSpacing: 2.0,
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _logoFade;
  late final Animation<double>   _slide;
  late final Animation<double>   _textFade;

  // Largeur du texte mesurée une seule fois
  final double _textWidth = _measureText();

  static double _measureText() {
    final tp = TextPainter(
      text: const TextSpan(text: _kAppName, style: _kTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Phase 1 : logo apparaît au centre
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Phase 2 : le bloc Row glisse de "logo centré" vers "logo+nom centré"
    _slide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Phase 2 : nom fade-in
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.72, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 700), _navigate);
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
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Décalage initial : le Row est poussé à droite pour que le logo soit centré.
    // À la fin de l'animation il revient à 0 → tout le bloc est centré.
    final initialOffset = (_textWidth + _kGap) / 2;

    return Scaffold(
      backgroundColor: _kBeige,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final offset = initialOffset * (1.0 - _slide.value);
            return Transform.translate(
              offset: Offset(-offset, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: Image.asset(
                      _kLogoPath,
                      width:  _kLogoSize,
                      height: _kLogoSize,
                    ),
                  ),
                  const SizedBox(width: _kGap),
                  Opacity(
                    opacity: _textFade.value,
                    child: const Text(_kAppName, style: _kTextStyle),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
