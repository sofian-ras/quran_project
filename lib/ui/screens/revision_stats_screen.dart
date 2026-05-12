import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/revision_entry.dart';
import '../../services/revision_service.dart';
import '../../services/revision_stats_service.dart';
import '../../theme/app_theme.dart';
import 'revision_palette.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Screen
// ════════════════════════════════════════════════════════════════════════════

class RevisionStatsScreen extends StatefulWidget {
  final RevisionPalette palette;
  const RevisionStatsScreen({super.key, required this.palette});

  @override
  State<RevisionStatsScreen> createState() => _RevisionStatsScreenState();
}

class _RevisionStatsScreenState extends State<RevisionStatsScreen>
    with TickerProviderStateMixin {
  RevisionStats?         _stats;
  List<RevisionEntry>    _entries = [];
  bool                   _loading = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _anim;

  RevisionPalette get _p => widget.palette;
  Color           get _a => _p.accent;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await RevisionService.instance.getAll();
    final stats   = await RevisionStatsService.instance.getStats(allEntries: entries);
    if (mounted) {
      setState(() { _stats = stats; _entries = entries; _loading = false; });
      _animCtrl.forward();
    }
  }

  Future<void> _showGoalPicker() async {
    if (_stats == null) return;
    int draft = _stats!.dailyGoal;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _p.bgBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RevisionThemeScope(
        palette: widget.palette,
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Objectif quotidien',
                  style: TextStyle(color: _p.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$draft versets / jour',
                      style: TextStyle(color: _a, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: _a,
                    inactiveTrackColor: _p.cardBorder,
                    thumbColor: _a,
                    overlayColor: _a.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: draft.toDouble(),
                    min: 5,
                    max: 200,
                    divisions: 39,
                    onChanged: (v) => setS(() => draft = v.round()),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await RevisionStatsService.instance.setDailyGoal(draft);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _a,
                      foregroundColor: _p.buttonFg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RevisionThemeScope(
      palette: widget.palette,
      child: Scaffold(
        body: _GradientBg(
          child: SafeArea(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _a))
                : _buildContent(_stats!),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(RevisionStats s) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back_rounded, color: _p.iconMuted),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _p.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _p.cardBorder),
                  ),
                  child: Text(
                    '🔥 ${s.streak} jour${s.streak > 1 ? 's' : ''}',
                    style: TextStyle(color: _p.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 12),

            // ── Objectif du jour ──────────────────────────────────────────
            _GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: s.goalProgress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: v,
                              strokeWidth: 8,
                              backgroundColor: _p.cardBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                s.goalMet ? AppColors.success : _a,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.todayAyahs}',
                              style: TextStyle(
                                color: s.goalMet ? AppColors.success : _p.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '/${s.dailyGoal}',
                              style: TextStyle(color: _p.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Objectif du jour',
                              style: TextStyle(color: _p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            if (s.goalMet) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Atteint ✓',
                                  style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: s.goalProgress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 5,
                              backgroundColor: _p.cardBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                s.goalMet ? AppColors.success : _a,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!s.goalMet)
                          Text(
                            '${s.dailyGoal - s.todayAyahs} verset${s.dailyGoal - s.todayAyahs > 1 ? 's' : ''} restant${s.dailyGoal - s.todayAyahs > 1 ? 's' : ''}',
                            style: TextStyle(color: _a, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showGoalPicker,
                          child: Text(
                            'Modifier l\'objectif →',
                            style: TextStyle(color: _a, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Activité 7 jours ──────────────────────────────────────────
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activité — 7 derniers jours',
                    style: TextStyle(color: _p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: _AnimatedWeekChart(days: s.last7Days),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Maîtrise globale ──────────────────────────────────────────
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Maîtrise globale',
                        style: TextStyle(color: _p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: s.masteryPercent),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => Text(
                          '${(v * 100).round()}%',
                          style: TextStyle(color: _a, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: s.masteryPercent),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: _p.cardBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(_a),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.totalTracked} sourate${s.totalTracked > 1 ? 's' : ''} suivie${s.totalTracked > 1 ? 's' : ''}',
                    style: TextStyle(color: _p.textHint, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatusChip(color: AppColors.success, label: 'Maîtrisées', count: s.masteredCount),
                      const SizedBox(width: 8),
                      _StatusChip(color: AppColors.warning, label: 'En cours',   count: s.learningCount),
                      const SizedBox(width: 8),
                      _StatusChip(color: AppColors.error,   label: 'À revoir',   count: s.lapsedCount),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tout temps ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Sessions',        value: '${s.allTimeSessions}')),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Versets révisés', value: '${s.allTimeAyahs}')),
              ],
            ),
            const SizedBox(height: 14),

            // ── Cercle de Mémoire ─────────────────────────────────────────
            if (_entries.isNotEmpty) ...[
              _GlassCard(
                child: _MemoireCircle(
                  entries: _entries,
                  stats: s,
                  animation: _anim,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Bilan Intelligent ─────────────────────────────────────────
            _GlassCard(
              child: _BilanIntelligent(
                entries: _entries,
                stats: s,
                palette: _p,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Animated week chart ───────────────────────────────────────────────────────

class _AnimatedWeekChart extends StatefulWidget {
  final List<DayEntry> days;
  const _AnimatedWeekChart({required this.days});

  @override
  State<_AnimatedWeekChart> createState() => _AnimatedWeekChartState();
}

class _AnimatedWeekChartState extends State<_AnimatedWeekChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  static const _barMaxH  = 64.0;
  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p        = RevisionThemeScope.of(context);
    final maxAyahs = widget.days.fold(0, (m, d) => max(m, d.ayahs));
    final todayStr = _dateStr(DateTime.now());

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widget.days.map((d) {
          final isToday  = _dateStr(d.date) == todayStr;
          final frac     = maxAyahs == 0 ? 0.0 : d.ayahs / maxAyahs;
          final targetH  = d.ayahs == 0 ? 4.0 : max(8.0, frac * _barMaxH);
          final barH     = targetH * _anim.value;
          final dayLabel = _dayLabels[d.date.weekday - 1];

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isToday && d.ayahs > 0)
                  Text(
                    '${d.ayahs}',
                    style: TextStyle(fontSize: 9, color: p.accent, fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 2),
                Container(
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: isToday ? 1.0 : (d.ayahs == 0 ? 0.15 : 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday ? p.accent : p.textHint,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cercle de Mémoire ─────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'review':   return const Color(0xFF4CAF50);
    case 'learning': return const Color(0xFFFF9800);
    case 'lapsed':   return const Color(0xFFF44336);
    default:         return const Color(0xFF9E9E9E);
  }
}

class _MemoireCircle extends StatelessWidget {
  final List<RevisionEntry> entries;
  final RevisionStats       stats;
  final Animation<double>   animation;
  const _MemoireCircle({required this.entries, required this.stats, required this.animation});

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cercle de Mémoire',
          style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          'Chaque arc = une sourate · taille proportionnelle aux versets',
          style: TextStyle(color: p.textHint, fontSize: 11),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => SizedBox(
            width: double.infinity,
            height: 210,
            child: CustomPaint(
              painter: _MemoireCirclePainter(
                entries:        entries,
                palette:        p,
                progress:       animation.value,
                masteryPercent: stats.masteryPercent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: Color(0xFF4CAF50), label: 'Maîtrisée'),
            _LegendDot(color: Color(0xFFFF9800), label: 'En cours'),
            _LegendDot(color: Color(0xFFF44336), label: 'Oubliée'),
            _LegendDot(color: Color(0xFF9E9E9E), label: 'Nouvelle'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: p.textHint, fontSize: 11)),
      ],
    );
  }
}

class _MemoireCirclePainter extends CustomPainter {
  final List<RevisionEntry> entries;
  final RevisionPalette     palette;
  final double              progress;
  final double              masteryPercent;

  const _MemoireCirclePainter({
    required this.entries,
    required this.palette,
    required this.progress,
    required this.masteryPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r      = min(size.width, size.height) / 2 - 16;

    final valid  = entries.where((e) => e.ayahCount > 0).toList();
    final total  = valid.fold(0, (s, e) => s + e.ayahCount);
    if (total == 0) return;

    // Background track
    canvas.drawCircle(
      center, r,
      Paint()
        ..color = palette.cardBorder.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18,
    );

    final now   = DateTime.now();
    double angle = -pi / 2;

    for (final entry in valid) {
      final fullSweep = (entry.ayahCount / total) * 2 * pi;
      final sweep     = fullSweep * progress;
      final color     = _statusColor(entry.status);
      final isOverdue = entry.status == 'lapsed' &&
                        entry.nextReview != null &&
                        entry.nextReview!.isBefore(now);

      if (isOverdue && progress > 0.5) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          angle,
          max(0.0, sweep - 0.04),
          false,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 30
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        angle,
        max(0.0, sweep - 0.06),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );

      angle += fullSweep;
    }

    // Centre — % maîtrise animé
    final pctStr = '${(masteryPercent * 100 * progress).round()}%';
    final pctTp  = TextPainter(
      text: TextSpan(
        text: pctStr,
        style: TextStyle(
          color: palette.accent,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelTp = TextPainter(
      text: TextSpan(
        text: 'maîtrise',
        style: TextStyle(color: palette.textHint, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    pctTp.paint(canvas,
        Offset(center.dx - pctTp.width / 2, center.dy - pctTp.height - 2));
    labelTp.paint(canvas,
        Offset(center.dx - labelTp.width / 2, center.dy + 4));
  }

  @override
  bool shouldRepaint(_MemoireCirclePainter old) =>
      old.progress != progress || old.masteryPercent != masteryPercent;
}

// ── Bilan Intelligent ─────────────────────────────────────────────────────────

class _BilanIntelligent extends StatefulWidget {
  final List<RevisionEntry> entries;
  final RevisionStats       stats;
  final RevisionPalette     palette;
  const _BilanIntelligent({required this.entries, required this.stats, required this.palette});

  @override
  State<_BilanIntelligent> createState() => _BilanIntelligentState();
}

class _BilanIntelligentState extends State<_BilanIntelligent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _pulseAnim;

  RevisionPalette get _p => widget.palette;

  List<RevisionEntry> get _overdue {
    final now = DateTime.now();
    return widget.entries
        .where((e) =>
            e.status == 'lapsed' &&
            e.nextReview != null &&
            e.nextReview!.isBefore(now))
        .toList()
      ..sort((a, b) => a.nextReview!.compareTo(b.nextReview!));
  }

  List<RevisionEntry> get _upcoming {
    final now = DateTime.now();
    return widget.entries
        .where((e) =>
            e.status != 'lapsed' &&
            e.nextReview != null &&
            e.nextReview!.isAfter(now))
        .toList()
      ..sort((a, b) => a.nextReview!.compareTo(b.nextReview!));
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (_overdue.isNotEmpty) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  String _conseil() {
    final od = _overdue;
    if (od.isNotEmpty) {
      final days = max(1, DateTime.now().difference(od.first.nextReview!).inDays);
      return '⚠️ ${od.first.surahName} est en retard de $days jour${days > 1 ? 's' : ''}. Commence par là.';
    }
    if (widget.stats.streak == 0)  return '💤 Lance une session courte pour relancer ta série.';
    if (widget.stats.goalMet)      return '🎯 Objectif atteint ! Profite de l\'élan pour avancer.';
    final remain = widget.stats.dailyGoal - widget.stats.todayAyahs;
    return '📖 Plus que $remain verset${remain > 1 ? 's' : ''} pour atteindre ton objectif du jour.';
  }

  ({String label, Color color}) _tendance() {
    final days = widget.stats.last7Days;
    if (days.length < 7) return (label: '→ stable', color: const Color(0xFF9E9E9E));
    final recent = days.sublist(4).fold(0, (s, d) => s + d.ayahs);
    final older  = days.sublist(0, 3).fold(0, (s, d) => s + d.ayahs);
    if (older == 0 && recent == 0) return (label: '→ stable',   color: const Color(0xFF9E9E9E));
    if (older == 0)                return (label: '↑ en hausse', color: const Color(0xFF4CAF50));
    final pct = ((recent - older) / older * 100).round();
    if (pct >  10) return (label: '↑ +$pct%', color: const Color(0xFF4CAF50));
    if (pct < -10) return (label: '↓ $pct%',  color: const Color(0xFFF44336));
    return (label: '→ stable', color: const Color(0xFF9E9E9E));
  }

  String _relativeDate(DateTime d) {
    final days = d.difference(DateTime.now()).inDays;
    if (days == 0) return 'aujourd\'hui';
    if (days == 1) return 'demain';
    return 'dans $days jours';
  }

  @override
  Widget build(BuildContext context) {
    final overdue  = _overdue;
    final upcoming = _upcoming.take(3).toList();
    final tendance = _tendance();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Bilan Intelligent',
              style: TextStyle(color: _p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tendance.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tendance.label,
                style: TextStyle(color: tendance.color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Conseil du jour ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _p.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _p.accent.withValues(alpha: 0.2)),
          ),
          child: Text(
            _conseil(),
            style: TextStyle(color: _p.textPrimary, fontSize: 13, height: 1.5),
          ),
        ),

        // ── Manquements ─────────────────────────────────────────────────
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnim.value,
                  child: const Text('🔴', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Manquements (${overdue.length})',
                style: const TextStyle(
                  color: Color(0xFFF44336),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...overdue.map((e) {
            final daysLate = max(1, DateTime.now().difference(e.nextReview!).inDays);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  const Text('·  ', style: TextStyle(color: Color(0xFFF44336), fontSize: 16)),
                  Expanded(
                    child: Text(
                      e.surahName,
                      style: TextStyle(color: _p.textPrimary, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44336).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+$daysLate j',
                      style: const TextStyle(
                        color: Color(0xFFF44336),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // ── Prochaines révisions ─────────────────────────────────────────
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Prochaines révisions',
            style: TextStyle(color: _p.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...upcoming.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Text('📅  ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    e.surahName,
                    style: TextStyle(color: _p.textPrimary, fontSize: 13),
                  ),
                ),
                Text(
                  _relativeDate(e.nextReview!),
                  style: TextStyle(
                    color: _p.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],

        if (overdue.isEmpty && upcoming.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Aucun manquement ni révision planifiée.',
            style: TextStyle(color: _p.textHint, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ── Background ────────────────────────────────────────────────────────────────

class _GradientBg extends StatelessWidget {
  final Widget child;
  const _GradientBg({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: p.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color  color;
  final String label;
  final int    count;
  const _StatusChip({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,  style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: p.accent, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: p.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
