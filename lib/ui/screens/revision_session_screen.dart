import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/quran_text_db.dart';
import '../../services/revision_service.dart';
import '../../theme/app_theme.dart';

enum QuestionType { next, prev, mixed }

class SessionConfig {
  final int surahId;
  final String surahName;
  final String surahNameAr;
  final int fromAyah;
  final int toAyah;
  final QuestionType questionType;

  const SessionConfig({
    required this.surahId,
    required this.surahName,
    required this.surahNameAr,
    required this.fromAyah,
    required this.toAyah,
    this.questionType = QuestionType.next,
  });
}

class _Question {
  final QVerse stimulus;
  final QVerse answer;
  final bool isNext;

  const _Question({
    required this.stimulus,
    required this.answer,
    required this.isNext,
  });
}

class RevisionSessionScreen extends StatefulWidget {
  final SessionConfig config;

  const RevisionSessionScreen({super.key, required this.config});

  @override
  State<RevisionSessionScreen> createState() => _RevisionSessionScreenState();
}

class _RevisionSessionScreenState extends State<RevisionSessionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _answerAnimCtrl;
  late final Animation<double> _answerFade;
  late final Animation<Offset> _answerSlide;

  List<_Question> _questions = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _loading = true;
  String? _error;

  final List<bool> _results = [];

  bool get _isLastQuestion => _currentIndex >= _questions.length - 1;
  bool get _sessionDone => _currentIndex >= _questions.length;

  @override
  void initState() {
    super.initState();
    _answerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _answerFade = CurvedAnimation(parent: _answerAnimCtrl, curve: Curves.easeOut);
    _answerSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _answerAnimCtrl, curve: Curves.easeOutCubic));

    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() { _loading = true; _error = null; });
    try {
      final verses = await QuranTextDb.instance.getSurah(widget.config.surahId);
      final filtered = verses
          .where((v) => v.ayah >= widget.config.fromAyah && v.ayah <= widget.config.toAyah)
          .toList()
        ..sort((a, b) => a.ayah.compareTo(b.ayah));

      if (filtered.length < 2) {
        setState(() {
          _error = 'Sélectionnez au moins 2 versets pour démarrer une session.';
          _loading = false;
        });
        return;
      }

      _questions = _buildQuestions(filtered, widget.config.questionType);
      setState(() => _loading = false);
      _playCurrentStimulus();
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement des versets.';
        _loading = false;
      });
    }
  }

  List<_Question> _buildQuestions(List<QVerse> verses, QuestionType type) {
    final questions = <_Question>[];
    for (int i = 0; i < verses.length - 1; i++) {
      final bool isNext = type == QuestionType.next ||
          (type == QuestionType.mixed && i % 2 == 0);
      final bool isPrev = type == QuestionType.prev ||
          (type == QuestionType.mixed && i % 2 != 0);

      if (isNext) {
        questions.add(_Question(
          stimulus: verses[i],
          answer: verses[i + 1],
          isNext: true,
        ));
      } else if (isPrev && i + 1 < verses.length) {
        questions.add(_Question(
          stimulus: verses[i + 1],
          answer: verses[i],
          isNext: false,
        ));
      }
    }
    return questions;
  }

  void _playCurrentStimulus() {
    if (_currentIndex >= _questions.length) return;
    final q = _questions[_currentIndex];
    AudioService.instance.playAyah(q.stimulus.surah, q.stimulus.ayah);
  }

  void _revealAnswer() {
    setState(() => _showAnswer = true);
    _answerAnimCtrl.forward(from: 0);
    // Auto-play answer verse
    final q = _questions[_currentIndex];
    AudioService.instance.playAyah(q.answer.surah, q.answer.ayah);
  }

  void _recordAndNext(bool knew) {
    _results.add(knew);
    if (_isLastQuestion) {
      AudioService.instance.stopAyah();
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      _answerAnimCtrl.reset();
      _playCurrentStimulus();
    }
  }

  Future<bool> _confirmExit() async {
    if (_sessionDone || _questions.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner la session ?'),
        content: const Text('Ta progression dans cette session sera perdue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _answerAnimCtrl.dispose();
    AudioService.instance.stopAyah();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Révision')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_sessionDone) {
      return _ResultsScreen(
        config: widget.config,
        results: _results,
        total: _questions.length,
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExit();
        if (exit && context.mounted) {
          AudioService.instance.stopAyah();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          title: Text(
            'Révision — ${widget.config.surahName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Counter
                Text(
                  '${_currentIndex + 1} / ${_questions.length}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                // Stimulus card
                _VerseCard(
                  verse: q.stimulus,
                  label: 'Verset ${q.stimulus.ayah}',
                  isDark: isDark,
                  accentColor: AppColors.primaryAccent,
                ),
                const SizedBox(height: 12),
                // Mini audio player
                _MiniAudioPlayer(isDark: isDark),
                const SizedBox(height: 16),
                // Question label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    q.isNext
                        ? 'Quel est le verset suivant ?'
                        : 'Quel est le verset précédent ?',
                    style: TextStyle(
                      color: isDark ? AppColors.accent : AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Answer area
                if (_showAnswer)
                  FadeTransition(
                    opacity: _answerFade,
                    child: SlideTransition(
                      position: _answerSlide,
                      child: _VerseCard(
                        verse: q.answer,
                        label: 'Verset ${q.answer.ayah} — Réponse',
                        isDark: isDark,
                        accentColor: AppColors.success,
                      ),
                    ),
                  ),
                const Spacer(),
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _showAnswer
                      ? _AnswerButtons(onResult: _recordAndNext)
                      : _RevealButton(onPressed: _revealAnswer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Verse card ──────────────────────────────────────────────────────────────

class _VerseCard extends StatelessWidget {
  final QVerse verse;
  final String label;
  final bool isDark;
  final Color accentColor;

  const _VerseCard({
    required this.verse,
    required this.label,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            verse.ar,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Hafs',
              fontSize: 22,
              height: 1.8,
            ),
          ),
          if (verse.fr.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                verse.fr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mini audio player ───────────────────────────────────────────────────────

class _MiniAudioPlayer extends StatelessWidget {
  final bool isDark;

  const _MiniAudioPlayer({required this.isDark});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2920) : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.1),
        ),
      ),
      child: StreamBuilder<PositionData>(
        stream: audio.ayahPositionDataStream,
        builder: (ctx, snap) {
          final pos = snap.data?.position ?? Duration.zero;
          final dur = snap.data?.duration ?? Duration.zero;
          final sliderMax = dur.inMilliseconds > 0
              ? dur.inMilliseconds.toDouble()
              : 1.0;

          return Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: audio.isAyahPlayingNotifier,
                builder: (_, playing, __) => GestureDetector(
                  onTap: audio.toggleAyahPlayPause,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: pos.inMilliseconds.clamp(0, sliderMax.toInt()).toDouble(),
                        min: 0,
                        max: sliderMax,
                        onChanged: (v) => audio.seekAyah(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(pos),
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
                          Text(_fmt(dur),
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Reveal button ────────────────────────────────────────────────────────────

class _RevealButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RevealButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: const Text(
          'Voir la réponse',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Answer buttons ────────────────────────────────────────────────────────────

class _AnswerButtons extends StatelessWidget {
  final void Function(bool knew) onResult;

  const _AnswerButtons({required this.onResult});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => onResult(false),
              icon: const Icon(Icons.close_rounded, color: AppColors.error),
              label: const Text(
                'Pas trouvé',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => onResult(true),
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Trouvé !',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Results screen ────────────────────────────────────────────────────────────

class _ResultsScreen extends StatefulWidget {
  final SessionConfig config;
  final List<bool> results;
  final int total;

  const _ResultsScreen({
    required this.config,
    required this.results,
    required this.total,
  });

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> {
  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    final correct = widget.results.where((r) => r).length;
    await RevisionService.instance.recordSessionResult(
      widget.config.surahId,
      correctCount: correct,
      totalCount: widget.total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.results.where((r) => r).length;
    final total = widget.total;
    final score = total > 0 ? correct / total : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String nextMsg;
    Color scoreColor;
    if (score >= 0.8) {
      nextMsg = 'Excellent ! Intervalle doublé.';
      scoreColor = AppColors.success;
    } else if (score >= 0.5) {
      nextMsg = 'Bien ! Continue à réviser régulièrement.';
      scoreColor = AppColors.warning;
    } else {
      nextMsg = 'Continue, tu progresses ! Révision demain.';
      scoreColor = AppColors.error;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Résultats'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score circle
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.1),
                  border: Border.all(color: scoreColor, width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$correct / $total',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        'trouvés',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.config.surahName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nextMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 10,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              const SizedBox(height: 48),
              // Results detail
              ...List.generate(
                widget.results.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        widget.results[i]
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: widget.results[i] ? AppColors.success : AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question ${i + 1}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/revision'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Terminer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
