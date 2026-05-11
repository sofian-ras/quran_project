import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';
import '../../services/quran_text_db.dart' show QVerse;
import '../../services/revision_service.dart';
import '../../theme/app_theme.dart';

// ── Data classes (inchangés) ─────────────────────────────────────────────────

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

// ── Phase machine ────────────────────────────────────────────────────────────

enum _Phase { intro, listening, thinking, answer, result }

// ── Main widget ──────────────────────────────────────────────────────────────

class RevisionSessionScreen extends StatefulWidget {
  final SessionConfig config;

  const RevisionSessionScreen({super.key, required this.config});

  @override
  State<RevisionSessionScreen> createState() => _RevisionSessionScreenState();
}

class _RevisionSessionScreenState extends State<RevisionSessionScreen>
    with TickerProviderStateMixin {
  // ── Data ─────────────────────────────────────────────────────────────────
  List<_Question> _questions = [];
  int _currentIndex = 0;
  final List<bool> _results = [];
  bool _loading = true;
  String? _error;

  // ── Phase ─────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.intro;
  bool _readyVisible = false;

  // ── Flash feedback ────────────────────────────────────────────────────────
  Color _flashColor = Colors.transparent;
  bool _showFlash = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _answerSlideCtrl;
  late final Animation<Offset> _answerSlideAnim;
  late final Animation<double> _answerFadeAnim;

  StreamSubscription<PlayerState>? _audioSub;
  Timer? _readyTimer;

  // ── Init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _answerSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _answerSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _answerSlideCtrl, curve: Curves.easeOutCubic));
    _answerFadeAnim = CurvedAnimation(parent: _answerSlideCtrl, curve: Curves.easeOut);

    _loadSession();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _answerSlideCtrl.dispose();
    _audioSub?.cancel();
    _readyTimer?.cancel();
    AudioService.instance.stopAyah();
    super.dispose();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _loadSession() async {
    setState(() { _loading = true; _error = null; });
    try {
      final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
      final raw = json.decode(jsonStr) as List<dynamic>;

      final verses = raw
          .where((v) {
            final s = v['surah'];
            final a = v['ayah'];
            if (s == null || a == null) return false;
            final surah = s is int ? s : int.tryParse(s.toString()) ?? -1;
            final ayah  = a is int ? a : int.tryParse(a.toString()) ?? -1;
            return surah == widget.config.surahId &&
                ayah >= widget.config.fromAyah &&
                ayah <= widget.config.toAyah;
          })
          .map((v) {
            final ayah = (v['ayah'] is int ? v['ayah'] : int.parse(v['ayah'].toString())) as int;
            final rawAr = (v['hafs'] ?? v['ar'] ?? '').toString();
            // Strip Quran verse-end ornament glyphs (Arabic Presentation Forms U+FB50–U+FDFF)
            final cleanAr = rawAr.replaceAll(RegExp(r'\s*[ﭐ-﷿]+\s*$'), '').trim();
            return QVerse(
              verseKey: '${widget.config.surahId}:$ayah',
              surah: widget.config.surahId,
              ayah: ayah,
              ar: cleanAr,
              fr: (v['fr'] ?? '').toString(),
              tafsir: null,
            );
          })
          .toList()
        ..sort((a, b) => a.ayah.compareTo(b.ayah));

      if (verses.length < 2) {
        setState(() {
          _error = 'Sélectionnez au moins 2 versets pour démarrer une session.';
          _loading = false;
        });
        return;
      }

      _questions = _buildQuestions(verses, widget.config.questionType)..shuffle();
      setState(() { _loading = false; _phase = _Phase.intro; });
    } catch (_) {
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
        questions.add(_Question(stimulus: verses[i], answer: verses[i + 1], isNext: true));
      } else if (isPrev) {
        questions.add(_Question(stimulus: verses[i + 1], answer: verses[i], isNext: false));
      }
    }
    return questions;
  }

  // ── Phase transitions ─────────────────────────────────────────────────────

  void _startSession() {
    setState(() { _phase = _Phase.listening; _readyVisible = false; });
    _enterListening();
  }

  void _enterListening() {
    _pulseCtrl.repeat(reverse: true);

    _readyTimer?.cancel();
    _readyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _phase == _Phase.listening) {
        setState(() => _readyVisible = true);
      }
    });

    _audioSub?.cancel();
    _audioSub = AudioService.instance.ayahPlayerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed &&
          _phase == _Phase.listening &&
          mounted) {
        setState(() => _readyVisible = true);
      }
    });
  }

  void _goToThinking() {
    _pulseCtrl.stop();
    _pulseCtrl.value = 0;
    setState(() => _phase = _Phase.thinking);
  }

  void _goToAnswer() {
    setState(() => _phase = _Phase.answer);
    _answerSlideCtrl.forward(from: 0);
  }

  Future<void> _recordResult(bool knew) async {
    _results.add(knew);

    // Flash feedback
    if (mounted) {
      setState(() {
        _flashColor = knew ? AppColors.success : AppColors.error;
        _showFlash = true;
      });
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _showFlash = false);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _advanceQuestion();
  }

  void _advanceQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _finishSession();
      return;
    }
    _currentIndex++;
    _answerSlideCtrl.reset();
    setState(() { _phase = _Phase.listening; _readyVisible = false; });
    _enterListening();
  }

  void _finishSession() {
    AudioService.instance.stopAyah();
    setState(() => _phase = _Phase.result);
    _saveResult();
  }

  Future<void> _saveResult() async {
    final correct = _results.where((r) => r).length;
    await RevisionService.instance.recordSessionResult(
      widget.config.surahId,
      correctCount: correct,
      totalCount: _questions.length,
    );
  }

  Future<bool> _confirmExit() async {
    if (_phase == _Phase.result || _phase == _Phase.intro) return true;
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          ),
        ),
      );
    }

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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  child: _buildCurrentPhaseContent(),
                ),
                // Flash overlay
                if (_showFlash)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showFlash ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(color: _flashColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseContent() {
    return switch (_phase) {
      _Phase.intro || _Phase.listening || _Phase.thinking || _Phase.answer =>
        _phase == _Phase.intro
            ? _IntroContent(
                key: const ValueKey('intro'),
                config: widget.config,
                questionCount: _questions.length,
                onStart: _startSession,
              )
            : _SessionContent(
                key: ValueKey('session_${_currentIndex}_${_phase.name}'),
                config: widget.config,
                question: _questions[_currentIndex],
                phase: _phase,
                currentIndex: _currentIndex,
                total: _questions.length,
                readyVisible: _readyVisible,
                pulseCtrl: _pulseCtrl,
                answerSlideAnim: _answerSlideAnim,
                answerFadeAnim: _answerFadeAnim,
                onReady: _goToThinking,
                onReveal: _goToAnswer,
                onResult: _recordResult,
                onExit: () async {
                  final exit = await _confirmExit();
                  if (exit && mounted) {
                    AudioService.instance.stopAyah();
                    Navigator.of(context).pop();
                  }
                },
              ),
      _Phase.result => _ResultContent(
          key: const ValueKey('result'),
          config: widget.config,
          results: _results,
          total: _questions.length,
          onFinish: () => Navigator.of(context).pop(),
        ),
    };
  }
}

