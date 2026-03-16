// lib/ui/widgets/quran_search_overlay.dart
//
// Overlay de recherche dans le Coran.
// Utilise searchWords() de qcf_quran (pas de DB externe nécessaire).
// S'affiche par-dessus le lecteur et navigue via PageController.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../data/quran_clean_plain.dart';
import '../../surah_name.dart';

class QuranSearchOverlay extends StatefulWidget {
  final PageController pageController;
  final VoidCallback onClose;
  final bool isDark;

  const QuranSearchOverlay({
    super.key,
    required this.pageController,
    required this.onClose,
    required this.isDark,
  });

  @override
  State<QuranSearchOverlay> createState() => _QuranSearchOverlayState();
}

class _QuranSearchOverlayState extends State<QuranSearchOverlay> {
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  void _search(String query) {
    // Single-pass over pre-normalized Arabic text — no toLowerCase, no toString
    final list = <Map<String, dynamic>>[];
    for (final v in quranCleanPlain) {
      if ((v['content'] as String).contains(query)) {
        list.add({
          'suraNumber': v['surah_number'],
          'verseNumber': v['verse_number'],
        });
        if (list.length >= 50) break;
      }
    }
    if (mounted) {
      setState(() {
        _results = list;
        _searched = true;
      });
    }
  }

  void _navigate(int surah, int verse) {
    widget.onClose();
    final page = getPageNumber(surah, verse);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pageController.hasClients) {
        widget.pageController.jumpToPage(page - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1A2035) : Colors.white;
    final textColor =
        widget.isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = widget.isDark ? Colors.white38 : Colors.black26;
    final fieldBg = widget.isDark
        ? const Color(0xFF252D40)
        : const Color(0xFFF2F2F2);
    final dividerColor =
        widget.isDark ? Colors.white12 : const Color(0xFFE5E5E5);
    final surahColor = widget.isDark
        ? const Color(0xFFBFA878)
        : const Color(0xFF8B6C35);

    return Stack(
      children: [
        // Fond obscurci — tap pour fermer
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black.withValues(alpha: 0.45)),
        ),

        // Panneau de recherche (top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Champ de saisie
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'ابحث في القرآن الكريم...',
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                          color: hintColor,
                          fontFamily: 'ScheherazadeNew',
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: hintColor, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: hintColor, size: 20),
                          onPressed: widget.onClose,
                        ),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Aucun résultat
                  if (_searched && _results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        'Aucun résultat',
                        style:
                            TextStyle(color: hintColor, fontSize: 13),
                      ),
                    ),

                  // Liste de résultats
                  if (_results.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Divider(
                            color: dividerColor,
                            height: 1,
                            indent: 16,
                            endIndent: 16),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          final surah = r['suraNumber'] as int;
                          final verse = r['verseNumber'] as int;
                          final nameFr =
                              surahFr[surah] ?? 'Sourate $surah';
                          final nameAr = getSurahNameArabic(surah);
                          final verseText = getVerse(surah, verse);
                          final page = getPageNumber(surah, verse);

                          return InkWell(
                            onTap: () => _navigate(surah, verse),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    verseText,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'UthmanTahaNaskh',
                                      fontSize: 18,
                                      height: 1.6,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Page $page',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: hintColor),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'v.$verse · $nameFr',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: hintColor),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            nameAr,
                                            textDirection:
                                                TextDirection.rtl,
                                            style: TextStyle(
                                              fontFamily:
                                                  'ScheherazadeNew',
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: surahColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
      ],
    );
  }
}
