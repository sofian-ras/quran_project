// lib/ui/widgets/ayah_action_sheet.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/quran_ayah_metadata_db.dart';
import '../../services/quran_text_db.dart';
import '../../services/quran_translation_pack_service.dart';
import '../../services/verse_favorites_service.dart';
import '../../surah_name.dart';
import '../../data/quran_text_data.dart';
import '../../data/sura_ayah_to_page.dart';
import '../../data/image_surah_glyph.dart';
import '../../services/font_download_service.dart';

class AyahActionSheet extends StatefulWidget {
  final int surah;
  final int ayah;

  const AyahActionSheet({
    super.key,
    required this.surah,
    required this.ayah,
  });

  static Future<void> show(
    BuildContext context, {
    required int surah,
    required int ayah,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahActionSheet(surah: surah, ayah: ayah),
    );
  }

  @override
  State<AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<AyahActionSheet> {
  QVerse? _verse;
  bool _loading = true;
  bool _isFavorite = false;

  // ── QCF font ──────────────────────────────────────────
  String? _qfcText;
  String? _qfcFontFamily;
  bool _qfcFontLoaded = false;

  // ── Traduction ────────────────────────────────────────
  bool _packDownloading = false;
  double _packProgress = 0;
  CancelToken? _packCancelToken;

  // ── Tafsir ────────────────────────────────────────────
  int _tafsirId = 14;
  String? _onlineTafsir;
  bool _tafsirLoading = false;
  bool _tafsirSaved = false;
  bool _tafsirSaving = false;
  CancelToken? _tafsirCancelToken;
  final _tafsirKey = GlobalKey();

  String get _verseKey    => '${widget.surah}:${widget.ayah}';
  String get _tafsirCacheKey => 'tafsir_${_tafsirId}_$_verseKey';
  String get _surahName   => surahFr[widget.surah] ?? 'Sourate ${widget.surah}';

  @override
  void initState() {
    super.initState();
    _load();
    _loadQcfFont();
  }

  @override
  void dispose() {
    _tafsirCancelToken?.cancel();
    _packCancelToken?.cancel();
    super.dispose();
  }

  List<Map<String, int>> _pageAyahsSorted(int page) {
    final Set<String> seen = {};
    final List<Map<String, int>> list = [];
    for (int s = 1; s <= 114; s++) {
      final ayahMap = suraAyahToPage[s];
      if (ayahMap == null) continue;
      for (final entry in ayahMap.entries) {
        if (entry.value == page) {
          final key = '$s:${entry.key}';
          if (!seen.contains(key)) {
            seen.add(key);
            list.add({'surah': s, 'ayah': entry.key});
          }
        }
      }
    }
    list.sort((a, b) {
      if (a['surah'] != b['surah']) return a['surah']!.compareTo(b['surah']!);
      return a['ayah']!.compareTo(b['ayah']!);
    });
    return list;
  }

  Future<void> _loadQcfFont() async {
    try {
      if (!await FontDownloadService.areFontsDownloaded()) return;
      final page = suraAyahToPage[widget.surah]?[widget.ayah] ?? 1;
      await FontDownloadService.loadFont(page);
      final family = 'QCF_P${page.toString().padLeft(3, '0')}';
      String qfcText = '';
      if (page >= 1 && page <= quranTextData.length) {
        final pageAyahs = _pageAyahsSorted(page);
        final idx = pageAyahs.indexWhere(
          (e) => e['surah'] == widget.surah && e['ayah'] == widget.ayah,
        );
        if (idx != -1 && idx < quranTextData[page - 1].length) {
          qfcText = quranTextData[page - 1][idx];
        }
      }
      if (!mounted) return;
      setState(() {
        _qfcFontFamily = family;
        _qfcText = qfcText.isNotEmpty ? qfcText : null;
        _qfcFontLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    final results = await Future.wait([
      QuranAyahMetadataDb.instance.getVerseText(widget.surah, widget.ayah),
      VerseFavoritesService.instance.isFavorite(_verseKey),
    ]);
    final ar  = (results[0] as String?) ?? '';
    final fav = results[1] as bool;
    if (!mounted) return;
    setState(() {
      _verse = QVerse(
        verseKey: _verseKey,
        surah:    widget.surah,
        ayah:     widget.ayah,
        ar:       ar,
        fr:       '',
        tafsir:   null,
      );
      _isFavorite = fav;
      _loading    = false;
    });

    try {
      await QuranTranslationPackService.migrateLegacyToQulIfNeeded();
      final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
      if (verse != null && verse.fr.isNotEmpty && mounted) {
        setState(() => _verse = verse);
      } else {
        final ready = await QuranTranslationPackService.isPackReady(AppLang.fr);
        if (mounted && !ready) setState(() {});
      }
    } catch (_) {}

    if (!mounted) return;
    final hasLocal = _verse?.tafsir != null && _verse!.tafsir!.isNotEmpty;
    if (!hasLocal) {
      final prefs  = await SharedPreferences.getInstance();
      final cached = prefs.getString(_tafsirCacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() { _onlineTafsir = cached; _tafsirSaved = true; });
      } else {
        _fetchTafsir();
      }
    }
  }

  Future<void> _downloadPack() async {
    if (_packDownloading) return;
    _packCancelToken = CancelToken();
    setState(() { _packDownloading = true; _packProgress = 0; });
    try {
      await QuranTranslationPackService.downloadPack(
        AppLang.fr,
        cancelToken: _packCancelToken,
        onProgress: (p) { if (mounted) setState(() => _packProgress = p); },
      );
      final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
      if (!mounted) return;
      setState(() {
        _packDownloading = false;
        if (verse != null && verse.fr.isNotEmpty) _verse = verse;
      });
    } catch (_) {
      if (mounted) setState(() => _packDownloading = false);
    }
  }

  Future<void> _fetchTafsir() async {
    if (_tafsirLoading) return;
    _tafsirCancelToken?.cancel();
    _tafsirCancelToken = CancelToken();
    setState(() { _tafsirLoading = true; _onlineTafsir = null; });
    try {
      final res = await Dio().get(
        'https://api.quran.com/api/v4/tafsirs/$_tafsirId/by_ayah/$_verseKey',
        cancelToken: _tafsirCancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final raw = res.data['tafsir']['text'] as String? ?? '';
      final clean = raw
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r' {2,}'), ' ')
          .trim();
      if (!mounted) return;
      setState(() { _onlineTafsir = clean.isEmpty ? null : clean; _tafsirLoading = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() => _tafsirLoading = false);
    }
  }

  Future<void> _saveTafsirLocally() async {
    if (_tafsirSaving || _onlineTafsir == null) return;
    setState(() => _tafsirSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tafsirCacheKey, _onlineTafsir!);
      if (!mounted) return;
      setState(() { _tafsirSaved = true; _tafsirSaving = false; });
    } catch (_) {
      if (mounted) setState(() => _tafsirSaving = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final now = await VerseFavoritesService.instance.toggleFavorite(_verseKey);
    if (!mounted) return;
    setState(() => _isFavorite = now);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(now ? 'Ajouté aux favoris' : 'Retiré des favoris'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _copyVerse() async {
    final ar = _verse?.ar ?? '';
    final fr = _verse?.fr ?? '';
    await Clipboard.setData(ClipboardData(text: fr.isNotEmpty ? '$ar\n\n$fr' : ar));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Verset copié'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _scrollToTafsir() {
    final ctx = _tafsirKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _saveAsImage() async {
    try {
      if (!await FontDownloadService.areFontsDownloaded()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Téléchargement des polices en cours…'),
          duration: Duration(seconds: 10),
        ));
        await FontDownloadService.downloadAndExtractFonts();
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      final page = suraAyahToPage[widget.surah]?[widget.ayah] ?? 1;
      await FontDownloadService.loadFont(page);
      await FontDownloadService.loadSuraNameFont();
      final ayahFontFamily = 'QCF_P${page.toString().padLeft(3, '0')}';

      String ayahText = '';
      if (page >= 1 && page <= quranTextData.length) {
        final pageAyahs = _pageAyahsSorted(page);
        final index = pageAyahs.indexWhere(
          (e) => e['surah'] == widget.surah && e['ayah'] == widget.ayah,
        );
        if (index != -1 && index < quranTextData[page - 1].length) {
          ayahText = quranTextData[page - 1][index];
        }
      }
      if (ayahText.isEmpty) return;

      final surahGlyphChar = imageSuraGlyph[widget.surah] ?? '';
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const double width = 800.0;
      const double padding = 50.0;

      canvas.drawRect(const Rect.fromLTWH(0, 0, width, 2000), Paint()..color = Colors.white);

      final containerPainter = TextPainter(
        text: const TextSpan(text: '\u00F2',
            style: TextStyle(fontFamily: 'suraNameFont', fontSize: 80, color: Colors.black)),
        textDirection: TextDirection.rtl,
      );
      containerPainter.layout(maxWidth: width - padding * 2);
      containerPainter.paint(canvas, Offset((width - containerPainter.width) / 2, padding - 40));

      final namePainter = TextPainter(
        text: TextSpan(text: '\u005C$surahGlyphChar',
            style: const TextStyle(fontFamily: 'suraNameFont', fontSize: 50, color: Colors.black)),
        textDirection: TextDirection.rtl,
      );
      namePainter.layout(maxWidth: width - padding * 2);
      namePainter.paint(canvas, Offset((width - namePainter.width) / 2, padding));

      final double ayahY = padding + math.max(containerPainter.height, namePainter.height) + 50;
      final ayahPainter = TextPainter(
        text: TextSpan(text: ayahText,
            style: TextStyle(fontFamily: ayahFontFamily, fontSize: 49, color: Colors.black, height: 1.8)),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      ayahPainter.layout(maxWidth: width - padding * 2);
      ayahPainter.paint(canvas, Offset((width - ayahPainter.width) / 2, ayahY - 80));

      final double finalHeight = (ayahY + ayahPainter.height + padding) - 100;
      final picture  = recorder.endRecording();
      final img      = await picture.toImage(width.toInt(), finalHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer   = byteData!.buffer.asUint8List();

      final Directory? directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download/QuranPages')
          : await getDownloadsDirectory();
      if (directory != null && !await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = 'ayah_${widget.surah}_${widget.ayah}_${DateTime.now().millisecondsSinceEpoch}.png';
      await File('${directory?.path}/$fileName').writeAsBytes(buffer);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Image sauvegardée : $fileName'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    } on MissingPluginException catch (e) {
      debugPrint('MissingPluginException: $e');
    } catch (e) {
      debugPrint('Error saving ayah image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur de sauvegarde'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12182B) : const Color(0xFFFBF8F3);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _surahName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : const Color(0xFF1A0E00),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verset ${widget.ayah}  ·  Page ${suraAyahToPage[widget.surah]?[widget.ayah] ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ★ Favori
                  _CircleBtn(
                    icon: _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFD4AF37),
                    bgColor: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.15 : 0.1),
                    onTap: _toggleFavorite,
                  ),
                  const SizedBox(width: 8),
                  // ✕ Fermer
                  _CircleBtn(
                    icon: Icons.close_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                    bgColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Gold accent line ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Color(0x008B6C35),
                    Color(0xFFBFA878),
                    Color(0x008B6C35),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Contenu scrollable ───────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(scrollCtrl, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenu ──────────────────────────────────────────────────────────────────

  Widget _buildContent(ScrollController ctrl, bool isDark) {
    final theme      = Theme.of(context);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF555555);
    final divColor   = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      children: [
        if (_verse != null) ...[
          // ── Carte verset arabe ─────────────────────────────────
          _VerseCard(
            text: _qfcFontLoaded && _qfcText != null
                ? _qfcText!
                : sanitizeQulText(_verse!.ar),
            fontFamily: _qfcFontLoaded && _qfcText != null
                ? _qfcFontFamily!
                : 'UthmanTahaNaskh',
            fontSize: 22,
            ayah: widget.ayah,
            surahName: _surahName,
            page: suraAyahToPage[widget.surah]?[widget.ayah] ?? 1,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // ── Raccourcis ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.menu_book_rounded,
                  label: 'Tafsir',
                  color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF9A7B2F),
                  isDark: isDark,
                  onTap: _scrollToTafsir,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.copy_rounded,
                  label: 'Copier',
                  color: isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
                  isDark: isDark,
                  onTap: _copyVerse,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  color: isDark ? const Color(0xFF7986CB) : const Color(0xFF3949AB),
                  isDark: isDark,
                  onTap: _saveAsImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: divColor, height: 1),
          const SizedBox(height: 18),

          // ── Traduction française ───────────────────────────────
          if (_verse!.fr.isNotEmpty)
            Text(
              _verse!.fr,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.8, fontSize: 15, color: mutedColor,
              ),
            )
          else if (_packDownloading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _packProgress, minHeight: 3),
                const SizedBox(height: 8),
                Text(
                  'Téléchargement… ${(_packProgress * 100).toStringAsFixed(0)} %',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: _downloadPack,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Télécharger la traduction française'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const SizedBox(height: 28),
          Divider(color: divColor, height: 1),
          const SizedBox(height: 22),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.menu_book_outlined, size: 44, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Texte non disponible',
                  style: TextStyle(color: Colors.grey.shade500)),
            ]),
          ),
          Divider(color: divColor, height: 1),
          const SizedBox(height: 22),
        ],

        // ── Tafsir ─────────────────────────────────────────────
        _buildTafsirSection(isDark, theme),
      ],
    );
  }

  // ── Section tafsir ───────────────────────────────────────────────────────────

  Widget _buildTafsirSection(bool isDark, ThemeData theme) {
    final gold      = isDark ? const Color(0xFFD4AF37) : const Color(0xFF9A7B2F);
    final hasLocal  = _verse?.tafsir != null && _verse!.tafsir!.isNotEmpty;
    final displayText = hasLocal ? sanitizeQulText(_verse!.tafsir!) : _onlineTafsir;

    return Column(
      key: _tafsirKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 15, color: gold),
            const SizedBox(width: 6),
            Text('Tafsir',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: gold)),
            const Spacer(),
            if (!hasLocal)
              _TafsirSelector(
                selectedId: _tafsirId,
                isDark: isDark,
                gold: gold,
                onChanged: (id) async {
                  final prefs  = await SharedPreferences.getInstance();
                  final cached = prefs.getString('tafsir_${id}_$_verseKey');
                  setState(() {
                    _tafsirId    = id;
                    _onlineTafsir = cached;
                    _tafsirSaved  = cached != null && cached.isNotEmpty;
                  });
                  if (cached == null || cached.isEmpty) _fetchTafsir();
                },
              ),
            if (hasLocal) _SourceBadge(label: 'Qul · local', isDark: isDark),
            if (!hasLocal && displayText != null) ...[
              const SizedBox(width: 6),
              _DownloadBtn(
                saved:  _tafsirSaved,
                saving: _tafsirSaving,
                isDark: isDark,
                gold:   gold,
                onTap:  _tafsirSaved ? null : _saveTafsirLocally,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_tafsirLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: gold),
              ),
            ),
          )
        else if (displayText != null && displayText.isNotEmpty)
          SelectableText(
            displayText,
            style: TextStyle(
              height: 1.85, fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF555555),
            ),
          )
        else
          Text(
            'Tafsir non disponible pour ce verset.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Widgets helpers
// ════════════════════════════════════════════════════════════════════════════════

/// Bouton rapide avec icône + label centré (Tafsir / Copier / Image)
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.12 : 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton circulaire (header : favori, fermer)
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

/// Badge source (Qul · local)
class _SourceBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SourceBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : const Color(0xFF888888),
        ),
      ),
    );
  }
}