// ── Intro screen ─────────────────────────────────────────────────────────────

class _IntroContent extends StatelessWidget {
  final SessionConfig config;
  final int questionCount;
  final VoidCallback onStart;

  const _IntroContent({
    super.key,
    required this.config,
    required this.questionCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (config.questionType) {
      QuestionType.next => 'Verset suivant',
      QuestionType.prev => 'Verset précédent',
      QuestionType.mixed => 'Mixte',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Arabic surah name
          Text(
            config.surahNameAr.isNotEmpty ? config.surahNameAr : config.surahName,
            style: const TextStyle(
              fontFamily: 'Hafs',
              fontSize: 42,
              color: AppColors.accent,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Révision de ${config.surahName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$questionCount questions · $typeLabel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text(
                'Commencer la session',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Session content (listening / thinking / answer) ───────────────────────────

class _SessionContent extends StatelessWidget {
  final SessionConfig config;
  final _Question question;
  final _Phase phase;
  final int currentIndex;
  final int total;
  final bool readyVisible;
  final AnimationController pulseCtrl;
  final Animation<Offset> answerSlideAnim;
  final Animation<double> answerFadeAnim;
  final VoidCallback onReady;
  final VoidCallback onReveal;
  final void Function(bool) onResult;
  final VoidCallback onExit;

  const _SessionContent({
    super.key,
    required this.config,
    required this.question,
    required this.phase,
    required this.currentIndex,
    required this.total,
    required this.readyVisible,
    required this.pulseCtrl,
    required this.answerSlideAnim,
    required this.answerFadeAnim,
    required this.onReady,
    required this.onReveal,
    required this.onResult,
    required this.onExit,
  });

  static String _phaseHeading(_Phase phase, _Question question) {
    return switch (phase) {
      _Phase.listening => 'Écoute attentivement ce verset',
      _Phase.thinking => question.isNext
          ? 'Quel est le verset suivant ?'
          : 'Quel est le verset précédent ?',
      _Phase.answer => 'Avais-tu trouvé ?',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Custom top bar ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
              Expanded(
                child: Text(
                  '${config.surahName} · ${currentIndex + 1} / $total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 48), // balance
            ],
          ),
        ),
        // ── Progress bar ──────────────────────────────────────────────────
        LinearProgressIndicator(
          value: (currentIndex + 1) / total,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          minHeight: 3,
        ),
        const SizedBox(height: 12),
        // ── Phase dots ────────────────────────────────────────────────────
        _PhaseIndicator(phase: phase),
        const SizedBox(height: 20),
        // ── Big centered phase question ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _phaseHeading(phase, question),
              key: ValueKey('heading_${phase.name}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // ── Main content ──────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PhaseBody(
              question: question,
              phase: phase,
              readyVisible: readyVisible,
              pulseCtrl: pulseCtrl,
              answerSlideAnim: answerSlideAnim,
              answerFadeAnim: answerFadeAnim,
              onReady: onReady,
              onReveal: onReveal,
              onResult: onResult,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phase indicator dots ──────────────────────────────────────────────────────

class _PhaseIndicator extends StatelessWidget {
  final _Phase phase;

  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final listeningDone = phase.index > _Phase.listening.index;
    final thinkingDone = phase.index > _Phase.thinking.index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PhaseDot(
          icon: Icons.headphones_rounded,
          label: 'Écoute',
          active: phase == _Phase.listening,
          done: listeningDone,
        ),
        _dotLine(listeningDone),
        _PhaseDot(
          icon: Icons.help_outline_rounded,
          label: 'Question',
          active: phase == _Phase.thinking,
          done: thinkingDone,
        ),
        _dotLine(thinkingDone),
        _PhaseDot(
          icon: Icons.star_rounded,
          label: 'Note',
          active: phase == _Phase.answer,
          done: false,
        ),
      ],
    );
  }

  Widget _dotLine(bool done) => Container(
        width: 28,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: done
              ? AppColors.accent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(1),
        ),
      );
}

class _PhaseDot extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool done;

  const _PhaseDot({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active || done ? AppColors.accent : Colors.white.withValues(alpha: 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 36 : 28,
          height: active ? 36 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.accent
                : done
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: color,
              width: active ? 0 : 1,
            ),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            color: active ? AppColors.primaryDark : color,
            size: active ? 18 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── Phase body ────────────────────────────────────────────────────────────────

class _PhaseBody extends StatelessWidget {
  final _Question question;
  final _Phase phase;
  final bool readyVisible;
  final AnimationController pulseCtrl;
  final Animation<Offset> answerSlideAnim;
  final Animation<double> answerFadeAnim;
  final VoidCallback onReady;
  final VoidCallback onReveal;
  final void Function(bool) onResult;

  const _PhaseBody({
    required this.question,
    required this.phase,
    required this.readyVisible,
    required this.pulseCtrl,
    required this.answerSlideAnim,
    required this.answerFadeAnim,
    required this.onReady,
    required this.onReveal,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Stimulus card (always visible, changes size) ──────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: phase == _Phase.listening
              ? _GlassVerseCard(
                  verse: question.stimulus,
                  label: 'Verset ${question.stimulus.ayah}',
                  pulseCtrl: pulseCtrl,
                )
              : _CompactVerseCard(verse: question.stimulus),
        ),
        const SizedBox(height: 14),

        // ── Listening phase ───────────────────────────────────────────────
        if (phase == _Phase.listening) ...[
          _CompactAudioPlayer(verse: question.stimulus),
          const Spacer(),
          AnimatedOpacity(
            opacity: readyVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _PrimaryButton(
              label: 'Je suis prêt',
              icon: Icons.arrow_forward_rounded,
              onPressed: readyVisible ? onReady : null,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Thinking phase ────────────────────────────────────────────────
        if (phase == _Phase.thinking) ...[
          const SizedBox(height: 4),
          // Mystery card
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
            ),
            child: Center(
              child: Text(
                '• • •',
                style: TextStyle(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  fontSize: 28,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Voir la réponse',
            icon: Icons.visibility_rounded,
            onPressed: onReveal,
          ),
          const SizedBox(height: 20),
        ],

        // ── Answer phase ──────────────────────────────────────────────────
        if (phase == _Phase.answer) ...[
          // Direction label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                question.isNext ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                question.isNext ? 'Verset suivant' : 'Verset précédent',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Answer card animated
          FadeTransition(
            opacity: answerFadeAnim,
            child: SlideTransition(
              position: answerSlideAnim,
              child: _GlassVerseCard(
                verse: question.answer,
                label: 'Verset ${question.answer.ayah}',
                pulseCtrl: null,
                accentColor: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CompactAudioPlayer(verse: question.answer),
          const Spacer(),
          // Result buttons
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'Pas trouvé',
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onPressed: () => onResult(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                  label: 'Trouvé !',
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  onPressed: () => onResult(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Glassmorphism verse card ──────────────────────────────────────────────────

class _GlassVerseCard extends StatelessWidget {
  final QVerse verse;
  final String label;
  final AnimationController? pulseCtrl;
  final Color accentColor;

  const _GlassVerseCard({
    required this.verse,
    required this.label,
    required this.pulseCtrl,
    this.accentColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedBuilder(
          animation: pulseCtrl ?? const AlwaysStoppedAnimation(0.5),
          builder: (_, child) {
            final pulse = pulseCtrl?.value ?? 0.5;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.2 + pulse * 0.3),
                  width: 1.0 + pulse * 0.5,
                ),
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
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
              const SizedBox(height: 14),
              Text(
                verse.ar,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Hafs',
                  fontSize: 24,
                  color: Colors.white,
                  height: 1.9,
                ),
              ),
              if (verse.fr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    verse.fr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return card;
  }
}

// ── Compact stimulus card (for thinking/answer phases) ───────────────────────

class _CompactVerseCard extends StatelessWidget {
  final QVerse verse;

  const _CompactVerseCard({required this.verse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'V${verse.ayah}',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verse.ar,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Hafs',
                fontSize: 17,
                color: Colors.white,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact audio player ──────────────────────────────────────────────────────

class _CompactAudioPlayer extends StatelessWidget {
  final QVerse verse;

  const _CompactAudioPlayer({required this.verse});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onPlayTap() {
    final audio = AudioService.instance;
    final key = '${verse.surah}:${verse.ayah}';
    if (audio.currentAyahKeyNotifier.value == key) {
      audio.toggleAyahPlayPause();
    } else {
      audio.playAyah(verse.surah, verse.ayah);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return StreamBuilder<PositionData>(
      stream: audio.ayahPositionDataStream,
      builder: (ctx, snap) {
        final pos = snap.data?.position ?? Duration.zero;
        final dur = snap.data?.duration ?? Duration.zero;
        final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: audio.isAyahPlayingNotifier,
                builder: (_, playing, __) => ValueListenableBuilder<String?>(
                  valueListenable: audio.currentAyahKeyNotifier,
                  builder: (_, key, __) {
                    final isThisVerse = key == '${verse.surah}:${verse.ayah}';
                    final showPause = playing && isThisVerse;
                    return GestureDetector(
                      onTap: _onPlayTap,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: pos.inMilliseconds.toDouble().clamp(0, max),
                        min: 0,
                        max: max,
                        onChanged: (v) =>
                            audio.seekAyah(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(pos),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.5))),
                          Text(_fmt(dur),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Button helpers ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == AppColors.accent ? AppColors.primaryDark : Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ── Result screen ─────────────────────────────────────────────────────────────

class _ResultContent extends StatelessWidget {
  final SessionConfig config;
  final List<bool> results;
  final int total;
  final VoidCallback onFinish;

  const _ResultContent({
    super.key,
    required this.config,
    required this.results,
    required this.total,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final correct = results.where((r) => r).length;
    final score = total > 0 ? correct / total : 0.0;

    final (message, scoreColor) = score >= 0.8
        ? ('Excellent travail !', AppColors.success)
        : score >= 0.5
            ? ('Continue comme ça !', AppColors.warning)
            : ('Reviens demain !', AppColors.error);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Score circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.12),
              border: Border.all(color: scoreColor, width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$correct / $total',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'trouvés',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Session de ${config.surahName} terminée',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          // Dots per question
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(
              results.length,
              (i) => Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: results[i]
                      ? AppColors.success.withValues(alpha: 0.9)
                      : AppColors.error.withValues(alpha: 0.7),
                ),
                child: Icon(
                  results[i] ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
          const Spacer(flex: 3),
          _PrimaryButton(
            label: 'Terminer la session',
            icon: Icons.check_circle_rounded,
            onPressed: onFinish,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
