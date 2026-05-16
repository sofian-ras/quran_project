import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/arabic_curriculum.dart';
import '../../models/arabic_models.dart';
import '../../services/arabic_learning_service.dart';
import 'arabic_lesson_screen.dart';
import 'arabic_badges_screen.dart';
import 'arabic_letter_detail_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────

const _kBgDark = Color(0xFF0B1223);
const _kBgLight = Color(0xFFF0EDE6);
const _kGoldStart = Color(0xFF8B6C35);
const _kGoldMid = Color(0xFFBFA878);
const _kGoldPale = Color(0xFFD4C5A3);
const _kGoldEnd = Color(0xFF8B6C35);
const _kGreen = Color(0xFF52B788);
const _kGreenDark = Color(0xFF2D6A4F);
const _kHeartRed = Color(0xFFE53935);
const _kFireOrange = Color(0xFFFF6D00);
const _kLocked = Color(0xFF9E9E9E);

// ─── Screen ────────────────────────────────────────────────────────────────

class ArabicHomeScreen extends StatefulWidget {
  const ArabicHomeScreen({super.key});

  @override
  State<ArabicHomeScreen> createState() => _ArabicHomeScreenState();
}

class _ArabicHomeScreenState extends State<ArabicHomeScreen>
    with TickerProviderStateMixin {
  final _service = ArabicLearningService.instance;
  ArabicStats? _stats;
  bool _loading = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stats = await _service.getStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  Future<void> _openLesson(ArabicLesson lesson) async {
    final stats = _stats!;
    final state = _service.lessonNodeState(lesson.id, stats);
    if (state == LessonNodeState.locked) {
      _showLockedSnack();
      return;
    }

    final prevBadgeIds = Set<String>.from(stats.unlockedBadgeIds);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ArabicLessonScreen(lesson: lesson, stats: stats),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

    if (result != null && mounted) {
      _load().then((_) async {
        if (!mounted) return;
        final newBadges = await _service.getNewlyUnlockedBadges(prevBadgeIds);
        for (final badgeId in newBadges) {
          final badge = kArabicBadges.firstWhere((b) => b.id == badgeId, orElse: () => kArabicBadges.first);
          if (mounted) _showBadgeDialog(badge);
        }
      });
    }
  }

  void _showLockedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Complète la leçon précédente pour débloquer celle-ci'),
        backgroundColor: const Color(0xFF1C2333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showBadgeDialog(ArabicBadge badge) {
    showDialog(
      context: context,
      builder: (_) => _BadgeUnlockDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kBgDark : _kBgLight;

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _ArabicSliverHeader(
                  stats: _stats!,
                  isDark: isDark,
                  onBadgesTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ArabicBadgesScreen(stats: _stats!))),
                ),
                SliverToBoxAdapter(
                  child: _StatsBar(stats: _stats!, isDark: isDark),
                ),
                for (int unitIdx = 0; unitIdx < kArabicCurriculum.length; unitIdx++)
                  ..._buildUnitSliver(unitIdx, isDark),
                SliverToBoxAdapter(
                  child: SizedBox(height: 80 + MediaQuery.of(context).padding.bottom),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildUnitSliver(int unitIdx, bool isDark) {
    final unit = kArabicCurriculum[unitIdx];
    final stats = _stats!;

    return [
      SliverToBoxAdapter(
        child: _UnitHeader(unit: unit, isDark: isDark),
      ),
      SliverToBoxAdapter(
        child: _LessonPathMap(
          unit: unit,
          stats: stats,
          isDark: isDark,
          pulseAnim: _pulseAnim,
          onLessonTap: _openLesson,
          onLessonLongPress: (lesson) {
            // Show letter detail if first letter group lesson
            final ex = lesson.exercises.isNotEmpty ? lesson.exercises.first : null;
            if (ex?.type == ExerciseType.letterIntro) {
              final letter = ex!.data['letter'] as ArabicLetter?;
              if (letter != null) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ArabicLetterDetailScreen(letter: letter)));
              }
            }
          },
        ),
      ),
    ];
  }
}

// ─── Sliver header ────────────────────────────────────────────────────────

class _ArabicSliverHeader extends StatelessWidget {
  final ArabicStats stats;
  final bool isDark;
  final VoidCallback onBadgesTap;

  const _ArabicSliverHeader({
    required this.stats,
    required this.isDark,
    required this.onBadgesTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF8B6C35),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD4C5A3)),
          onPressed: onBadgesTap,
          tooltip: 'Mes badges',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _HeaderBackground(stats: stats),
        titlePadding: EdgeInsets.zero,
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  final ArabicStats stats;
  const _HeaderBackground({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoldenHeaderPainter(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              const Text(
                'تعلم العربية',
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 32,
                  color: Color(0xFFEDE0C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Apprendre l\'Arabe',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFBFA878),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // XP bar
              _XpBar(stats: stats),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final ArabicStats stats;
  const _XpBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final progress = stats.xpInCurrentLevel / stats.xpNeededForNextLevel;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Niveau ${stats.level}',
                style: const TextStyle(color: Color(0xFFD4C5A3), fontSize: 12)),
            Text('${stats.totalXp} XP',
                style: const TextStyle(color: Color(0xFFD4C5A3), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFF4A3010),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF52B788)),
          ),
        ),
      ],
    );
  }
}

