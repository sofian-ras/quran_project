// lib/ui/widgets/vertical_quran_view.dart
//
// Mode de lecture vertical : affichage continu de tous les versets.
// Adapté de quran_vertical_view.dart (repo Skoon) avec les services existants.

import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../services/mini_player_service.dart';
import '../../surah_name.dart';

class VerticalQuranView extends StatefulWidget {
  final int initialPage;
  final QcfThemeData theme;
  final void Function(int page) onPageChanged;
  final void Function(int surah, int verse) onLongPress;

  const VerticalQuranView({
    super.key,
    required this.initialPage,
    required this.theme,
    required this.onPageChanged,
    required this.onLongPress,
  });

  @override
  State<VerticalQuranView> createState() => _VerticalQuranViewState();
}

class _VerticalQuranViewState extends State<VerticalQuranView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  // Flat list of all (surah, ayah) pairs — built once.
  late final List<({int surah, int ayah})> _verses;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _verses = _buildVerseList();
    final initialIndex = _findIndexForPage(widget.initialPage);

    // Jump to initial position after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.isAttached) {
        _scrollController.jumpTo(index: initialIndex);
      }
    });

    _positionsListener.itemPositions.addListener(_onPositionChanged);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionChanged);
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

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
      final v = _verses[i];
      if (getPageNumber(v.surah, v.ayah) >= page) return i;
    }
    return 0;
  }

  void _onPositionChanged() {
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    // Pick the item closest to the top of the viewport.
    final first = positions.reduce(
        (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    final v = _verses[first.index];
    final page = getPageNumber(v.surah, v.ayah);
    if (page != _currentPage) {
      _currentPage = page;
      widget.onPageChanged(page);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.theme.pageBackgroundColor;
    final numberColor = widget.theme.verseNumberColor;
    final isDarkBg = bg.computeLuminance() < 0.5;
    final textColor = isDarkBg
        ? const Color(0xFFE8D5B3)
        : const Color(0xFF4A3F30);

    return ColoredBox(
      color: bg,
      child: ValueListenableBuilder<String?>(
        valueListenable: MiniPlayerService.instance.currentAyahKey,
        builder: (_, currentKey, __) {
          return ScrollablePositionedList.builder(
            itemCount: _verses.length,
            itemScrollController: _scrollController,
            itemPositionsListener: _positionsListener,
            itemBuilder: (context, index) {
              final v = _verses[index];
              final key = '${v.surah}:${v.ayah}';
              final isHighlighted = key == currentKey;
              final showHeader = v.ayah == 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader)
                    _SurahHeader(
                      surahId: v.surah,
                      textColor: numberColor,
                      bg: bg,
                    ),
                  GestureDetector(
                    onLongPress: () => widget.onLongPress(v.surah, v.ayah),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      color: isHighlighted
                          ? numberColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Numéro verset
                          _VerseNumber(
                              ayah: v.ayah, color: numberColor),
                          const SizedBox(width: 10),
                          // Texte verset
                          Expanded(
                            child: Text(
                              getVerse(v.surah, v.ayah,
                                  verseEndSymbol: true),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'UthmanTahaNaskh',
                                fontSize: 22,
                                height: 1.75,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Widgets helpers ────────────────────────────────────────────────────────

class _SurahHeader extends StatelessWidget {
  final int surahId;
  final Color textColor;
  final Color bg;

  const _SurahHeader({
    required this.surahId,
    required this.textColor,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          Divider(color: textColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 12),
          Text(
            getSurahNameArabic(surahId),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Text(
            surahFr[surahId] ?? 'Sourate $surahId',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: textColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _VerseNumber extends StatelessWidget {
  final int ayah;
  final Color color;

  const _VerseNumber({required this.ayah, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(top: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '$ayah',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
