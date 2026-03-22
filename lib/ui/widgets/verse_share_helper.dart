import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/quran_text_db.dart';
import '../../surah_name.dart';

/// Génère l'image du verset et ouvre le partage natif.
Future<void> shareVerseAsImage({
  required BuildContext context,
  required int surah,
  required int ayah,
}) async {
  final verse = await QuranTextDb.instance.getVerseByKey('$surah:$ayah');
  if (verse == null) return;

  final name = surahFr[surah] ?? 'Sourate $surah';

  final bytes = await captureVerseCard(
    context: context,
    surah: surah,
    ayah: ayah,
    arabicText: verse.ar,
    frenchText: verse.fr,
    surahNameFr: name,
  );

  if (bytes == null) return;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/verset_${surah}_$ayah.png');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    subject: '$name — verset $ayah',
  );
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
  await Future.delayed(const Duration(milliseconds: 500));

  List<int>? result;
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      result = byteData?.buffer.asUint8List();
    }
  } catch (_) {}

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
