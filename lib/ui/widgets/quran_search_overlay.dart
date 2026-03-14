// lib/ui/widgets/quran_search_overlay.dart
//
// Overlay de recherche dans le Coran.
// S'affiche par-dessus le lecteur, navigue via PageController.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/quran_clean_plain.dart';
import '../../data/sura_ayah_to_page.dart';
import '../../data/arabic_numbers.dart';
import '../../data/quran_text.dart';
import '../../data/image_surah_glyph.dart';
import '../../services/font_download_service.dart';

// ── 114 noms arabes de sourates ─────────────────────────────────────────────
const List<String> _surahArabicNames = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

class QuranSearchOverlay extends StatefulWidget {
  final PageController pageController;
  final VoidCallback onClose;

  const QuranSearchOverlay({
    super.key,
    required this.pageController,
    required this.onClose,
  });

  @override
  State<QuranSearchOverlay> createState() => _QuranSearchOverlayState();
}

class _QuranSearchOverlayState extends State<QuranSearchOverlay> {
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  final Map<int, List<int>> _surasStartingOnPage = {};
  bool _suraFontLoaded = false;

  @override
  void initState() {
    super.initState();
    _buildSurasStartingOnPageMap();
    _loadSuraFont();
  }

  Future<void> _loadSuraFont() async {
    try {
      final ready = await FontDownloadService.areFontsDownloaded();
      if (!ready) return;
      await FontDownloadService.loadSuraNameFont();
      if (mounted) setState(() => _suraFontLoaded = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _buildSurasStartingOnPageMap() {
    for (int s = 1; s <= 114; s++) {
      final p = suraAyahToPage[s]?[1] ?? 1;
      _surasStartingOnPage.putIfAbsent(p, () => []).add(s);
    }
    _surasStartingOnPage.forEach((page, suras) => suras.sort());
  }

  String _getSurahArabicName(int surahNumber) {
    if (surahNumber < 1 || surahNumber > 114) return '';
    return _surahArabicNames[surahNumber - 1];
  }

  String _getAyahText(int surah, int ayah) {
    try {
      final verse = quranText.firstWhere(
        (v) => v['surah_number'] == surah && v['verse_number'] == ayah,
        orElse: () => {'content': ''},
      );
      return verse['content'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  void _performSearch(String query) {
    // 1. Search surah names
    final List<Map<String, dynamic>> suraResults = [];
    for (int i = 1; i <= 114; i++) {
      final suraName = _getSurahArabicName(i);
      if (suraName.contains(query)) {
        suraResults.add({
          'type': 'surah',
          'surah_number': i,
          'surah_name': suraName,
        });
      }
    }

    // 2. Search verses
    final verseResults = quranCleanPlain
        .where((verse) => (verse['content'] as String).contains(query))
        .map((v) => {...v, 'type': 'verse'})
        .toList();

    setState(() {
      _searchResults = [...suraResults, ...verseResults];
    });
  }

  void _closeSearch() {
    widget.onClose();
  }

  Widget _buildGroupTitle(String title, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sheetHeight = _searchResults.isEmpty
        ? 150
        : (screenHeight * 0.7).clamp(150, screenHeight * 0.9);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final iconsColor = isDark ? Colors.white : Colors.black;
    final resultTextColor = isDark ? Colors.white : Colors.black;
    final resultInfoColor = isDark ? Colors.white70 : Colors.black54;
    final fieldHintColor = isDark ? Colors.white54 : Colors.black38;
    final fieldTextColor = isDark ? Colors.white : Colors.black;
    final fieldBg = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF5F5F5);
    final groupTitleColor = isDark ? Colors.white70 : Colors.black87;
    final handleColor = const Color(0xFFB8860B);

    final suraCount = _searchResults.where((r) => r['type'] == 'surah').length;
    final verseCount = _searchResults.where((r) => r['type'] == 'verse').length;

    return Stack(
      children: [
        GestureDetector(
          onTap: _closeSearch,
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textSelectionTheme: TextSelectionThemeData(
                          cursorColor: handleColor,
                          selectionColor: handleColor.withValues(alpha: 0.3),
                          selectionHandleColor: handleColor,
                        ),
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: fieldTextColor),
                        decoration: InputDecoration(
                          hintText: 'ابحث في القرآن الكريم...',
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: TextStyle(color: fieldHintColor),
                          prefixIcon: Icon(Icons.search, color: iconsColor),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close, color: iconsColor),
                            onPressed: _closeSearch,
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: sheetHeight - 80),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _searchResults.length +
                            (suraCount > 0 ? 1 : 0) +
                            (verseCount > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (suraCount > 0 && index == 0) {
                            return _buildGroupTitle(
                              'عدد نتائج السور: ${ArabicNumbers().convert(suraCount)}',
                              groupTitleColor,
                            );
                          }

                          if (suraCount > 0 &&
                              verseCount > 0 &&
                              index == suraCount + 1) {
                            return _buildGroupTitle(
                              'عدد نتائج الآيات: ${ArabicNumbers().convert(verseCount)}',
                              groupTitleColor,
                            );
                          }

                          if (suraCount == 0 && verseCount > 0 && index == 0) {
                            return _buildGroupTitle(
                              'عدد نتائج الآيات: ${ArabicNumbers().convert(verseCount)}',
                              groupTitleColor,
                            );
                          }

                          int resultIndex = index;
                          if (suraCount > 0) {
                            resultIndex--;
                            if (verseCount > 0 && index > suraCount) {
                              resultIndex--;
                            }
                          } else if (verseCount > 0) {
                            resultIndex--;
                          }

                          final result = _searchResults[resultIndex];
                          final isSurah = result['type'] == 'surah';

                          if (isSurah) {
                            final surahNum = result['surah_number'] as int;
                            final surahName = result['surah_name'] as String;
                            final page = suraAyahToPage[surahNum]?[1] ?? 1;

                            return InkWell(
                              onTap: () {
                                _closeSearch();
                                widget.pageController.jumpToPage(page - 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.withValues(alpha: 0.1)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (_suraFontLoaded &&
                                            imageSuraGlyph.containsKey(surahNum))
                                          Text(
                                            imageSuraGlyph[surahNum]!,
                                            style: TextStyle(
                                              fontFamily: 'suraNameFont',
                                              fontSize: 36,
                                              color: resultTextColor,
                                            ),
                                          )
                                        else
                                          Text(
                                            surahName,
                                            style: TextStyle(
                                              fontFamily: 'ScheherazadeNew',
                                              fontSize: 22,
                                              color: resultTextColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      'صفحة ${ArabicNumbers().convert(page)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: resultInfoColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final surah = result['surah_number'] as int;
                            final ayah = result['verse_number'] as int;
                            final page = suraAyahToPage[surah]?[ayah] ?? 1;
                            final text = _getAyahText(surah, ayah);
                            final surahName = _getSurahArabicName(surah);

                            return InkWell(
                              onTap: () {
                                _closeSearch();
                                widget.pageController.jumpToPage(page - 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.withValues(alpha: 0.1)),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontFamily: 'ScheherazadeNew',
                                        fontSize: 20,
                                        color: resultTextColor,
                                      ),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Text(
                                          surahName,
                                          style: TextStyle(
                                            fontFamily: 'ScheherazadeNew',
                                            fontSize: 16,
                                            color: resultInfoColor,
                                          ),
                                        ),
                                        Text(
                                          'صفحة ${ArabicNumbers().convert(page)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: resultInfoColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
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
