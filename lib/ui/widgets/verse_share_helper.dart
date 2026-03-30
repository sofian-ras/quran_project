import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/quran_text_db.dart';
import '../../services/quran_translation_pack_service.dart';
import '../../data/surah_name.dart';

/// Affiche un bottom sheet proposant de télécharger la traduction.
/// Retourne true si le téléchargement a réussi.
Future<bool> showTranslationDownloadSheet(BuildContext context) async {
  return await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F1734)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    isDismissible: true,
    builder: (_) => const _TranslationDownloadSheet(),
  ) ?? false;
}

class _TranslationDownloadSheet extends StatefulWidget {
  const _TranslationDownloadSheet();
  @override
  State<_TranslationDownloadSheet> createState() => _TranslationDownloadSheetState();
}

class _TranslationDownloadSheetState extends State<_TranslationDownloadSheet> {
  bool _downloading = false;
  double _progress = 0;
  CancelToken? _cancelToken;

  Future<void> _download() async {
    if (_downloading) return;
    _cancelToken = CancelToken();
    setState(() { _downloading = true; _progress = 0; });
    try {
      await QuranTranslationPackService.downloadPack(
        AppLang.fr,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC8A165);
    final titleColor = isDark ? Colors.white : const Color(0xFF1a0033);
    final subColor = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 40, color: gold),
            const SizedBox(height: 12),
            Text(
              'Traduction non téléchargée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le pack de traduction est requis pour copier ou partager des versets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_downloading) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: gold,
                backgroundColor: gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                _progress > 0 ? '${(_progress * 100).round()} %' : 'Téléchargement...',
                style: TextStyle(color: subColor, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _cancelToken?.cancel();
                  if (mounted) Navigator.pop(context, false);
                },
                child: Text('Annuler', style: TextStyle(color: subColor)),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Télécharger'),
                  style: FilledButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Plus tard', style: TextStyle(color: subColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Génère l'image du verset et ouvre le partage natif.
/// Retourne true si le partage a été lancé avec succès.
Future<bool> shareVerseAsImage({
  required BuildContext context,
  required int surah,
  required int ayah,
}) async {
  var verse = await QuranTextDb.instance.getVerseByKey('$surah:$ayah');
  if (verse == null) {
    if (!context.mounted) return false;
    final downloaded = await showTranslationDownloadSheet(context);
    if (!downloaded || !context.mounted) return false;
    verse = await QuranTextDb.instance.getVerseByKey('$surah:$ayah');
    if (verse == null) return false;
  }

  final name = surahFr[surah] ?? 'Sourate $surah';

  final bytes = await captureVerseCard(
    context: context,
    surah: surah,
    ayah: ayah,
    arabicText: verse.ar,
    frenchText: verse.fr,
    surahNameFr: name,
  );

  if (bytes == null) return false;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/verset_${surah}_$ayah.png');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    subject: '$name — verset $ayah',
  );
  return true;
}

/// Capture le widget [VerseShareCard] hors-écran et retourne les bytes PNG.
Future<List<int>?> captureVerseCard({
  required BuildContext context,
  required int surah,
  required int ayah,
  required String arabicText,
  required String frenchText,
  required String surahNameFr,
}) async {
  if (!context.mounted) return null;

  final key = GlobalKey();
  OverlayEntry? entry;

  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -5000,
      top: 0,
      child: SizedBox(
        width: 360,
        child: RepaintBoundary(
          key: key,
          child: VerseShareCard(
            surah: surah,
            ayah: ayah,
            arabicText: arabicText,
            frenchText: frenchText,
            surahNameFr: surahNameFr,
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(entry);

  // Attendre plusieurs frames pour que le widget soit construit ET que les
  // assets asynchrones (SvgPicture, Image.asset) aient fini de se rendre.
  for (int i = 0; i < 5; i++) {
    await WidgetsBinding.instance.endOfFrame;
  }
  await Future.delayed(const Duration(milliseconds: 200));

  List<int>? result;
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      result = byteData?.buffer.asUint8List();
    }
  } catch (e) {
    debugPrint('[captureVerseCard] erreur capture: $e');
  }

  entry.remove();
  return result;
}

// ── Carte de partage ──────────────────────────────────────────────────────────

class VerseShareCard extends StatelessWidget {
  final int surah;
  final int ayah;
  final String arabicText;
  final String frenchText;
  final String surahNameFr;

  const VerseShareCard({
    super.key,
    required this.surah,
    required this.ayah,
    required this.arabicText,
    required this.frenchText,
    required this.surahNameFr,
  });

  static String cleanArabic(String raw) => raw
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'[\s\u0660-\u0669\u06F0-\u06F9]+$'), '')
      .trim();

  static String _indic(int v) {
    const m = {
      '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
      '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
    };
    return v.toString().split('').map((d) => m[d] ?? d).join();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3E8C0);
    const textAr = Color(0xFF2D1B00);
    const textFr = Color(0xFF4A3F30);
    const gold = Color(0xFFC8A97E);
    const attr = Color(0xFF8B6C35);

    final clean = cleanArabic(arabicText);

    return Material(
      color: Colors.transparent,
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Entête calligraphiée ──────────────────────────────────
            LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                final h = w * 67 / 624;
                return SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/Translated_Quran/entete_verte.webp',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: h * 0.12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/images/Translated_Quran/surah_svg/$surah.svg',
                              height: h * 0.68,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                            const SizedBox(width: 2),
                            SvgPicture.asset(
                              'assets/images/Translated_Quran/surah_svg/0. surah.svg',
                              height: h * 0.68,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            // ── Texte arabe + numéro de verset ───────────────────────
            RichText(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 22,
                  color: textAr,
                  height: 1.9,
                ),
                children: [
                  TextSpan(text: clean),
                  TextSpan(
                    text: ' ﴿${_indic(ayah)}﴾',
                    style: const TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Séparateur doré ───────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider(color: gold, thickness: 0.8)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: gold, thickness: 0.8)),
              ],
            ),

            const SizedBox(height: 14),

            // ── Traduction française ──────────────────────────────────
            Text(
              frenchText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: textFr,
                height: 1.65,
              ),
            ),

            const SizedBox(height: 16),

            // ── Attribution ───────────────────────────────────────────
            Text(
              '— $surahNameFr',
              style: const TextStyle(
                fontSize: 11,
                color: attr,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
