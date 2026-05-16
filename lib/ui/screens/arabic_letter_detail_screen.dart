import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/arabic_models.dart';

// ─── Palette ──────────────────────────────────────────────────────────────

const _kGold = Color(0xFFC8A97E);
const _kSepia = Color(0xFF4A3F30);

class ArabicLetterDetailScreen extends StatefulWidget {
  final ArabicLetter letter;
  const ArabicLetterDetailScreen({super.key, required this.letter});

  @override
  State<ArabicLetterDetailScreen> createState() => _ArabicLetterDetailScreenState();
}

class _ArabicLetterDetailScreenState extends State<ArabicLetterDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  void _clear() => setState(() { _strokes.clear(); _currentStroke = []; });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1223) : const Color(0xFFF0EDE6);
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;
    final letter = widget.letter;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B6C35),
        foregroundColor: Colors.white,
        title: Text(
          letter.nameFr,
          style: const TextStyle(color: Color(0xFFEDE0C0)),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Big letter with gentle rotation
            Center(
              child: AnimatedBuilder(
                animation: _rotateCtrl,
                builder: (_, child) => Transform.rotate(
                  angle: math.sin(_rotateCtrl.value * math.pi) * 0.04,
                  child: child,
                ),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGold, width: 2),
                    boxShadow: [
                      BoxShadow(color: _kGold.withAlpha(60), blurRadius: 24, spreadRadius: 4),
                    ],
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
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(letter.nameAr,
                      style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 22, color: _kGold)),
                  Text(letter.phonetic,
                      style: TextStyle(color: textColor.withAlpha(200), fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pronunciation card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGold.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prononciation', style: TextStyle(color: _kGold, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(letter.exampleFr, style: TextStyle(color: textColor)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4 forms card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGold.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Les 4 formes', style: TextStyle(color: _kGold, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _FormCard(label: 'Isolée', form: letter.isolated, textColor: textColor),
                      _FormCard(label: 'Initiale', form: letter.initial, textColor: textColor),
                      _FormCard(label: 'Médiane', form: letter.medial, textColor: textColor),
                      _FormCard(label: 'Finale', form: letter.final_, textColor: textColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Writing practice canvas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGold.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Entraîne-toi à écrire', style: TextStyle(color: _kGold, fontSize: 12, letterSpacing: 1.2)),
                      GestureDetector(
                        onTap: _clear,
                        child: const Text('Effacer', style: TextStyle(color: _kGold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 200,
                      color: isDark ? const Color(0xFF0D1826) : const Color(0xFFF8F4EC),
                      child: GestureDetector(
                        onPanStart: (d) {
                          setState(() {
                            _currentStroke = [d.localPosition];
                            _strokes.add(_currentStroke);
                          });
                        },
                        onPanUpdate: (d) => setState(() => _currentStroke.add(d.localPosition)),
                        onPanEnd: (_) => setState(() => _currentStroke = []),
                        child: CustomPaint(
                          painter: _DetailCanvasPainter(
                            strokes: _strokes,
                            guideLetter: letter.char,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String label, form;
  final Color textColor;
  const _FormCard({required this.label, required this.form, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _kGold.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGold.withAlpha(60)),
          ),
          child: Center(
            child: Text(
              form,
              style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 32, color: textColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: _kGold, fontSize: 10)),
      ],
    );
  }
}

class _DetailCanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final String guideLetter;

  const _DetailCanvasPainter({required this.strokes, required this.guideLetter});

  @override
  void paint(Canvas canvas, Size size) {
    // Guide letter
    final tp = TextPainter(
      text: TextSpan(
        text: guideLetter,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontSize: 140,
          color: const Color(0xFFC8A97E).withAlpha(30),
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
  bool shouldRepaint(_DetailCanvasPainter old) => old.strokes != strokes;
}
