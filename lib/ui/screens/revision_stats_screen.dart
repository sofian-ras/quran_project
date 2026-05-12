import 'package:flutter/material.dart';
import 'dart:ui';

import '../../services/revision_service.dart';
import '../../services/revision_stats_service.dart';
import '../../theme/app_theme.dart';

class RevisionStatsScreen extends StatefulWidget {
  final Color accentColor;
  const RevisionStatsScreen({super.key, required this.accentColor});

  @override
  State<RevisionStatsScreen> createState() => _RevisionStatsScreenState();
}

class _RevisionStatsScreenState extends State<RevisionStatsScreen> {
  RevisionStats? _stats;
  bool _loading = true;

  Color get _a => widget.accentColor;

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
      backgroundColor: AppColors.primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Objectif quotidien',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$draft versets / jour',
                    style: TextStyle(
                      color: _a,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: _a,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
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
                    foregroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _a))
              : _buildContent(_stats!),
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
            // ── Back ──────────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white54),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),

            // ── Streak ────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    '🔥',
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.streak}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.streak == 1 ? 'jour consécutif' : 'jours consécutifs',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Objectif du jour ──────────────────────────────────────────
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Objectif du jour',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (s.goalMet)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Atteint ✓',
                            style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(
                              value: s.goalProgress,
                              strokeWidth: 9,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
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
                                  color: s.goalMet ? AppColors.success : Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                '/ ${s.dailyGoal}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'versets aujourd\'hui',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _showGoalPicker,
                      child: Text(
                        'Modifier l\'objectif →',
                        style: TextStyle(color: _a, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Maîtrise ──────────────────────────────────────────────────
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maîtrise globale',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(color: _a, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.masteryPercent,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(_a),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.totalTracked} sourate${s.totalTracked > 1 ? 's' : ''} suivie${s.totalTracked > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatusChip(
                        color: AppColors.success,
                        label: 'Maîtrisées',
                        count: s.masteredCount,
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        color: AppColors.warning,
                        label: 'En cours',
                        count: s.learningCount,
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        color: AppColors.error,
                        label: 'À revoir',
                        count: s.lapsedCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tout temps ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Sessions',
                    value: '${s.allTimeSessions}',
                    accent: _a,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Versets révisés',
                    value: '${s.allTimeAyahs}',
                    accent: _a,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────────────────────────────

class _GradientBg extends StatelessWidget {
  final Widget child;
  const _GradientBg({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDark, AppColors.primary],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatTile({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(color: accent, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