// ─── Stats bar (streak + hearts) ─────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final ArabicStats stats;
  final bool isDark;
  const _StatsBar({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8A97E).withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            emoji: '🔥',
            label: 'Streak',
            value: '${stats.currentStreak}j',
            color: _kFireOrange,
          ),
          Container(width: 1, height: 32, color: const Color(0xFFC8A97E).withAlpha(60)),
          _HeartsDisplay(hearts: stats.hearts, minutesLeft: stats.minutesUntilNextHeart()),
          Container(width: 1, height: 32, color: const Color(0xFFC8A97E).withAlpha(60)),
          _StatItem(
            emoji: '💎',
            label: 'XP Total',
            value: '${stats.totalXp}',
            color: const Color(0xFFD4AF77),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatItem({required this.emoji, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: color.withAlpha(180), fontSize: 11)),
      ],
    );
  }
}

class _HeartsDisplay extends StatelessWidget {
  final int hearts;
  final int minutesLeft;
  const _HeartsDisplay({required this.hearts, required this.minutesLeft});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(5, (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              i < hearts ? '❤️' : '🖤',
              style: const TextStyle(fontSize: 14),
            ),
          )),
        ),
        const SizedBox(height: 2),
        if (minutesLeft > 0)
          Text('+1 dans ${minutesLeft}min',
              style: const TextStyle(color: _kHeartRed, fontSize: 10))
        else
          const Text('Vies', style: TextStyle(color: _kHeartRed, fontSize: 11)),
      ],
    );
  }
}

// ─── Unit header ──────────────────────────────────────────────────────────