/// Sélecteur de source de tafsir
class _TafsirSelector extends StatelessWidget {
  final int selectedId;
  final bool isDark;
  final Color gold;
  final void Function(int) onChanged;

  const _TafsirSelector({
    required this.selectedId,
    required this.isDark,
    required this.gold,
    required this.onChanged,
  });

  static const _options = [
    _TafsirOption(id: 14,  label: 'Ibn Kathir (ar)'),
    _TafsirOption(id: 169, label: 'Ibn Kathir (en)'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _options.firstWhere(
      (o) => o.id == selectedId,
      orElse: () => _options.first,
    );

    return PopupMenuButton<int>(
      onSelected: onChanged,
      color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => _options.map((o) => PopupMenuItem<int>(
        value: o.id,
        child: Row(children: [
          if (o.id == selectedId)
            Icon(Icons.check_rounded, size: 14, color: gold)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Text(o.label, style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : const Color(0xFF333333),
          )),
        ]),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.label, style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : const Color(0xFF888888),
            )),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF888888)),
          ],
        ),
      ),
    );
  }
}

class _TafsirOption {
  final int id;
  final String label;
  const _TafsirOption({required this.id, required this.label});
}

/// Bouton sauvegarde hors-ligne du tafsir
class _DownloadBtn extends StatelessWidget {
  final bool saved;
  final bool saving;
  final bool isDark;
  final Color gold;
  final VoidCallback? onTap;

