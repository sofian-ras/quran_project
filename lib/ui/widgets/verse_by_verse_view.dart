// lib/ui/widgets/verse_by_verse_view.dart
//
// Mode lecture verset par verset : un verset centré, navigation prev/next.
// Adapté de quran_verse_by_verse_view.dart (repo Skoon).

import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../services/mini_player_service.dart';
import '../../surah_name.dart';

class VerseByVerseView extends StatefulWidget {
  final int initialPage;
  final QcfThemeData theme;
  final void Function(int surah, int ayah) onChanged;
  final void Function(int surah, int ayah) onLongPress;

  const VerseByVerseView({
    super.key,
    required this.initialPage,
    required this.theme,
    required this.onChanged,
    required this.onLongPress,
  });

  @override
  State<VerseByVerseView> createState() => _VerseByVerseViewState();
}

class _VerseByVerseViewState extends State<VerseByVerseView> {
  // Flat list of all (surah, ayah).
  late final List<({int surah, int ayah})> _verses;
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _verses = _buildVerseList();
    _currentIndex = _findIndexForPage(widget.initialPage);
    _pageController = PageController(initialPage: _currentIndex);
    // Notify parent of initial verse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final v = _verses[_currentIndex];
      widget.onChanged(v.surah, v.ayah);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static List<({int surah, int ayah})> _buildVerseList() {
    final list = <({int surah, int ayah})>[];
    for (int s = 1; s <= 114; s++) {
      final count = getVerseCount(s);
      for (int a = 1; a <= count; a++) {
        list.add((surah: s, ayah: a));
      }
    }
    return list;
  }

  int _findIndexForPage(int page) {
    for (int i = 0; i < _verses.length; i++) {
      if (getPageNumber(_verses[i].surah, _verses[i].ayah) >= page) return i;
    }
    return 0;
  }

  void _goTo(int index) {
    final clamped = index.clamp(0, _verses.length - 1);
    _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.theme.pageBackgroundColor;
    final numberColor = widget.theme.verseNumberColor;
    final isDarkBg = bg.computeLuminance() < 0.5;
    final textColor =
        isDarkBg ? const Color(0xFFE8D5B3) : const Color(0xFF4A3F30);
    final subColor = isDarkBg
        ? const Color(0xFF8B9BB4)
        : const Color(0xFF8B7355);

    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          // ── Navigation bar ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded,
                      color: numberColor.withValues(alpha: 0.7)),
                  onPressed: _currentIndex > 0
                      ? () => _goTo(_currentIndex - 1)
                      : null,
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: MiniPlayerService.instance.currentAyahKey,
                  builder: (_, key, __) {
                    final v = _verses[_currentIndex];
                    final isPlaying = key == '${v.surah}:${v.ayah}';
                    return Text(
                      '${getSurahNameArabic(v.surah)}  •  ${v.ayah} / ${getVerseCount(v.surah)}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 14,
                        color: isPlaying
                            ? numberColor
                            : textColor.withValues(alpha: 0.6),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded,
                      color: numberColor.withValues(alpha: 0.7)),
                  onPressed: _currentIndex < _verses.length - 1
                      ? () => _goTo(_currentIndex + 1)
                      : null,
                ),
              ],
            ),
          ),

          // ── Verse display ─────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              reverse: true, // RTL — swipe right = verse précédent
              itemCount: _verses.length,
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() => _currentIndex = index);
                final v = _verses[index];
                widget.onChanged(v.surah, v.ayah);
              },
              itemBuilder: (context, index) {
                final v = _verses[index];
                final verseKey = '${v.surah}:${v.ayah}';
                return ValueListenableBuilder<String?>(
                  valueListenable: MiniPlayerService.instance.currentAyahKey,
                  builder: (_, currentKey, __) {
                    final isHighlighted = verseKey == currentKey;
                    return GestureDetector(
                      onLongPress: () =>
                          widget.onLongPress(v.surah, v.ayah),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        color: isHighlighted
                            ? numberColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Surah name
                            Text(
                              surahFr[v.surah] ?? 'Sourate ${v.surah}',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.0,
                                color: subColor,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Verse text
                            Text(
                              getVerse(v.surah, v.ayah,
                                  verseEndSymbol: true),
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'UthmanTahaNaskh',
                                fontSize: 26,
                                height: 1.85,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Verse number badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: numberColor.withValues(alpha: 0.35),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${v.ayah}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: numberColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
