import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/quran_translation_pack_service.dart';
import '../translated_quran_screen.dart';

enum _FrenchMode { online, offline }

// Widget Coran en franÃ§ais
class FrenchQuranWidget extends StatelessWidget {
  const FrenchQuranWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1F8F4A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F8F4A).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Image en arriÃ¨re-plan
            Positioned.fill(
              child: Image.asset(
                'assets/icon/logo_coran.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1a0033),
                  );
                },
              ),
            ),
            // Overlay gradient semi-transparent
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0B3D1F).withOpacity(0.78),
                      const Color(0xFF0F5A2A).withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Contenu
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () async {
                  {
                    final langCode = Localizations.localeOf(context).languageCode.toLowerCase();
                    final lang = langCode.startsWith('en') ? AppLang.en : AppLang.fr;

                    final ready = await QuranTranslationPackService.isPackReady(lang);
                    if (ready) {
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TranslatedQuranScreen(preferOffline: true),
                        ),
                      );
                      return;
                    }

                    final mode = await showModalBottomSheet<_FrenchMode>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('Lire en ligne'),
                                  subtitle: const Text('Pas de telechargement, rapide'),
                                  leading: const Icon(Icons.wifi_rounded),
                                  onTap: () => Navigator.pop(ctx, _FrenchMode.online),
                                ),
                                const SizedBox(height: 8),
                                ListTile(
                                  title: const Text('Lire hors-ligne'),
                                  subtitle: const Text('Telecharger traduction + tafsir une seule fois'),
                                  leading: const Icon(Icons.download_rounded),
                                  onTap: () => Navigator.pop(ctx, _FrenchMode.offline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    if (mode == null) return;

                    if (mode == _FrenchMode.online) {
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TranslatedQuranScreen(preferOffline: false),
                        ),
                      );
                      return;
                    }

                    final progress = ValueNotifier<double>(0.0);
                    final cancelToken = CancelToken();
                    bool canceled = false;

                    showModalBottomSheet<void>(
                      context: context,
                      isDismissible: false,
                      enableDrag: false,
                      showDragHandle: false,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0F1734)
                          : const Color(0xFFFFFFFF),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (sheetContext) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            child: ValueListenableBuilder<double>(
                              valueListenable: progress,
                              builder: (_, p01, __) {
                                final pct = (p01 * 100).toStringAsFixed(0);
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang == AppLang.fr ? 'Telechargement' : 'Downloading',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      lang == AppLang.fr
                                          ? 'Telechargement du pack (traduction + tafsir)...'
                                          : 'Downloading pack (translation + tafsir)...',
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: p01,
                                        minHeight: 12,
                                        backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.18),
                                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFFFFF)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '$pct%',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          canceled = true;
                                          cancelToken.cancel('User canceled');
                                          Navigator.pop(sheetContext);
                                        },
                                        child: Text(lang == AppLang.fr ? 'Annuler' : 'Cancel'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );

                    try {
                      await QuranTranslationPackService.downloadPack(
                        lang,
                        onProgress: (p01) => progress.value = p01,
                        cancelToken: cancelToken,
                      );
                    } on DioException catch (_) {
                      // ignore cancels
                    } finally {
                      progress.dispose();
                      if (!canceled && context.mounted) {
                        Navigator.pop(context);
                      }
                    }

                    if (canceled) return;
                    final readyAfter = await QuranTranslationPackService.isPackReady(lang);
                    if (!readyAfter) return;
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TranslatedQuranScreen(preferOffline: true),
                      ),
                    );
                    return;
                  }
                  final mode = await showModalBottomSheet<_FrenchMode>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('Lire en ligne'),
                                subtitle: const Text('Pas de tÃ©lÃ©chargement, rapide'),
                                leading: const Icon(Icons.wifi_rounded),
                                onTap: () => Navigator.pop(ctx, _FrenchMode.online),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                title: const Text('Lire hors-ligne'),
                                subtitle: const Text('TÃ©lÃ©charger traduction + tafsir une seule fois'),
                                leading: const Icon(Icons.download_rounded),
                                onTap: () => Navigator.pop(ctx, _FrenchMode.offline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  if (mode == null) return;

                  if (mode == _FrenchMode.offline) {
                    // Langue (pour lâ€™instant: langue du tÃ©lÃ©phone)
                    final langCode = Localizations.localeOf(context).languageCode.toLowerCase();
                    final lang = langCode.startsWith('en') ? AppLang.en : AppLang.fr;

                    final ready = await QuranTranslationPackService.isPackReady(lang);

                    if (!ready) {
                      /*
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(lang == AppLang.fr ? 'Mode hors-ligne' : 'Offline mode'),
                          content: Text(
                            lang == AppLang.fr
                                ? 'Pour lire hors connexion, il faut tÃ©lÃ©charger le pack (traduction + tafsir).'
                                : 'To read offline, you need to download the pack (translation + tafsir).',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(lang == AppLang.fr ? 'Annuler' : 'Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(lang == AppLang.fr ? 'TÃ©lÃ©charger' : 'Download'),
                            ),
                          ],
                        ),
                      );

                      */
                      final progress = ValueNotifier<double>(0.0);
                      final cancelToken = CancelToken();
                      bool canceled = false;

                      showModalBottomSheet<void>(
                        context: context,
                        isDismissible: false,
                        enableDrag: false,
                        showDragHandle: false,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F1734)
                            : const Color(0xFFFFFFFF),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) {
                          return SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: ValueListenableBuilder<double>(
                                valueListenable: progress,
                                builder: (_, p01, __) {
                                  final pct = (p01 * 100).toStringAsFixed(0);
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang == AppLang.fr ? 'TÃ‡Â¸lÃ‡Â¸chargement' : 'Downloading',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        lang == AppLang.fr
                                            ? 'TÃ‡Â¸lÃ‡Â¸chargement du pack (traduction + tafsir)...'
                                            : 'Downloading pack (translation + tafsir)...',
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: p01,
                                          minHeight: 12,
                                          backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.18),
                                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFFFFF)),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '$pct%',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            canceled = true;
                                            cancelToken.cancel('User canceled');
                                            Navigator.pop(context);
                                          },
                                          child: Text(lang == AppLang.fr ? 'Annuler' : 'Cancel'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );

                      /*
                      // showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Text(lang == AppLang.fr ? 'TÃ©lÃ©chargementâ€¦' : 'Downloadingâ€¦'),
                          content: ValueListenableBuilder<double>(
                            valueListenable: progress,
                            builder: (_, p01, __) {
                              final pct = (p01 * 100).toStringAsFixed(0);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Ø§Ù„Ù‚Ø±Ø¢Ù† Ø§Ù„ÙƒØ±ÙŠÙ…', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: p01,
                                      minHeight: 12,
                                      backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.18),
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFFFFFF)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1a0033),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      // );
                      */

                      try {
                        await QuranTranslationPackService.downloadPack(
                          lang,
                          onProgress: (p01) => progress.value = p01,
                          cancelToken: cancelToken,
                        );
                      } on DioException catch (_) {
                        // ignore cancels
                      } finally {
                        progress.dispose();
                        if (!canceled && context.mounted) Navigator.pop(context); // ferme la popup
                      }
                    }

                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TranslatedQuranScreen(preferOffline: true),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TranslatedQuranScreen(preferOffline: false)),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Coran traduction',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Color(0xFF7A5A12), blurRadius: 6, offset: Offset(1, 1)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
