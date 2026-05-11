import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:ui';

import '../../data/surah_name.dart';
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
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
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

    final list = <Map<String, dynamic>>[];
    for (int i = 1; i <= 114; i++) {
      list.add({
        'id': i,
        'nameFr': surahFr[i] ?? 'Sourate $i',
        'nameAr': araNames[i] ?? '',
        'ayahCount': ayahCounts[i] ?? 0,
      });
    }

    if (mounted) {
      setState(() {
        _surahs = list;
        _filtered = list;
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _surahs
          : _surahs
              .where((s) =>
                  (s['nameFr'] as String).toLowerCase().contains(q) ||
                  s['id'].toString() == q)
              .toList();
    });
  }

  void _onSurahTap(Map<String, dynamic> surah) {
    // SRS tracking silencieux
    RevisionService.instance.addSurah(
      surahId: surah['id'] as int,
      surahName: surah['nameFr'] as String,
      surahNameAr: surah['nameAr'] as String,
      ayahCount: surah['ayahCount'] as int,
    );
    Navigator.of(context).push(_fadeRoute(RevisionConfigScreen(surah: surah)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // ── Close button ───────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ),
              // ── Big question ───────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quelle sourate veux-tu réviser ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Search bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassInput(
                  controller: _searchCtrl,
                  hint: 'Rechercher…',
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 10),
              // ── List ──────────────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.accent))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _SurahTile(
                          surah: _filtered[i],
                          onTap: () => _onSurahTap(_filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN 2 : Configurer la session (full screen)
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
    _toAyah = _totalAyahs;
  }

  void _launch() {
    final config = SessionConfig(
      surahId: widget.surah['id'] as int,
      surahName: widget.surah['nameFr'] as String,
      surahNameAr: widget.surah['nameAr'] as String,
      fromAyah: _fromAyah,
      toAyah: _toAyah,
      questionType: _questionType,
    );
    Navigator.of(context).push(_fadeRoute(RevisionSessionScreen(config: config)));
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalAyahs;
    final nameFr = widget.surah['nameFr'] as String;
    final nameAr = widget.surah['nameAr'] as String;
    final questionCount = (_toAyah - _fromAyah).clamp(0, total);

    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // ── Back button ────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              // ── Big question ────────────────────────────────────────────
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
              const SizedBox(height: 6),
              // Arabic name
              Text(
                nameAr,
                style: const TextStyle(
                  fontFamily: 'Hafs',
                  fontSize: 28,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(flex: 1),
              // ── Config card ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verse range
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                          rangeThumbShape:
                              const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
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
                              _toAyah = v.end.round();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Question type label
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
                            QuestionType.next => 'Suivant',
                            QuestionType.prev => 'Précédent',
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
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

class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _GlassInput({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
              prefixIcon:
                  Icon(icon, color: Colors.white.withValues(alpha: 0.45)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final Map<String, dynamic> surah;
  final VoidCallback onTap;

  const _SurahTile({required this.surah, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final id = surah['id'] as int;
    final nameFr = surah['nameFr'] as String;
    final nameAr = surah['nameAr'] as String;
    final ayahCount = surah['ayahCount'] as int;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  '$id',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameFr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text('$ayahCount versets',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Text(nameAr,
                style: const TextStyle(
                    fontFamily: 'Hafs', fontSize: 18, color: AppColors.accent)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: Colors.white.withValues(alpha: 0.25)),
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
