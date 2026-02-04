import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'reciter_selector.dart';
import '../../services/audio_service.dart';
import '../downloads_screen.dart';
import '../favorites_screen.dart';
import '../statistics_screen.dart';
import '../../theme/theme_service.dart';
import '../bookmarks_screen.dart';
import '../settings_screen.dart';
import '../reading_history_screen.dart';

class IOSSideMenu extends StatelessWidget {
  final VoidCallback? onSettingsClosed;

  const IOSSideMenu({super.key, this.onSettingsClosed});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // LIGHT palette
    const Color baseBlueLight = Color(0xFF1E5AA8);
    const Color deepLightA = Color(0xFF0B1B33);
    const Color deepLightB = Color(0xFF123B73);
    const Color deepLightC = Color(0xFF1E5AA8);
    const Color glassLight = Color(0x1AFFFFFF);
    const Color glass2Light = Color(0x26FFFFFF);
    const Color borderLight = Color(0x33FFFFFF);
    const Color textLight = Color(0xFFF4F7FF);
    const Color textMutedLight = Color(0xFFB8C6E6);

    // DARK palette (different)
    const Color baseBlueDark = Color(0xFF3B82F6);
    const Color deepDarkA = Color(0xFF050B16);
    const Color deepDarkB = Color(0xFF0B1733);
    const Color deepDarkC = Color(0xFF102B57);
    const Color glassDark = Color(0x14121A2A);
    const Color glass2Dark = Color(0x1F121A2A);
    const Color borderDark = Color(0x2A3B82F6);
    const Color textDark = Color(0xFFEAF0FF);
    const Color textMutedDark = Color(0xFF9FB2D8);

    final Color baseBlue = isDark ? baseBlueDark : baseBlueLight;
    final Color glass = isDark ? glassDark : glassLight;
    final Color glass2 = isDark ? glass2Dark : glass2Light;
    final Color border = isDark ? borderDark : borderLight;
    final Color text = isDark ? textDark : textLight;
    final Color textMuted = isDark ? textMutedDark : textMutedLight;

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [deepDarkA, deepDarkB, deepDarkC]
              : const [deepLightA, deepLightB, deepLightC],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        border: Border.all(color: border, width: 1.2),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (sans encadré, juste halo de lumière)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: baseBlue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/logo_quranv2.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.book_fill,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Quran',
                      style: TextStyle(
                        fontSize: 22,
                        color: text,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Theme chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.themeMode,
                builder: (context, mode, _) {
                  bool isSelected(ThemeMode m) => mode == m;

                  Widget chip({
                    required IconData icon,
                    required String label,
                    required ThemeMode value,
                  }) {
                    final selected = isSelected(value);
                    final bg = selected
                        ? (isDark ? const Color(0xFF0E1A33) : Colors.white)
                        : glass;
                    final fg = selected ? baseBlue : (isDark ? text : const Color(0xFF6A7B91));

                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? baseBlue.withOpacity(0.8) : border,
                            width: 1.2,
                          ),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.transparent,
                          onPressed: () => ThemeService.setTheme(value),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 16, color: fg),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      chip(icon: CupertinoIcons.sun_max_fill, label: 'Clair', value: ThemeMode.light),
                      const SizedBox(width: 8),
                      chip(icon: CupertinoIcons.moon_fill, label: 'Sombre', value: ThemeMode.dark),
                      const SizedBox(width: 8),
                      chip(icon: CupertinoIcons.device_phone_portrait, label: 'Système', value: ThemeMode.system),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // List (glass panel)
            Flexible(
              fit: FlexFit.loose,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: glass2,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border, width: 1.2),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _MenuSection(
                          icon: CupertinoIcons.book_fill,
                          title: 'Coran',
                          subtitle: 'Lecture et récitation',
                          trailing: null,
                          onTap: () => Navigator.pop(context),
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.heart_fill,
                          title: 'Favoris',
                          subtitle: 'Vos sourates préférées',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                                );
                              }
                            });
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.chart_bar_alt_fill,
                          title: 'Statistiques',
                          subtitle: 'Vos progrès et historique',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                                );
                              }
                            });
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.bookmark_fill,
                          title: 'Marque-pages',
                          subtitle: 'Pages sauvegardées',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                                );
                              }
                            });
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.music_note_2,
                          title: 'Écouter',
                          subtitle: 'Récitateurs et audio',
                          trailing: ValueListenableBuilder<String>(
                            valueListenable: AudioService.instance.currentReciterNotifier,
                            builder: (context, reciter, _) => Text(
                              reciter,
                              style: TextStyle(
                                color: text,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ReciterSelectorSheet(
                                    onSelected: (name, server) {
                                      AudioService.instance.setReciter(name, server);
                                    },
                                  ),
                                );
                              }
                            });
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.book,
                          title: 'Hadith',
                          subtitle: 'Bientôt disponible',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: baseBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'BIENTÔT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fonctionnalité bientôt disponible'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        _SectionLabel(
                          title: 'PRÉFÉRENCES',
                          color: baseBlue,
                          textColor: text,
                        ),
                        const SizedBox(height: 10),

                        _MenuSection(
                          icon: CupertinoIcons.clock_fill,
                          title: 'Historique',
                          subtitle: 'Lectures récentes',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
                                );
                              }
                            });
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.arrow_down_circle,
                          title: 'Téléchargements',
                          subtitle: 'Gérer les fichiers',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                            );
                          },
                        ),

                        _MenuSection(
                          icon: CupertinoIcons.settings,
                          title: 'Paramètres',
                          subtitle: 'Personnalisation',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                ).then((_) {
                                  if (!context.mounted) return;
                                  onSettingsClosed?.call();
                                });
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 12),

                        _SectionLabel(
                          title: 'INFORMATIONS',
                          color: baseBlue,
                          textColor: text,
                        ),
                        const SizedBox(height: 10),

                        _MenuSection(
                          icon: CupertinoIcons.info_circle_fill,
                          title: 'À propos',
                          subtitle: 'Version et crédits',
                          trailing: null,
                          onTap: () {
                            Navigator.pop(context);
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('القرآن الكريم'),
        content: const Column(
          children: [
            SizedBox(height: 10),
            Text('Version 1.0.0'),
            SizedBox(height: 10),
            Text(
              'Une application dédiée à la lecture et l\'écoute du Noble Coran.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 10),
            Text(
              'Audio fourni par mp3quran.net',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Fermer'),
            onPressed: null,
          ),
        ],
      ),
    );

    // Keep your original behavior
    // ignore: unused_result
    Future.delayed(Duration.zero);
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Color color;
  final Color textColor;

  const _SectionLabel({
    required this.title,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color baseBlue = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E5AA8);
    final Color glass = isDark ? const Color(0x14121A2A) : const Color(0x1AFFFFFF);
    final Color border = isDark ? const Color(0x2A3B82F6) : const Color(0x33FFFFFF);
    final Color text = isDark ? const Color(0xFFEAF0FF) : const Color(0xFFF4F7FF);
    final Color textMuted = isDark ? const Color(0xFF9FB2D8) : const Color(0xFFB8C6E6);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(0, 0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: baseBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: baseBlue.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDark ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: text,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
