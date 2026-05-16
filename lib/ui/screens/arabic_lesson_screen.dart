import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/arabic_curriculum.dart';
import '../../models/arabic_models.dart';
import '../../services/arabic_learning_service.dart';
import 'arabic_lesson_complete_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────

const _kBgDark = Color(0xFF0B1223);
const _kBgLight = Color(0xFFF0EDE6);
const _kGold = Color(0xFFC8A97E);
const _kGreen = Color(0xFF52B788);
const _kRed = Color(0xFFE53935);
const _kSepia = Color(0xFF4A3F30);

// ─── Screen ────────────────────────────────────────────────────────────────

class ArabicLessonScreen extends StatefulWidget {
  final ArabicLesson lesson;
  final ArabicStats stats;

  const ArabicLessonScreen({
    super.key,
    required this.lesson,
    required this.stats,
  });

  @override
  State<ArabicLessonScreen> createState() => _ArabicLessonScreenState();
}

class _ArabicLessonScreenState extends State<ArabicLessonScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalAnswered = 0;
  int _heartsLeft = 0;

  bool _answered = false;
  bool? _lastCorrect;

  late AnimationController _progressCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _heartsLeft = widget.stats.hearts;

    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );

  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  List<Exercise> get exercises => widget.lesson.exercises;
  Exercise get current => exercises[_currentIndex];

  double get progress => exercises.isEmpty ? 0 : _currentIndex / exercises.length;

  void _onAnswer(bool correct) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _lastCorrect = correct;
      _totalAnswered++;
      if (correct) {
        _correctCount++;
      } else {
        _heartsLeft = (_heartsLeft - 1).clamp(0, 5);
        _shakeCtrl.forward(from: 0);
        ArabicLearningService.instance.loseHeart();
      }
    });

    if (_heartsLeft == 0 && !correct) {
      Future.delayed(const Duration(milliseconds: 800), _showNoHeartsDialog);
      return;
    }
  }

  void _advance() {
    if (_currentIndex >= exercises.length - 1) {
      _finishLesson();
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _lastCorrect = null;
    });
    _progressCtrl.animateTo((_currentIndex + 1) / exercises.length);
  }

  void _finishLesson() {
    final score = ArabicLearningService.instance.calculateScore(_correctCount, _totalAnswered);
    final xp = ArabicLearningService.instance.calculateXp(
      correctCount: _correctCount,
      totalCount: _totalAnswered,
      baseXp: widget.lesson.totalXp,
      streakDays: widget.stats.currentStreak,
    );
    final perfect = score == 100;

    ArabicLearningService.instance.completeLesson(
      lessonId: widget.lesson.id,
      score: score,
      xpEarned: xp,
      perfect: perfect,
    );

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ArabicLessonCompleteScreen(
          lesson: widget.lesson,
          correctCount: _correctCount,
          totalCount: _totalAnswered,
          xpEarned: xp,
          score: score,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showNoHeartsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NoHeartsDialog(
        onLeave: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kBgDark : _kBgLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _LessonTopBar(
              current: _currentIndex + 1,
              total: exercises.length,
              hearts: _heartsLeft,
              progress: progress,
              onClose: () => _showExitDialog(),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    math.sin(_shakeAnim.value * math.pi * 6) * 8 * (1 - _shakeAnim.value),
                    0,
                  ),
                  child: child,
                ),
                child: _buildExercise(isDark),
              ),
            ),
            _AnswerBar(
              answered: _answered,
              correct: _lastCorrect,
              isDark: isDark,
              exercise: current,
              onValidate: _answered ? _advance : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercise(bool isDark) {
    final ex = current;
    switch (ex.type) {
      case ExerciseType.letterIntro:
        return _LetterIntroExercise(
          exercise: ex,
          isDark: isDark,
          onContinue: _advance,
        );
      case ExerciseType.letterRecognition:
        return _McqExercise(
          exercise: ex,
          isDark: isDark,
          answered: _answered,
          lastCorrect: _lastCorrect,
          onAnswer: _onAnswer,
          showLetterAsQuestion: true,
        );
      case ExerciseType.nameToLetter:
        return _McqExercise(
          exercise: ex,
          isDark: isDark,
          answered: _answered,
          lastCorrect: _lastCorrect,
          onAnswer: _onAnswer,
          showLetterAsQuestion: false,
        );
      case ExerciseType.letterForms:
        return _LetterFormsExercise(
          exercise: ex,
          isDark: isDark,
          answered: _answered,
          onAnswer: _onAnswer,
        );
      case ExerciseType.letterWriting:
        return _LetterWritingExercise(
          exercise: ex,
          isDark: isDark,
          answered: _answered,
          onAnswer: _onAnswer,
          onContinue: _advance,
        );
      case ExerciseType.wordAssociation:
        return _WordAssociationExercise(
          exercise: ex,
          isDark: isDark,
          answered: _answered,
          onAnswer: _onAnswer,
        );
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('Quitter la leçon ?', style: TextStyle(color: Colors.white)),
        content: const Text('Ta progression dans cette leçon sera perdue.',
            style: TextStyle(color: Color(0xFF9FA8B0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer', style: TextStyle(color: _kGold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Quitter', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────

class _LessonTopBar extends StatelessWidget {
  final int current, total, hearts;
  final double progress;
  final VoidCallback onClose;

  const _LessonTopBar({
    required this.current,
    required this.total,
    required this.hearts,
    required this.progress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            color: const Color(0xFF9FA8B0),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFF2A3A4A),
                valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(
              5,
              (i) => Text(i < hearts ? '❤️' : '🖤', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Answer bar ──────────────────────────────────────────────────────────

class _AnswerBar extends StatelessWidget {
  final bool answered;
  final bool? correct;
  final bool isDark;
  final Exercise exercise;
  final VoidCallback? onValidate;

  const _AnswerBar({
    required this.answered,
    required this.correct,
    required this.isDark,
    required this.exercise,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    // Intro and writing handle their own "continue" button
    if (exercise.type == ExerciseType.letterIntro ||
        exercise.type == ExerciseType.letterWriting) {
      return const SizedBox.shrink();
    }
    if (!answered) return const SizedBox(height: 80);

    final isCorrect = correct == true;
    final bgColor = isCorrect
        ? (isDark ? const Color(0xFF1A3A2A) : const Color(0xFFDDF4E8))
        : (isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFDE8E8));
    final textColor = isCorrect ? _kGreen : _kRed;
    final label = isCorrect ? '✓ Bonne réponse !' : '✗ Mauvaise réponse';

    String? explanation;
    if (!isCorrect) {
      final letter = exercise.data['letter'] as ArabicLetter?;
      if (letter != null) {
        explanation = 'C\'était : ${letter.nameFr} (${letter.char})';
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          if (explanation != null) ...[
            const SizedBox(height: 4),
            Text(explanation, style: TextStyle(color: textColor.withAlpha(200), fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onValidate,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCorrect ? _kGreen : _kRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise 1 : Letter Intro ────────────────────────────────────────────

class _LetterIntroExercise extends StatefulWidget {
  final Exercise exercise;
  final bool isDark;
  final VoidCallback onContinue;
  const _LetterIntroExercise({required this.exercise, required this.isDark, required this.onContinue});

  @override
  State<_LetterIntroExercise> createState() => _LetterIntroExerciseState();
}

class _LetterIntroExerciseState extends State<_LetterIntroExercise>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final isDark = widget.isDark;

    // Syllable group lesson
    if (data['syllable'] == true) {
      final items = data['items'] as List<dynamic>;
      return _buildSyllableCard(items, isDark);
    }

    // Vowel intro
    if (data['isVowel'] == true) {
      final vowel = data['vowel'] as ArabicVowel;
      return _buildVowelCard(vowel, isDark);
    }

    // Standard letter intro
    final letter = data['letter'] as ArabicLetter;
    return _buildLetterCard(letter, isDark);
  }

  Widget _buildLetterCard(ArabicLetter letter, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Nouvelle lettre',
              style: TextStyle(color: _kGold, fontSize: 13, letterSpacing: 1.4)),
          const SizedBox(height: 24),
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _kGold, width: 2),
                boxShadow: [BoxShadow(color: _kGold.withAlpha(60), blurRadius: 24, spreadRadius: 4)],
              ),
              child: Center(
                child: Text(
                  letter.char,
                  style: TextStyle(
                    fontFamily: 'ScheherazadeNew',
                    fontSize: 96,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(letter.nameFr, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
          Text(letter.nameAr,
              style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 22, color: _kGold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _kGold.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGold.withAlpha(80)),
            ),
            child: Column(
              children: [
                Text('Prononciation : ${letter.phonetic}',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(letter.exampleFr,
                    style: TextStyle(color: textColor.withAlpha(180), fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 4 forms
          Text('Les 4 formes', style: TextStyle(color: _kGold, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FormChip(label: 'Isolée', form: letter.isolated, isDark: isDark),
              _FormChip(label: 'Initiale', form: letter.initial, isDark: isDark),
              _FormChip(label: 'Médiane', form: letter.medial, isDark: isDark),
              _FormChip(label: 'Finale', form: letter.final_, isDark: isDark),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF1C2333),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('J\'ai compris !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVowelCard(ArabicVowel vowel, bool isDark) {
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Nouvelle voyelle', style: TextStyle(color: _kGold, fontSize: 13, letterSpacing: 1.4)),
          const SizedBox(height: 24),
          ScaleTransition(
            scale: _scaleAnim,
            child: Text(vowel.symbol,
                style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 96, color: textColor)),
          ),
          const SizedBox(height: 16),
          Text(vowel.nameFr, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          Text(vowel.nameAr, style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 20, color: _kGold)),
          const SizedBox(height: 12),
          Text('Son : ${vowel.sound}', style: TextStyle(color: textColor.withAlpha(200))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kGold.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGold.withAlpha(80)),
            ),
            child: Column(
              children: [
                Text(vowel.example,
                    style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 36, color: textColor)),
                const SizedBox(height: 4),
                Text(vowel.exampleTranslation, style: TextStyle(color: textColor.withAlpha(180))),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF1C2333),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('J\'ai compris !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllableCard(List<dynamic> items, bool isDark) {
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          for (final item in items) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kGold.withAlpha(80)),
              ),
              child: Column(
                children: [
                  Text(
                    (item as Map)['text'] as String,
                    style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 36, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(item['sound'] as String,
                      style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold)),
                  if (item['desc'] != null) ...[
                    const SizedBox(height: 4),
                    Text(item['desc'] as String,
                        style: TextStyle(color: textColor.withAlpha(160), fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF1C2333),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormChip extends StatelessWidget {
  final String label, form;
  final bool isDark;
  const _FormChip({required this.label, required this.form, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(form,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: 28,
              color: isDark ? const Color(0xFFD4C5A3) : _kSepia,
            )),
        Text(label,
            style: const TextStyle(color: _kGold, fontSize: 10)),
      ],
    );
  }
}

// ─── Exercise 2 & 3 : MCQ ────────────────────────────────────────────────

class _McqExercise extends StatefulWidget {
  final Exercise exercise;
  final bool isDark, answered, showLetterAsQuestion;
  final bool? lastCorrect;
  final void Function(bool) onAnswer;

  const _McqExercise({
    required this.exercise,
    required this.isDark,
    required this.answered,
    required this.lastCorrect,
    required this.onAnswer,
    required this.showLetterAsQuestion,
  });

  @override
  State<_McqExercise> createState() => _McqExerciseState();
}

class _McqExerciseState extends State<_McqExercise> {
  int? _selected;

  @override
  void didUpdateWidget(_McqExercise old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;

    // Syllable / word MCQ
    if (data['isSyllable'] == true) {
      return _buildSyllableMcq(data, isDark, textColor);
    }

    // Vowel recognition
    if (data['isVowelRecog'] == true) {
      return _buildVowelMcq(data, isDark, textColor);
    }

    final letter = data['letter'] as ArabicLetter;
    final options = data['options'] as List<ArabicLetter>;
    final correctIndex = data['correctIndex'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            widget.showLetterAsQuestion ? 'Comment s\'appelle cette lettre ?' : 'Quelle lettre est le "${letter.nameFr}" ?',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (widget.showLetterAsQuestion)
            Text(letter.char,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 96,
                  color: textColor,
                ))
          else
            Text(letter.nameFr,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: List.generate(options.length, (i) {
              final opt = options[i];
              final isSelected = _selected == i;
              final isCorrect = i == correctIndex;

              Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
              Color border = _kGold.withAlpha(80);

              if (widget.answered && isSelected) {
                bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
                border = isCorrect ? _kGreen : _kRed;
              } else if (widget.answered && isCorrect) {
                bg = _kGreen.withAlpha(40);
                border = _kGreen;
              } else if (isSelected) {
                border = _kGold;
              }

              return GestureDetector(
                onTap: widget.answered
                    ? null
                    : () {
                        setState(() => _selected = i);
                        widget.onAnswer(i == correctIndex);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Center(
                    child: widget.showLetterAsQuestion
                        ? Text(opt.nameFr,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ))
                        : Text(opt.char,
                            style: TextStyle(
                              fontFamily: 'ScheherazadeNew',
                              fontSize: 40,
                              color: textColor,
                            )),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllableMcq(Map<String, dynamic> data, bool isDark, Color textColor) {
    final question = data['question'] as String;
    final questionLabel = data['questionLabel'] as String;
    final options = data['options'] as List<dynamic>;
    final correctIndex = data['correctIndex'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(questionLabel,
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(question,
              style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 72, color: textColor)),
          const SizedBox(height: 32),
          ...List.generate(options.length, (i) {
            final opt = options[i] as String;
            final isSelected = _selected == i;
            final isCorrect = i == correctIndex;

            Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
            Color border = _kGold.withAlpha(80);

            if (widget.answered && isSelected) {
              bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
              border = isCorrect ? _kGreen : _kRed;
            } else if (widget.answered && isCorrect) {
              bg = _kGreen.withAlpha(40);
              border = _kGreen;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: widget.answered
                    ? null
                    : () {
                        setState(() => _selected = i);
                        widget.onAnswer(i == correctIndex);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(opt, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVowelMcq(Map<String, dynamic> data, bool isDark, Color textColor) {
    final vowel = data['vowel'] as ArabicVowel;
    final correct = data['correct'] as ArabicVowel;
    final options = data['options'] as List<ArabicVowel>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Comment appelle-t-on cette voyelle ?',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(vowel.symbol,
              style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 72, color: textColor)),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final isCorrect = opt.nameFr == correct.nameFr;
            final isSelected = _selected == options.indexOf(opt);
            Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
            Color border = _kGold.withAlpha(80);

            if (widget.answered && isSelected) {
              bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
              border = isCorrect ? _kGreen : _kRed;
            } else if (widget.answered && isCorrect) {
              bg = _kGreen.withAlpha(40);
              border = _kGreen;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: widget.answered
                    ? null
                    : () {
                        setState(() => _selected = options.indexOf(opt));
                        widget.onAnswer(isCorrect);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(opt.nameFr,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Exercise 4 : Letter forms MCQ ───────────────────────────────────────

class _LetterFormsExercise extends StatefulWidget {
  final Exercise exercise;
  final bool isDark, answered;
  final void Function(bool) onAnswer;

  const _LetterFormsExercise({
    required this.exercise,
    required this.isDark,
    required this.answered,
    required this.onAnswer,
  });

  @override
  State<_LetterFormsExercise> createState() => _LetterFormsExerciseState();
}

class _LetterFormsExerciseState extends State<_LetterFormsExercise> {
  // Ask: "quelle est la forme médiane de X ?" → pick from 4 forms
  // Randomly pick which form to ask about
  late final int _askFormIndex; // 0=isolated,1=initial,2=medial,3=final
  int? _selected;

  @override
  void initState() {
    super.initState();
    _askFormIndex = math.Random().nextInt(4);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final letter = data['letter'] as ArabicLetter;
    final forms = data['options'] as List<Map<String, String>>;
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;

    final askLabel = forms[_askFormIndex]['label']!;
    final correctForm = forms[_askFormIndex]['form']!;

    final options = forms.map((f) => f['form']!).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('Quelle est la forme $askLabel de cette lettre ?',
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(letter.char,
              style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 80, color: textColor)),
          Text(letter.nameFr, style: const TextStyle(color: _kGold, fontSize: 14)),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: List.generate(options.length, (i) {
              final opt = options[i];
              final isSelected = _selected == i;
              final isCorrect = opt == correctForm;

              Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
              Color border = _kGold.withAlpha(80);

              if (widget.answered && isSelected) {
                bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
                border = isCorrect ? _kGreen : _kRed;
              } else if (widget.answered && isCorrect) {
                bg = _kGreen.withAlpha(40);
                border = _kGreen;
              }

              return GestureDetector(
                onTap: widget.answered
                    ? null
                    : () {
                        setState(() => _selected = i);
                        widget.onAnswer(isCorrect);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(opt,
                        style: TextStyle(
                          fontFamily: 'ScheherazadeNew',
                          fontSize: 36,
                          color: textColor,
                        )),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise 5 : Letter writing (canvas) ────────────────────────────────

class _LetterWritingExercise extends StatefulWidget {
  final Exercise exercise;
  final bool isDark, answered;
  final void Function(bool) onAnswer;
  final VoidCallback onContinue;

  const _LetterWritingExercise({
    required this.exercise,
    required this.isDark,
    required this.answered,
    required this.onAnswer,
    required this.onContinue,
  });

  @override
  State<_LetterWritingExercise> createState() => _LetterWritingExerciseState();
}

class _LetterWritingExerciseState extends State<_LetterWritingExercise> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _validated = false;
  bool? _result;

  void _validate() {
    // Count total drawn points
    final totalPoints = _strokes.fold<int>(0, (sum, s) => sum + s.length);
    final success = totalPoints > 40; // at least 40 drawn points
    setState(() {
      _validated = true;
      _result = success;
    });
    widget.onAnswer(success);
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
      _validated = false;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.exercise.data['letter'] as ArabicLetter;
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Écris cette lettre',
              style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(letter.nameFr, style: const TextStyle(color: _kGold, fontSize: 13)),
          const SizedBox(height: 20),
          // Drawing canvas
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _validated == false
                    ? _kGold.withAlpha(100)
                    : (_result == true ? _kGreen : _kRed),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onPanStart: _validated
                    ? null
                    : (d) {
                        setState(() {
                          _currentStroke = [d.localPosition];
                          _strokes.add(_currentStroke);
                        });
                      },
                onPanUpdate: _validated
                    ? null
                    : (d) {
                        setState(() => _currentStroke.add(d.localPosition));
                      },
                onPanEnd: _validated
                    ? null
                    : (_) => setState(() => _currentStroke = []),
                child: CustomPaint(
                  painter: _WritingCanvasPainter(
                    strokes: _strokes,
                    guideLetter: letter.char,
                    isDark: isDark,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_validated) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kGold),
                      foregroundColor: _kGold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Effacer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _strokes.isEmpty ? null : _validate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: const Color(0xFF1C2333),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: _kGold.withAlpha(80),
                    ),
                    child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _result == true ? _kGreen.withAlpha(30) : _kRed.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _result == true ? _kGreen : _kRed),
              ),
              child: Row(
                children: [
                  Icon(_result == true ? Icons.check_circle : Icons.error,
                      color: _result == true ? _kGreen : _kRed),
                  const SizedBox(width: 8),
                  Text(
                    _result == true ? 'Bravo ! Belle écriture !' : 'Continue à t\'entraîner !',
                    style: TextStyle(color: _result == true ? _kGreen : _kRed, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _result == true ? _kGreen : _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WritingCanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final String guideLetter;
  final bool isDark;

  _WritingCanvasPainter({
    required this.strokes,
    required this.guideLetter,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Guide letter in background
    final tp = TextPainter(
      text: TextSpan(
        text: guideLetter,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontSize: 140,
          color: const Color(0xFFC8A97E).withAlpha(35),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));

    // User strokes
    final paint = Paint()
      ..color = const Color(0xFFC8A97E)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WritingCanvasPainter old) => old.strokes != strokes;
}

// ─── Exercise 6 : Word Association ───────────────────────────────────────

class _WordAssociationExercise extends StatefulWidget {
  final Exercise exercise;
  final bool isDark, answered;
  final void Function(bool) onAnswer;

  const _WordAssociationExercise({
    required this.exercise,
    required this.isDark,
    required this.answered,
    required this.onAnswer,
  });

  @override
  State<_WordAssociationExercise> createState() => _WordAssociationExerciseState();
}

class _WordAssociationExerciseState extends State<_WordAssociationExercise> {
  late final List<QuranWord> _words;
  late final List<String> _shuffledTranslations;
  final Map<String, String> _matched = {}; // arabic → translation
  String? _selectedArabic;

  @override
  void initState() {
    super.initState();
    _words = (widget.exercise.data['words'] as List<dynamic>).cast<QuranWord>();
    _shuffledTranslations = _words.map((w) => w.translationFr).toList()..shuffle();
  }

  void _selectArabic(String arabic) {
    if (widget.answered || _matched.containsKey(arabic)) return;
    setState(() => _selectedArabic = arabic);
  }

  void _selectTranslation(String translation) {
    if (widget.answered || _selectedArabic == null) return;
    if (_matched.values.contains(translation)) return;

    setState(() {
      _matched[_selectedArabic!] = translation;
      _selectedArabic = null;
    });

    // Check completion
    if (_matched.length == _words.length) {
      final allCorrect = _words.every((w) => _matched[w.arabic] == w.translationFr);
      widget.onAnswer(allCorrect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Relie chaque mot arabe à sa traduction',
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arabic words column
              Expanded(
                child: Column(
                  children: _words.map((w) {
                    final isSelected = _selectedArabic == w.arabic;
                    final isMatched = _matched.containsKey(w.arabic);
                    final isCorrect = isMatched && _matched[w.arabic] == w.translationFr;

                    Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
                    Color border = _kGold.withAlpha(80);

                    if (isSelected) border = _kGold;
                    if (isMatched && widget.answered) {
                      bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
                      border = isCorrect ? _kGreen : _kRed;
                    } else if (isMatched) {
                      border = _kGold;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _selectArabic(w.arabic),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1.5),
                          ),
                          child: Center(
                            child: Text(w.arabic,
                                style: TextStyle(
                                  fontFamily: 'ScheherazadeNew',
                                  fontSize: 24,
                                  color: textColor,
                                )),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Translations column
              Expanded(
                child: Column(
                  children: _shuffledTranslations.map((tr) {
                    final isMatched = _matched.values.contains(tr);
                    final matchedArabic = _matched.entries
                        .where((e) => e.value == tr)
                        .map((e) => e.key)
                        .firstOrNull;
                    final isCorrect = matchedArabic != null &&
                        _words.any((w) => w.arabic == matchedArabic && w.translationFr == tr);

                    Color bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
                    Color border = _kGold.withAlpha(80);

                    if (isMatched && widget.answered) {
                      bg = isCorrect ? _kGreen.withAlpha(40) : _kRed.withAlpha(40);
                      border = isCorrect ? _kGreen : _kRed;
                    } else if (isMatched) {
                      border = _kGold;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _selectTranslation(tr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1.5),
                          ),
                          child: Center(
                            child: Text(tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_selectedArabic != null) ...[
            const SizedBox(height: 12),
            Text('Sélectionne la traduction →',
                style: TextStyle(color: _kGold, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

// ─── No hearts dialog ─────────────────────────────────────────────────────

class _NoHeartsDialog extends StatelessWidget {
  final VoidCallback onLeave;
  const _NoHeartsDialog({required this.onLeave});

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
          border: Border.all(color: const Color(0xFFE53935), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Plus de vies !',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tes vies se rechargent automatiquement (1 toutes les 30 min). Reviens plus tard !',
              style: TextStyle(color: Color(0xFF9FA8B0), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Revenir plus tard', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
