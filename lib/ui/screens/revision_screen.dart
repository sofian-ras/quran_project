import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';

import '../../data/surah_name.dart';
import '../../models/revision_entry.dart';
import '../../services/revision_service.dart';
import '../../services/revision_stats_service.dart';
import '../../services/tafsir_service.dart';
import '../../theme/app_theme.dart';
import 'revision_palette.dart';
import 'revision_session_screen.dart';
import 'revision_stats_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN 1 : Choisir une sourate
// ─────────────────────────────────────────────────────────────────────────────

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _surahs = [];
  List<RevisionEntry> _dueToday = [];
  Map<int, RevisionEntry> _tracked = {};
  bool _loading = true;

  late AnimationController _staggerCtrl;

  // ── Thèmes (3 sombres + 3 clairs) ────────────────────────────────────────
  static const List<RevisionPalette> _themes = [
    RevisionPalette(accent: Color(0xFFD4AF77), bgTop: Color(0xFF1A1206), bgBottom: Color(0xFF261B0C), isDark: true),
    RevisionPalette(accent: Color(0xFF4DB87A), bgTop: Color(0xFF0A1A10), bgBottom: Color(0xFF122B1A), isDark: true),
    RevisionPalette(accent: Color(0xFF5BA3D5), bgTop: Color(0xFF080F1F), bgBottom: Color(0xFF0E1A32), isDark: true),
    RevisionPalette(accent: Color(0xFFC17A3A), bgTop: Color(0xFFF5EDD8), bgBottom: Color(0xFFEDE0C4), isDark: false),
    RevisionPalette(accent: Color(0xFF2B5F8E), bgTop: Color(0xFFD6E8F5), bgBottom: Color(0xFFC2D9EE), isDark: false),
    RevisionPalette(accent: Color(0xFF2A7A4A), bgTop: Color(0xFFD6EDE0), bgBottom: Color(0xFFC2E0CE), isDark: false),
  ];
  int _themeIndex = 0;
  RevisionPalette get _theme => _themes[_themeIndex];

  RevisionStats? _stats;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadAll();
    _loadAccent();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccent() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('revision_accent_index') ?? 0;
    if (mounted) setState(() => _themeIndex = idx.clamp(0, _themes.length - 1));
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _buildSurahList(),
      RevisionService.instance.getAll(),
    ]);

    final list    = results[0] as List<Map<String, dynamic>>;
    final entries = results[1] as List<RevisionEntry>;
    final due        = entries.where((e) => e.isDueToday).toList();
    final trackedMap = {for (final e in entries) e.surahId: e};

    if (mounted) {
      setState(() {
        _surahs     = list;
        _dueToday   = due;
        _tracked    = trackedMap;
        _loading    = false;
      });
      _staggerCtrl.forward();
    }

    final stats = await RevisionStatsService.instance.getStats(allEntries: entries);
    if (mounted) setState(() => _stats = stats);
  }

  Future<List<Map<String, dynamic>>> _buildSurahList() async {
    final jsonStr  = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;

    final Map<int, int> ayahCounts = {};
    for (final v in quranData) {
      final id = v['surah'] as int?;
      if (id == null) continue;
      ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
    }

    return [
      for (int i = 1; i <= 114; i++)
        {
          'id':        i,
          'nameFr':    surahFr[i] ?? 'Sourate $i',
          'ayahCount': ayahCounts[i] ?? 0,
        }
    ];
  }

  void _confirmRemove(int surahId, String nameFr) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer $nameFr ?'),
        content: const Text('Le suivi et l\'historique SRS seront supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await RevisionService.instance.removeSurah(surahId);
              _loadAll();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onSurahTap(Map<String, dynamic> surah) {
    RevisionService.instance.addSurah(
      surahId:     surah['id'] as int,
      surahName:   surah['nameFr'] as String,
      surahNameAr: '',
      ayahCount:   surah['ayahCount'] as int,
    );
    Navigator.of(context)
        .push(_fadeRoute(RevisionConfigScreen(surah: surah, palette: _theme, stats: _stats)))
        .then((_) => _loadAll());
  }

  void _showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _theme.bgBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RevisionThemeScope(
        palette: _theme,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thème',
                style: TextStyle(
                  color: _theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_themes.length, (i) {
                  final sel = i == _themeIndex;
                  final t = _themes[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _themeIndex = i);
                      SharedPreferences.getInstance()
                          .then((p) => p.setInt('revision_accent_index', i));
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? _theme.textPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: t.accent.withValues(alpha: 0.55),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RevisionThemeScope(
      palette: _theme,
      child: Scaffold(
        body: _GradientBg(
          child: SafeArea(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _theme.accent))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── Decorative header (scrolls away) ─────────────────
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        expandedHeight: 240,
                        pinned: false,
                        floating: false,
                        stretch: true,
                        automaticallyImplyLeading: false,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            children: [
                              // Halo soleil au centre
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.88,
                                      colors: [
                                        Colors.white.withValues(alpha: _theme.isDark ? 0.30 : 0.55),
                                        Colors.white.withValues(alpha: _theme.isDark ? 0.10 : 0.20),
                                        Colors.white.withValues(alpha: _theme.isDark ? 0.03 : 0.06),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.45, 0.72, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Title + hadith
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Révision',
                                      style: TextStyle(
                                        color: _theme.textPrimary,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Le Messager d\'Allah ﷺ :',
                                      style: TextStyle(
                                        color: _theme.textHint,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 36),
                                      child: Text(
                                        '« Révisez ce Coran, car par Celui qui détient mon âme dans Sa main, il s\'échappe plus rapidement que les chameaux attachés. »',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _theme.textSecondary,
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          height: 1.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Close button
                              Positioned(
                                top: 0,
                                left: 4,
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.close_rounded, color: _theme.iconMuted),
                                ),
                              ),
                              // Theme picker button
                              Positioned(
                                top: 0,
                                right: 4,
                                child: IconButton(
                                  onPressed: _showThemePicker,
                                  icon: Icon(Icons.palette_rounded, color: _theme.accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ── Carte objectif du jour ───────────────────────────
                      if (_stats != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: _DailyStatsCard(
                              stats: _stats!,
                              onTap: () => Navigator.of(context)
                                  .push(_fadeRoute(RevisionStatsScreen(palette: _theme)))
                                  .then((_) => _loadAll()),
                            ),
                          ),
                        ),
                      // ── À réviser aujourd'hui ─────────────────────────────
                      if (_dueToday.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _DueTodaySection(
                            dueToday: _dueToday,
                            onTap: _onSurahTap,
                            onLongPress: _confirmRemove,
                          ),
                        ),
                      // ── Surah list ────────────────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        sliver: SliverList.builder(
                          itemCount: _surahs.length,
                          itemBuilder: (_, i) {
                            final surah = _surahs[i];
                            final entry = _tracked[surah['id'] as int];
                            return _AnimatedTile(
                              index: i,
                              ctrl: _staggerCtrl,
                              child: _SurahTile(
                                surah: surah,
                                entry: entry,
                                onTap: () => _onSurahTap(surah),
                                onLongPress: entry != null
                                    ? () => _confirmRemove(entry.surahId, entry.surahName)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Due-today section ─────────────────────────────────────────────────────────

class _DueTodaySection extends StatelessWidget {
  final List<RevisionEntry> dueToday;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(int, String) onLongPress;

  const _DueTodaySection({
    required this.dueToday,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 12),
            child: Text(
              'À réviser aujourd\'hui',
              style: TextStyle(
                color: p.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dueToday.length,
              itemBuilder: (_, i) {
                final e = dueToday[i];
                final surah = {
                  'id': e.surahId,
                  'nameFr': e.surahName,
                  'ayahCount': e.ayahCount,
                };
                return _DueTodayCard(
                  entry: e,
                  onTap: () => onTap(surah),
                  onLongPress: () => onLongPress(e.surahId, e.surahName),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: p.cardBorder, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Toutes les sourates',
                    style: TextStyle(
                      color: p.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: p.cardBorder, height: 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Stagger animation wrapper ─────────────────────────────────────────────────

class _AnimatedTile extends StatelessWidget {
  final int index;
  final AnimationController ctrl;
  final Widget child;

  const _AnimatedTile({required this.index, required this.ctrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.04).clamp(0.0, 0.65);
    final end   = (delay + 0.30).clamp(0.0, 1.0);
    final curve = Interval(delay, end, curve: Curves.easeOutCubic);
    final fade  = CurvedAnimation(parent: ctrl, curve: curve);
    final slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: ctrl, curve: curve));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN 2 : Configurer la session
// ─────────────────────────────────────────────────────────────────────────────

class RevisionConfigScreen extends StatefulWidget {
  final Map<String, dynamic> surah;
  final RevisionPalette palette;
  final RevisionStats? stats;

  const RevisionConfigScreen({
    super.key,
    required this.surah,
    required this.palette,
    this.stats,
  });

  @override
  State<RevisionConfigScreen> createState() => _RevisionConfigScreenState();
}

class _RevisionConfigScreenState extends State<RevisionConfigScreen> {
  late int _fromAyah;
  late int _toAyah;
  QuestionType _questionType = QuestionType.next;

  RevisionPalette get _p => widget.palette;
  Color get _a => _p.accent;

  int get _totalAyahs {
    final count = widget.surah['ayahCount'] as int;
    if (count > 0) return count;
    final id = widget.surah['id'] as int;
    if (id >= 1 && id <= TafsirService.surahAyahCounts.length) {
      return TafsirService.surahAyahCounts[id - 1];
    }
    return 7;
  }

  @override
  void initState() {
    super.initState();
    _fromAyah = 1;
    final stats = widget.stats;
    if (stats != null && !stats.goalMet) {
      final remaining = (stats.dailyGoal - stats.todayAyahs).clamp(1, _totalAyahs);
      _toAyah = remaining;
    } else {
      _toAyah = _totalAyahs;
    }
  }

  void _launch() {
    final id = widget.surah['id'] as int;
    final config = SessionConfig(
      surahId:      id,
      surahName:    widget.surah['nameFr'] as String,
      surahNameAr:  '',
      fromAyah:     _fromAyah,
      toAyah:       _toAyah,
      questionType: _questionType,
    );
    Navigator.of(context).push(_fadeRoute(RevisionSessionScreen(config: config, palette: widget.palette)));
  }

  @override
  Widget build(BuildContext context) {
    final id           = widget.surah['id'] as int;
    final total        = _totalAyahs;
    final nameFr       = widget.surah['nameFr'] as String;
    final questionCount = (_toAyah - _fromAyah + 1).clamp(0, total);
    final stats         = widget.stats;
    final remaining     = stats != null ? (stats.dailyGoal - stats.todayAyahs).clamp(0, total) : 0;

    return RevisionThemeScope(
      palette: widget.palette,
      child: Scaffold(
        body: _GradientBg(
          child: SafeArea(
            child: Column(
              children: [
                // ── Back ──────────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: _p.iconMuted),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Title ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Comment veux-tu réviser\n$nameFr ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _p.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── SVG Arabic name ────────────────────────────────────────
                SvgPicture.asset(
                  'assets/images/Translated_Quran/surah_svg/$id.svg',
                  height: 42,
                  colorFilter: ColorFilter.mode(_a, BlendMode.srcIn),
                ),
                const Spacer(flex: 1),
                // ── Config card ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Objective indicator
                        if (stats != null) ...[
                          Row(
                            children: [
                              Text(
                                'Objectif du jour',
                                style: TextStyle(color: _p.textSecondary, fontSize: 12),
                              ),
                              const Spacer(),
                              if (stats.goalMet)
                                Text(
                                  'Atteint ✓',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                Text(
                                  '$remaining verset${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''}',
                                  style: TextStyle(color: _a, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Verse range header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Versets $_fromAyah → $_toAyah',
                              style: TextStyle(
                                color: _p.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                if (stats != null && !stats.goalMet && questionCount != remaining)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _fromAyah = 1;
                                      _toAyah = remaining.clamp(1, total);
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '← objectif',
                                        style: TextStyle(color: _a, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _a.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$questionCount question${questionCount > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: _a,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: _a,
                            inactiveTrackColor: _p.cardBorder,
                            thumbColor: _a,
                            overlayColor: _a.withValues(alpha: 0.2),
                            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                          ),
                          child: RangeSlider(
                            values: RangeValues(_fromAyah.toDouble(), _toAyah.toDouble()),
                            min: 1,
                            max: total.toDouble(),
                            divisions: total > 1 ? total - 1 : 1,
                            labels: RangeLabels('$_fromAyah', '$_toAyah'),
                            onChanged: (v) {
                              if (v.end - v.start < 1) return;
                              setState(() {
                                _fromAyah = v.start.round();
                                _toAyah   = v.end.round();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Type de question',
                          style: TextStyle(
                            color: _p.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: QuestionType.values.map((t) {
                            final selected = _questionType == t;
                            final label = switch (t) {
                              QuestionType.next  => 'Suivant',
                              QuestionType.prev  => 'Précédent',
                              QuestionType.mixed => 'Mixte',
                            };
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _questionType = t),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: selected ? _a : _p.cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected ? _a : _p.cardBorder,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected ? _p.buttonFg : _p.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // ── Start button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: questionCount >= 1 ? _launch : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: const Text(
                        'Commencer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _a,
                        foregroundColor: _p.buttonFg,
                        disabledBackgroundColor: _a.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 6,
                        shadowColor: _a.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets partagés
// ─────────────────────────────────────────────────────────────────────────────

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

// ── SRS color helper ──────────────────────────────────────────────────────────

Color _srsColor(String status) => switch (status) {
      'review'   => AppColors.success,
      'learning' => AppColors.warning,
      'lapsed'   => AppColors.error,
      _          => AppColors.success,
    };

// ── Due-today card (horizontal scroll) ───────────────────────────────────────

class _DueTodayCard extends StatefulWidget {
  final RevisionEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DueTodayCard({required this.entry, required this.onTap, this.onLongPress});

  @override
  State<_DueTodayCard> createState() => _DueTodayCardState();
}

class _DueTodayCardState extends State<_DueTodayCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = RevisionThemeScope.of(context);
    final color = _srsColor(widget.entry.status);
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 148,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.entry.surahName,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SvgPicture.asset(
                  'assets/images/Translated_Quran/surah_svg/${widget.entry.surahId}.svg',
                  height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Surah list tile ───────────────────────────────────────────────────────────

class _SurahTile extends StatefulWidget {
  final Map<String, dynamic> surah;
  final RevisionEntry? entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SurahTile({
    required this.surah,
    required this.onTap,
    this.entry,
    this.onLongPress,
  });

  @override
  State<_SurahTile> createState() => _SurahTileState();
}

class _SurahTileState extends State<_SurahTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p         = RevisionThemeScope.of(context);
    final id        = widget.surah['id'] as int;
    final nameFr    = widget.surah['nameFr'] as String;
    final ayahCount = widget.surah['ayahCount'] as int;
    final dotColor  = widget.entry != null ? _srsColor(widget.entry!.status) : null;
    final svgColor  = dotColor ?? p.accent.withValues(alpha: 0.55);

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: p.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dotColor != null
                  ? dotColor.withValues(alpha: 0.28)
                  : p.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // Number circle + SRS dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: p.accent.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(
                        '$id',
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (dotColor != null)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.bgBottom, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // French name + ayah count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameFr,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$ayahCount versets',
                      style: TextStyle(color: p.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // SVG Arabic name
              SvgPicture.asset(
                'assets/images/Translated_Quran/surah_svg/$id.svg',
                height: 26,
                colorFilter: ColorFilter.mode(svgColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: p.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Daily stats card ──────────────────────────────────────────────────────────

class _DailyStatsCard extends StatefulWidget {
  final RevisionStats stats;
  final VoidCallback onTap;

  const _DailyStatsCard({required this.stats, required this.onTap});

  @override
  State<_DailyStatsCard> createState() => _DailyStatsCardState();
}

class _DailyStatsCardState extends State<_DailyStatsCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p   = RevisionThemeScope.of(context);
    final s   = widget.stats;
    final pct = (s.masteryPercent * 100).round();

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '🔥 ${s.streak} jour${s.streak > 1 ? 's' : ''}',
                    style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '⭐ $pct% maîtrisé',
                    style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: p.textHint),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: s.goalProgress,
                  minHeight: 5,
                  backgroundColor: p.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    s.goalMet ? AppColors.success : p.accent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${s.todayAyahs} / ${s.dailyGoal} versets aujourd\'hui',
                    style: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                  if (s.goalMet) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Objectif atteint !',
                      style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transition helper ─────────────────────────────────────────────────────────

PageRouteBuilder<void> _fadeRoute(Widget page) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: child,
      ),
    );
