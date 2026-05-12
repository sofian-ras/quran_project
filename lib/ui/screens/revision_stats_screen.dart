import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../../services/revision_service.dart';
import '../../services/revision_stats_service.dart';
import '../../theme/app_theme.dart';
import 'revision_palette.dart';

class RevisionStatsScreen extends StatefulWidget {
  final RevisionPalette palette;
  const RevisionStatsScreen({super.key, required this.palette});

  @override
  State<RevisionStatsScreen> createState() => _RevisionStatsScreenState();
}

class _RevisionStatsScreenState extends State<RevisionStatsScreen> {
  RevisionStats? _stats;
  bool _loading = true;

  RevisionPalette get _p => widget.palette;
  Color get _a => _p.accent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await RevisionService.instance.getAll();
    final stats   = await RevisionStatsService.instance.getStats(allEntries: entries);
    if (mounted) setState(() { _stats = stats; _loading = false; });
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
    final pct = (s.masteryPercent * 100).round();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header : retour + badge streak ───────────────────────────
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
                  // Cercle de progression
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: s.goalProgress,
                            strokeWidth: 8,
                            backgroundColor: _p.cardBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              s.goalMet ? AppColors.success : _a,
                            ),
                            strokeCap: StrokeCap.round,
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
                  // Infos à droite
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: s.goalProgress,
                            minHeight: 5,
                            backgroundColor: _p.cardBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              s.goalMet ? AppColors.success : _a,
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
                    child: _WeekChart(days: s.last7Days),
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
                      Text(
                        '$pct%',
                        style: TextStyle(color: _a, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.masteryPercent,
                      minHeight: 6,
                      backgroundColor: _p.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(_a),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Week chart ────────────────────────────────────────────────────────────────

class _WeekChart extends StatelessWidget {
  final List<DayEntry> days;
  const _WeekChart({required this.days});

  static const _barMaxH = 64.0;
  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    final maxAyahs = days.fold(0, (m, d) => max(m, d.ayahs));
    final todayStr = _dateStr(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((d) {
        final isToday  = _dateStr(d.date) == todayStr;
        final frac     = maxAyahs == 0 ? 0.0 : d.ayahs / maxAyahs;
        final barH     = d.ayahs == 0 ? 4.0 : max(8.0, frac * _barMaxH);
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
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

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
  final Color color;
  final String label;
  final int count;
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
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
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