  const _DownloadBtn({
    required this.saved,
    required this.saving,
    required this.isDark,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return SizedBox(
        width: 28, height: 28,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2, color: gold),
        ),
      );
    }
    if (saved) {
      return Tooltip(
        message: 'Disponible hors-ligne',
        child: Icon(Icons.download_done_rounded, size: 18, color: gold),
      );
    }
    return Tooltip(
      message: 'Sauvegarder pour hors-ligne',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.download_outlined, size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

// ── Carte verset (Arabic) ──────────────────────────────────────────────────────

class _VerseCard extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final int ayah;
  final String surahName;
  final int page;
  final bool isDark;

  const _VerseCard({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.ayah,
    required this.surahName,
    required this.page,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg   = isDark ? const Color(0xFF1C2333) : const Color(0xFFFAF6EE);
    final footerBg = isDark ? const Color(0xFF141B2A) : const Color(0xFFF0E8D5);
    const goldColor = Color(0xFFBFA878);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldColor.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Liseré doré haut
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0x008B6C35), Color(0xFFBFA878), Color(0x008B6C35),
              ]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          // Texte arabe
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize,
                height: 1.75,
                color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1A0E),
              ),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),
          ),
          // Pied : sourate + page
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: footerBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 13, color: goldColor),
                    const SizedBox(width: 4),
                    Text(surahName, style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 15,
                      color: isDark ? const Color(0xFFBFA878) : const Color(0xFF6B4510),
                    )),
                  ],
                ),
                Text('Page $page', style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nettoyage texte brut ───────────────────────────────────────────────────────

String sanitizeQulText(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s.replaceAll(
      RegExp(r'\b(rule|class|slnt|wght|wdth)\b[^ \n]*', caseSensitive: false), '');
  s = s.replaceAll('\u200C', '');
  s = s.replaceAll('\u200D', '');
  s = s.replaceAll('\u200E', '');
  s = s.replaceAll('\u200F', '');
  s = s.replaceAll('\u200B', '');
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
