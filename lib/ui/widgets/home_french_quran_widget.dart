import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/quran_translation_pack_service.dart';
import '../screens/translated_quran_screen.dart';

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
          color: Colors.black.withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3D1F).withOpacity(0.45),
            blurRadius: 12,
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
                      const Color(0xFF0B3D1F).withOpacity(0.85),
                      const Color(0xFF0F5A2A).withOpacity(0.85),
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

                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final titleColor = isDark ? Colors.white : const Color(0xFF1B1205);
                    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5B4A2F);
                    final iconColor = isDark ? Colors.white : const Color(0xFF1B1205);

                    final mode = await showModalBottomSheet<_FrenchMode>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: isDark ? const Color(0xFF0F1734) : const Color(0xFFFFFFFF),
                      builder: (ctx) {
                        final optionBg = isDark ? const Color(0xFF141B3A) : const Color(0xFFFFF7EA);
                        final optionBorder =
                            isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
                        final accent = isDark ? const Color(0xFFE3C880) : const Color(0xFF1E3A2F);

                        Widget optionTile({
                          required IconData icon,
                          required String title,
                          required String subtitle,
                          required _FrenchMode mode,
                        }) {
                          return Material(
                            color: optionBg,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pop(ctx, mode),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: optionBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(isDark ? 0.2 : 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(icon, color: accent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              color: titleColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: TextStyle(color: subtitleColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: subtitleColor),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.menu_book_rounded, color: iconColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Coran traduction',
                                      style: TextStyle(
                                        color: titleColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Choisis le mode de lecture',
                                  style: TextStyle(color: subtitleColor),
                                ),
                                const SizedBox(height: 14),
                                optionTile(
                                  icon: Icons.wifi_rounded,
                                  title: 'Lire en ligne',
                                  subtitle: 'Pas de telechargement, rapide',
                                  mode: _FrenchMode.online,
                                ),
                                const SizedBox(height: 10),
                                optionTile(
                                  icon: Icons.download_rounded,
                                  title: 'Lire hors-ligne',
                                  subtitle: 'Telecharger traduction + tafsir une seule fois',
                                  mode: _FrenchMode.offline,
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
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final titleColor = isDark ? Colors.white : const Color(0xFF1B1205);
                  final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5B4A2F);
                  final iconColor = isDark ? Colors.white : const Color(0xFF1B1205);

                  final mode = await showModalBottomSheet<_FrenchMode>(
                    context: context,
                    showDragHandle: true,
                    backgroundColor: isDark ? const Color(0xFF0F1734) : const Color(0xFFFFFFFF),
                    builder: (ctx) {
                      final optionBg = isDark ? const Color(0xFF141B3A) : const Color(0xFFFFF7EA);
                      final optionBorder =
                          isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
                      final accent = isDark ? const Color(0xFFE3C880) : const Color(0xFF1E3A2F);

                      Widget optionTile({
                        required IconData icon,
                        required String title,
                        required String subtitle,
                        required _FrenchMode mode,
                      }) {
                        return Material(
                          color: optionBg,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(ctx, mode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: optionBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon, color: accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: TextStyle(color: subtitleColor, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: subtitleColor),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SafeArea(

                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(
                                  'Lire en ligne',
                                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text('Pas de tÃ©lÃ©chargement, rapide'),
                                leading: Icon(Icons.wifi_rounded, color: iconColor),
                                onTap: () => Navigator.pop(ctx, _FrenchMode.online),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                title: Text(
                                  'Lire hors-ligne',
                                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text('TÃ©lÃ©charger traduction + tafsir une seule fois'),
                                leading: Icon(Icons.download_rounded, color: iconColor),
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
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
