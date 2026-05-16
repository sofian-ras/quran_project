import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/arabic_models.dart';

// ─── Palette ──────────────────────────────────────────────────────────────

const _kBgDark = Color(0xFF0B1223);
const _kGold = Color(0xFFC8A97E);
const _kGreen = Color(0xFF52B788);

// ─── Screen ────────────────────────────────────────────────────────────────

class ArabicLessonCompleteScreen extends StatefulWidget {
  final ArabicLesson lesson;
  final int correctCount;
  final int totalCount;
  final int xpEarned;
  final int score;

  const ArabicLessonCompleteScreen({
    super.key,
    required this.lesson,
    required this.correctCount,
    required this.totalCount,
    required this.xpEarned,
    required this.score,
  });

  @override
  State<ArabicLessonCompleteScreen> createState() => _ArabicLessonCompleteScreenState();
}

class _ArabicLessonCompleteScreenState extends State<ArabicLessonCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _particleCtrl;
  late AnimationController _entranceCtrl;
  late Animation<double> _starScale;
  late Animation<double> _xpSlide;
  late Animation<double> _xpFade;

  @override
  void initState() {
    super.initState();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _starScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _xpSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _xpFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  int get _stars {
    if (widget.score >= 85) return 3;
    if (widget.score >= 60) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBgDark : const Color(0xFFF0EDE6),
      body: Stack(
        children: [
          // Particle animation in background
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(progress: _particleCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Stars
                  ScaleTransition(
                    scale: _starScale,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final filled = i < _stars;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            size: i == 1 ? 56 : 44,
                            color: filled ? const Color(0xFFFFD700) : Colors.grey.withAlpha(80),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Title
                  Text(
                    _stars == 3 ? 'Parfait ! 🎉' : _stars == 2 ? 'Très bien ! 👏' : 'Continue ! 💪',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFD4C5A3) : const Color(0xFF4A3F30),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.lesson.titleFr,
                    style: const TextStyle(color: _kGold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Score card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGold.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ScoreStat(label: 'Score', value: '${widget.score}%', color: _kGreen),
                        _ScoreStat(
                          label: 'Bonnes\nrép.',
                          value: '${widget.correctCount}/${widget.totalCount}',
                          color: _kGold,
                        ),
                        AnimatedBuilder(
                          animation: _entranceCtrl,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(0, _xpSlide.value),
                            child: Opacity(
                              opacity: _xpFade.value.clamp(0.0, 1.0),
                              child: _ScoreStat(
                                label: 'XP gagnés',
                                value: '+${widget.xpEarned}',
                                color: const Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Pop back to home screen (lesson complete pops all the way)
                        Navigator.pop(context, {'completed': true});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Continuer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ScoreStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9FA8B0), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Particle painter ─────────────────────────────────────────────────────

class _Particle {
  final double x, y, size, speed, angle;
  final Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  static final _rng = math.Random(42);
  static final List<_Particle> _particles = List.generate(60, (_) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC8A97E),
      const Color(0xFF52B788),
      const Color(0xFFE53935),
      Colors.white,
    ];
    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 4 + _rng.nextDouble() * 6,
      speed: 0.2 + _rng.nextDouble() * 0.5,
      angle: _rng.nextDouble() * math.pi * 2,
      color: colors[_rng.nextInt(colors.length)],
    );
  });

  const _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress * p.speed + p.x) % 1.0;
      final opacity = t < 0.2 ? t / 0.2 : t > 0.8 ? (1 - t) / 0.2 : 1.0;
      final paint = Paint()
        ..color = p.color.withAlpha((opacity * 200).round())
        ..style = PaintingStyle.fill;

      final x = p.x * size.width + math.sin(progress * math.pi * 2 + p.angle) * 30;
      final y = ((p.y + progress * p.speed) % 1.0) * size.height;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
