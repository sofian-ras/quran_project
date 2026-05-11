import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../../data/surah_name.dart';
import '../../models/revision_entry.dart';
import '../../services/revision_service.dart';
import '../../services/streak_service.dart';
import '../../services/tafsir_service.dart';
import '../../theme/app_theme.dart';
import 'revision_session_screen.dart';

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  List<RevisionEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _entries = await RevisionService.instance.getAll();
    setState(() => _loading = false);
  }

  List<RevisionEntry> get _dueToday =>
      _entries.where((e) => e.isDueToday).toList();

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddSurahSheet(onAdded: _load),
    );
  }

  void _startSession(RevisionEntry entry) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SessionConfigSheet(entry: entry),
    );
    _load();
  }

  Future<void> _removeEntry(RevisionEntry entry) async {
    await RevisionService.instance.removeSurah(entry.surahId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.surahName} retiré'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () async {
            await RevisionService.instance.addSurah(
              surahId: entry.surahId,
              surahName: entry.surahName,
              surahNameAr: entry.surahNameAr,
              ayahCount: entry.ayahCount,
            );
            _load();
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = StreakService.instance.streak;
    final due = _dueToday;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        title: const Text(
          'Révision',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une sourate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  // ── Header stats ──────────────────────────────────────────
                  _StatsCard(
                    totalSurahs: _entries.length,
                    dueCount: due.length,
                    streak: streak,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // ── À réviser aujourd'hui ─────────────────────────────────
                  if (due.isNotEmpty) ...[
                    _sectionTitle('À réviser aujourd\'hui', isDark),
                    const SizedBox(height: 10),
                    ...due.map((e) => _DueSurahCard(
                          entry: e,
                          isDark: isDark,
                          onStart: () => _startSession(e),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // ── Mes sourates ──────────────────────────────────────────
                  if (_entries.isNotEmpty) ...[
                    _sectionTitle('Mes sourates mémorisées', isDark),
                    const SizedBox(height: 10),
                    ..._entries.map((e) => _EntryTile(
                          entry: e,
                          isDark: isDark,
                          onTap: () => _startSession(e),
                          onDelete: () => _removeEntry(e),
                        )),
                  ],

                  // ── Empty state ───────────────────────────────────────────
                  if (_entries.isEmpty)
                    _EmptyState(onAdd: _openAddSheet),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : AppColors.textPrimary,
        ),
      );
}

// ── Stats card ─────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int totalSurahs;
  final int dueCount;
  final int streak;
  final bool isDark;

  const _StatsCard({
    required this.totalSurahs,
    required this.dueCount,
    required this.streak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '$totalSurahs', label: 'Sourates', icon: Icons.menu_book_rounded),
          _divider(),
          _StatItem(value: '$dueCount', label: 'À réviser', icon: Icons.today_rounded),
          _divider(),
          _StatItem(value: '$streak', label: 'Streak', icon: Icons.local_fire_department_rounded),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.3),
      );
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Due today card ─────────────────────────────────────────────────────────

class _DueSurahCard extends StatelessWidget {
  final RevisionEntry entry;
  final bool isDark;
  final VoidCallback onStart;

  const _DueSurahCard({
    required this.entry,
    required this.isDark,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D26) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.refresh_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.surahName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.surahNameAr,
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }
}

// ── Entry tile (full list) ─────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final RevisionEntry entry;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusInfo(entry.status);

    String nextLabel;
    if (entry.nextReview == null) {
      nextLabel = 'À réviser maintenant';
    } else if (entry.isDueToday) {
      nextLabel = 'À réviser aujourd\'hui';
    } else {
      final days = entry.nextReview!.difference(DateTime.now()).inDays + 1;
      nextLabel = 'Dans $days jour${days > 1 ? 's' : ''}';
    }

    return Dismissible(
      key: ValueKey(entry.surahId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Retirer la sourate ?'),
            content: Text('${entry.surahName} sera retiré du suivi de révision.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Retirer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2920) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              '${entry.surahId}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            entry.surahName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            nextLabel,
            style: TextStyle(
              fontSize: 12,
              color: entry.isDueToday ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) => switch (status) {
        'new' => (AppColors.info, 'Nouveau'),
        'learning' => (AppColors.warning, 'Apprentissage'),
        'review' => (AppColors.success, 'Mémorisé'),
        'lapsed' => (AppColors.error, 'À revoir'),
        _ => (AppColors.textSecondary, status),
      };
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 72, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'Commence ta révision',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute les sourates que tu mémorises pour planifier tes révisions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter une sourate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add surah bottom sheet ─────────────────────────────────────────────────

class _AddSurahSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddSurahSheet({required this.onAdded});

  @override
  State<_AddSurahSheet> createState() => _AddSurahSheetState();
}

class _AddSurahSheetState extends State<_AddSurahSheet> {
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filtered = [];
  Set<int> _tracked = {};
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;
    final Map<int, String> araNames = {};
    final Map<int, int> ayahCounts = {};
    for (final v in quranData) {
      final id = v['surah'] as int?;
      if (id == null) continue;
      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
      araNames[id] ??= v['sura_name']?.toString() ?? '';
    }

    final surahs = <Map<String, dynamic>>[];
    for (int i = 1; i <= 114; i++) {
      surahs.add({
        'id': i,
        'nameFr': surahFr[i] ?? 'Sourate $i',
        'nameAr': araNames[i] ?? '',
        'ayahCount': ayahCounts[i] ?? 0,
      });
    }

    final tracked = await RevisionService.instance.getAll();
    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _filtered = surahs;
        _tracked = tracked.map((e) => e.surahId).toSet();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allSurahs
          : _allSurahs
              .where((s) =>
                  (s['nameFr'] as String).toLowerCase().contains(q) ||
                  s['id'].toString() == q)
              .toList();
    });
  }

  Future<void> _add(Map<String, dynamic> surah) async {
    await RevisionService.instance.addSurah(
      surahId: surah['id'] as int,
      surahName: surah['nameFr'] as String,
      surahNameAr: surah['nameAr'] as String,
      ayahCount: surah['ayahCount'] as int,
    );
    setState(() => _tracked.add(surah['id'] as int));
    widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choisir une sourate',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      final isTracked = _tracked.contains(s['id']);
                      return ListTile(
                        enabled: !isTracked,
                        leading: CircleAvatar(
                          backgroundColor: isTracked
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            '${s['id']}',
                            style: TextStyle(
                              color: isTracked ? AppColors.success : AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          s['nameFr'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isTracked ? AppColors.textSecondary : null,
                          ),
                        ),
                        subtitle: Text(
                          s['nameAr'] as String,
                          style: const TextStyle(fontFamily: 'Hafs'),
                        ),
                        trailing: isTracked
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 20)
                            : const Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary, size: 20),
                        onTap: isTracked ? null : () => _add(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Session config bottom sheet ────────────────────────────────────────────

class _SessionConfigSheet extends StatefulWidget {
  final RevisionEntry entry;

  const _SessionConfigSheet({required this.entry});

  @override
  State<_SessionConfigSheet> createState() => _SessionConfigSheetState();
}

class _SessionConfigSheetState extends State<_SessionConfigSheet> {
  late int _fromAyah;
  late int _toAyah;
  QuestionType _questionType = QuestionType.next;

  @override
  void initState() {
    super.initState();
    _fromAyah = 1;
    _toAyah = widget.entry.ayahCount > 0 ? widget.entry.ayahCount : 7;
  }

  int get _totalAyahs => widget.entry.ayahCount > 0
      ? widget.entry.ayahCount
      : (TafsirService.surahAyahCounts.length >= widget.entry.surahId
          ? TafsirService.surahAyahCounts[widget.entry.surahId - 1]
          : 7);

  void _startSession() {
    final config = SessionConfig(
      surahId: widget.entry.surahId,
      surahName: widget.entry.surahName,
      surahNameAr: widget.entry.surahNameAr,
      fromAyah: _fromAyah,
      toAyah: _toAyah,
      questionType: _questionType,
    );
    Navigator.of(context).pop();
    Navigator.of(context).push(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => RevisionSessionScreen(config: config),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _totalAyahs;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Surah name
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.surahName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${widget.entry.surahNameAr}  •  $total versets',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Verse range
          Text(
            'Plage de versets',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Verset $_fromAyah',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('Verset $_toAyah',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          RangeSlider(
            values: RangeValues(_fromAyah.toDouble(), _toAyah.toDouble()),
            min: 1,
            max: total.toDouble(),
            divisions: total > 1 ? total - 1 : 1,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.border,
            labels: RangeLabels('$_fromAyah', '$_toAyah'),
            onChanged: (v) {
              if (v.end - v.start < 1) return;
              setState(() {
                _fromAyah = v.start.round();
                _toAyah = v.end.round();
              });
            },
          ),
          Text(
            '${_toAyah - _fromAyah} question${(_toAyah - _fromAyah) > 1 ? 's' : ''}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Question type
          Text(
            'Type de question',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<QuestionType>(
            segments: const [
              ButtonSegment(
                value: QuestionType.next,
                label: Text('Suivant'),
                icon: Icon(Icons.arrow_forward_rounded, size: 16),
              ),
              ButtonSegment(
                value: QuestionType.prev,
                label: Text('Précédent'),
                icon: Icon(Icons.arrow_back_rounded, size: 16),
              ),
              ButtonSegment(
                value: QuestionType.mixed,
                label: Text('Mixte'),
                icon: Icon(Icons.shuffle_rounded, size: 16),
              ),
            ],
            selected: {_questionType},
            onSelectionChanged: (s) => setState(() => _questionType = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return null;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Commencer la session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