class _UnitHeader extends StatelessWidget {
  final ArabicUnit unit;
  final bool isDark;
  const _UnitHeader({required this.unit, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            unit.accentColor.withAlpha(isDark ? 60 : 30),
            unit.accentColor.withAlpha(isDark ? 30 : 15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unit.accentColor.withAlpha(100)),
      ),
      child: Row(
        children: [
          Text(unit.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.titleFr.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: unit.accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  unit.titleAr,
                  style: TextStyle(
                    fontFamily: 'ScheherazadeNew',
                    fontSize: 18,
                    color: isDark ? const Color(0xFFD4C5A3) : const Color(0xFF4A3F30),
                  ),
                ),
                Text(
                  unit.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withAlpha(150)
                        : Colors.black.withAlpha(120),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lesson path map ──────────────────────────────────────────────────────

class _LessonPathMap extends StatelessWidget {
  final ArabicUnit unit;
  final ArabicStats stats;
  final bool isDark;
  final Animation<double> pulseAnim;
  final void Function(ArabicLesson) onLessonTap;
  final void Function(ArabicLesson) onLessonLongPress;

  const _LessonPathMap({
    required this.unit,
    required this.stats,
    required this.isDark,
    required this.pulseAnim,
    required this.onLessonTap,
    required this.onLessonLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final lessons = unit.lessons;
    final nodeSize = 68.0;
    final rowH = nodeSize + 32;
    final totalH = lessons.length * rowH + 20.0;

    return SizedBox(
      height: totalH,
      child: CustomPaint(
        painter: _PathPainter(
          lessonCount: lessons.length,
          rowHeight: rowH,
          nodeSize: nodeSize,
          isDark: isDark,
          accentColor: unit.accentColor,
          completedCount: lessons
              .where((l) => stats.completedLessons.contains(l.id))
              .length,
        ),
        child: Stack(
          children: [
            for (int i = 0; i < lessons.length; i++)
              _positionedNode(
                context,
                index: i,
                lesson: lessons[i],
                rowHeight: rowH,
                nodeSize: nodeSize,
                totalWidth: MediaQuery.of(context).size.width,
              ),
          ],
        ),
      ),
    );
  }

  Positioned _positionedNode(
    BuildContext context, {
    required int index,
    required ArabicLesson lesson,
    required double rowHeight,
    required double nodeSize,
    required double totalWidth,
  }) {
    final nodeState = _nodeStateFor(lesson.id);
    final xOffset = _xOffsetFor(index, totalWidth, nodeSize);
    final top = index * rowHeight + 10;

    return Positioned(
      left: xOffset,
      top: top,
      child: GestureDetector(
        onTap: () => onLessonTap(lesson),
        onLongPress: () => onLessonLongPress(lesson),
        child: nodeState == LessonNodeState.current
            ? AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Transform.scale(scale: pulseAnim.value, child: child),
                child: _LessonNode(
                  lesson: lesson,
                  state: nodeState,
                  size: nodeSize,
                  accentColor: unit.accentColor,
                  isDark: isDark,
                  index: index,
                ),
              )
            : _LessonNode(
                lesson: lesson,
                state: nodeState,
                size: nodeSize,
                accentColor: unit.accentColor,
                isDark: isDark,
                index: index,
              ),
      ),
    );
  }

  LessonNodeState _nodeStateFor(String lessonId) =>
      ArabicLearningService.instance.lessonNodeState(lessonId, stats);

  double _xOffsetFor(int index, double totalWidth, double nodeSize) {
    // Sinusoidal path — alternates left/center/right
    const positions = [0.15, 0.5, 0.75, 0.5, 0.15, 0.5, 0.75, 0.5, 0.15];
    final ratio = positions[index % positions.length];
    return totalWidth * ratio - nodeSize / 2;
  }
}

class _LessonNode extends StatelessWidget {
  final ArabicLesson lesson;
  final LessonNodeState state;
  final double size;
  final Color accentColor;
  final bool isDark;
  final int index;

  const _LessonNode({
    required this.lesson,
    required this.state,
    required this.size,
    required this.accentColor,
    required this.isDark,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = state == LessonNodeState.locked;
    final isCompleted = state == LessonNodeState.completed;

    Color bg;
    Color border;
    Color iconColor;

    if (isCompleted) {
      bg = _kGreen;
      border = _kGreenDark;
      iconColor = Colors.white;
    } else if (isLocked) {
      bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0CCCC);
      border = _kLocked;
      iconColor = _kLocked;
    } else {
      // Current
      bg = accentColor;
      border = accentColor;
      iconColor = Colors.white;
    }

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 3),
            boxShadow: isLocked
                ? null
                : [
                    BoxShadow(
                      color: bg.withAlpha(100),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Center(
            child: isLocked
                ? Icon(Icons.lock_rounded, color: iconColor, size: 26)
                : isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                    : lesson.isQuiz
                        ? Icon(Icons.quiz_rounded, color: iconColor, size: 28)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: Text(
            lesson.titleFr,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isLocked
                  ? _kLocked
                  : (isDark ? const Color(0xFFD4C5A3) : const Color(0xFF4A3F30)),
              fontWeight: isLocked ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Path CustomPainter ────────────────────────────────────────────────────

class _PathPainter extends CustomPainter {
  final int lessonCount;
  final double rowHeight;
  final double nodeSize;
  final bool isDark;
  final Color accentColor;
  final int completedCount;

  _PathPainter({
    required this.lessonCount,
    required this.rowHeight,
    required this.nodeSize,
    required this.isDark,
    required this.accentColor,
    required this.completedCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [0.15, 0.5, 0.75, 0.5, 0.15, 0.5, 0.75, 0.5, 0.15];

    final paintBg = Paint()
      ..color = isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(12)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFg = Paint()
      ..color = accentColor.withAlpha(180)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < lessonCount - 1; i++) {
      final x1 = size.width * positions[i % positions.length];
      final y1 = i * rowHeight + nodeSize / 2 + 10;
      final x2 = size.width * positions[(i + 1) % positions.length];
      final y2 = (i + 1) * rowHeight + nodeSize / 2 + 10;

      final path = Path();
      path.moveTo(x1, y1);
      final cpx = (x1 + x2) / 2;
      final cpy = (y1 + y2) / 2 - 15;
      path.quadraticBezierTo(cpx, cpy, x2, y2);

      canvas.drawPath(path, paintBg);
      if (i < completedCount) {
        canvas.drawPath(path, paintFg);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.completedCount != completedCount || old.isDark != isDark;
}

// ─── Golden header painter ────────────────────────────────────────────────

class _GoldenHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [_kGoldStart, _kGoldMid, _kGoldPale, _kGoldMid, _kGoldEnd],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Crosshatch fiber texture
    final fiber = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 20.0;
    for (double x = 0; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), fiber);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), fiber);
    }

    // Bottom border line
    final line = Paint()
      ..color = const Color(0xFF6B4F20).withAlpha(120)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), line);

    // Star ornaments in corners
    _drawStar(canvas, Offset(24, size.height - 24), 10, const Color(0xFFD4C5A3).withAlpha(100));
    _drawStar(canvas, Offset(size.width - 24, size.height - 24), 10, const Color(0xFFD4C5A3).withAlpha(100));
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    const n = 8;
    final path = Path();
    for (int i = 0; i < n * 2; i++) {
      final angle = i * math.pi / n - math.pi / 2;
      final radius = i.isEven ? r : r * 0.45;
      final pt = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GoldenHeaderPainter _) => false;
}

// ─── Badge unlock dialog ──────────────────────────────────────────────────

class _BadgeUnlockDialog extends StatelessWidget {
  final ArabicBadge badge;
  const _BadgeUnlockDialog({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C2333), Color(0xFF0B1223)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFC8A97E), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              'Badge débloqué !',
              style: TextStyle(
                color: Color(0xFFBFA878),
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.titleFr,
              style: const TextStyle(
                color: Color(0xFFEDE0C0),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: const TextStyle(color: Color(0xFF9FA8B0), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8A97E),
                foregroundColor: const Color(0xFF1C2333),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Super !', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
