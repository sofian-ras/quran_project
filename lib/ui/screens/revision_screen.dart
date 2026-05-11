import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:ui';

import '../../data/surah_name.dart';
import '../../models/revision_entry.dart';
import '../../services/revision_service.dart';
import '../../services/tafsir_service.dart';
import '../../theme/app_theme.dart';
import 'revision_session_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN 1 : Choisir une sourate
// ─────────────────────────────────────────────────────────────────────────────

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  List<Map<String, dynamic>> _surahs = [];
  List<RevisionEntry> _dueToday = [];
  Map<int, RevisionEntry> _tracked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
    }
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
      surahId:    surah['id'] as int,
      surahName:  surah['nameFr'] as String,
      surahNameAr: '',
      ayahCount:  surah['ayahCount'] as int,
    );
    Navigator.of(context)
        .push(_fadeRoute(RevisionConfigScreen(surah: surah)))
        .then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _RevisionHeader(
                        dueToday: _dueToday,
                        tracked: _tracked,
                        onTap: _onSurahTap,
                        onLongPress: _confirmRemove,
                      ),
                    ),
                    // ── Surah list ────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      sliver: SliverList.builder(
                        itemCount: _surahs.length,
                        itemBuilder: (_, i) {
                          final surah = _surahs[i];
                          final entry = _tracked[surah['id'] as int];
                          return _SurahTile(
                            surah: surah,
                            entry: entry,
                            onTap: () => _onSurahTap(surah),
                            onLongPress: entry != null
                                ? () => _confirmRemove(entry.surahId, entry.surahName)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Header widget (scrolls with list) ────────────────────────────────────────

class _RevisionHeader extends StatelessWidget {
  final List<RevisionEntry> dueToday;
  final Map<int, RevisionEntry> tracked;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(int, String) onLongPress;

  const _RevisionHeader({
    required this.dueToday,
    required this.tracked,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Révision',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Choisissez une sourate à réviser',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── À réviser aujourd'hui ──────────────────────────────────────
          if (dueToday.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 0, 12),
              child: Text(
                'À réviser aujourd\'hui',
                style: TextStyle(
                  color: AppColors.accent,
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
                  Expanded(
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Toutes les sourates',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN 2 : Configurer la session
// ─────────────────────────────────────────────────────────────────────────────

class RevisionConfigScreen extends StatefulWidget {
  final Map<String, dynamic> surah;

  const RevisionConfigScreen({super.key, required this.surah});

  @override
  State<RevisionConfigScreen> createState() => _RevisionConfigScreenState();
}

class _RevisionConfigScreenState extends State<RevisionConfigScreen> {
  late int _fromAyah;
  late int _toAyah;
  QuestionType _questionType = QuestionType.next;

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
    _toAyah   = _totalAyahs;
  }

  void _launch() {
    final id = widget.surah['id'] as int;
    final config = SessionConfig(
      surahId:     id,
      surahName:   widget.surah['nameFr'] as String,
      surahNameAr: '',
      fromAyah:    _fromAyah,
      toAyah:      _toAyah,
      questionType: _questionType,
    );
    Navigator.of(context).push(_fadeRoute(RevisionSessionScreen(config: config)));
  }

  @override
  Widget build(BuildContext context) {
    final id           = widget.surah['id'] as int;
    final total        = _totalAyahs;
    final nameFr       = widget.surah['nameFr'] as String;
    final questionCount = (_toAyah - _fromAyah + 1).clamp(0, total);

    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // ── Back ──────────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              // ── Title ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Comment veux-tu réviser\n$nameFr ?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
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
                colorFilter: const ColorFilter.mode(AppColors.accent, BlendMode.srcIn),
              ),
              const Spacer(flex: 1),
              // ── Config card ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verse range header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Versets $_fromAyah → $_toAyah',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$questionCount question${questionCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                          thumbColor: AppColors.accent,
                          overlayColor: AppColors.accent.withValues(alpha: 0.2),
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
                          color: Colors.white.withValues(alpha: 0.55),
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
                                  color: selected
                                      ? AppColors.accent
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.accent
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.primaryDark
                                        : Colors.white.withValues(alpha: 0.75),
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
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primaryDark,
                      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 6,
                      shadowColor: AppColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
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

// ── SRS color helper ──────────────────────────────────────────────────────────

Color _srsColor(String status) => switch (status) {
      'review'   => AppColors.success,
      'learning' => AppColors.warning,
      'lapsed'   => AppColors.error,
      _          => Colors.white,
    };

// ── Due-today card (horizontal scroll) ───────────────────────────────────────

class _DueTodayCard extends StatelessWidget {
  final RevisionEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DueTodayCard({required this.entry, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final color = _srsColor(entry.status);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
            // Status dot + name
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
                    entry.surahName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // SVG Arabic name
            Align(
              alignment: Alignment.centerRight,
              child: SvgPicture.asset(
                'assets/images/Translated_Quran/surah_svg/${entry.surahId}.svg',
                height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Surah list tile ───────────────────────────────────────────────────────────

class _SurahTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final id        = surah['id'] as int;
    final nameFr    = surah['nameFr'] as String;
    final ayahCount = surah['ayahCount'] as int;
    final dotColor  = entry != null ? _srsColor(entry!.status) : null;
    final svgColor  = dotColor ?? AppColors.accent.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dotColor != null ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dotColor != null
                ? dotColor.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.07),
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
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Center(
                    child: Text(
                      '$id',
                      style: const TextStyle(
                        color: AppColors.accent,
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
                        border: Border.all(color: AppColors.primaryDark, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // French name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameFr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$ayahCount versets',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
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
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
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
