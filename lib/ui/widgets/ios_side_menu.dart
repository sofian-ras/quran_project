import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'reciter_selector.dart';
import '../../services/audio_service.dart';
import '../../theme/app_theme.dart';
import '../downloads_screen.dart';
import '../favorites_screen.dart';
import '../statistics_screen.dart';
import '../../theme/theme_service.dart';
import '../bookmarks_screen.dart';
import '../settings_screen.dart';
import '../reading_history_screen.dart';


class IOSSideMenu extends StatelessWidget {
  const IOSSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? const Color(0xFFFDFCF9) : const Color(0xFF1A0B3D);
    final Color subTextColor = isDark ? Colors.white70 : const Color(0xFF4B3B7A);
    final Color accentPrimary = isDark ? const Color(0xFFFFD93D) : const Color(0xFFFF6B3D);
    final Color accentSecondary = const Color(0xFF2BB6FF);
    final Color accentTertiary = isDark ? const Color(0xFFFF6EC7) : const Color(0xFFFFD93D);
    final Color iconColor = accentPrimary;
    final Color tileHover = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B0F2A).withOpacity(0.98),
                  const Color(0xFF3A0F5C).withOpacity(0.95),
                  const Color(0xFF0F4C6B).withOpacity(0.94),
                  const Color(0xFF0A6F7A).withOpacity(0.92),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF0B3),
                  Color(0xFFFFC9D9),
                  Color(0xFFC9F2FF),
                  Color(0xFFD4FFB3),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
      ),

          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header premium avec effet ajusté pour le mode clair
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentSecondary.withOpacity(isDark ? 0.25 : 0.45),
                        accentTertiary.withOpacity(isDark ? 0.20 : 0.40),
                        accentPrimary.withOpacity(isDark ? 0.22 : 0.35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 2,
                      color: accentPrimary.withOpacity(isDark ? 0.45 : 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentPrimary.withOpacity(isDark ? 0.35 : 0.5),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icône premium ajustée
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentPrimary,
                              accentTertiary,
                              accentSecondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentPrimary.withOpacity(isDark ? 0.6 : 0.7),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/logo_coran.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                CupertinoIcons.book_fill,
                                color: iconColor, // Couleur des icônes encore plus foncées
                                size: 28,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'القرآن الكريم',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor, // Couleur du texte principal encore plus foncée
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                                letterSpacing: 0.5,
                                shadows: isDark
                                    ? [
                                        Shadow(
                                          color: accentPrimary.withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Coran Premium',
                              style: TextStyle(
                                fontSize: 9,
                                color: subTextColor, // Couleur du texte secondaire encore plus foncée
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                            ? accentPrimary.withOpacity(isDark ? 0.25 : 0.35)
                            : (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.45));

                        final fg = selected ? textColor : (isDark ? Colors.white70 : const Color(0xFF3B2B6B));

                        return Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            borderRadius: BorderRadius.circular(14),
                            color: bg,
                            onPressed: () {
                              ThemeService.setTheme(value);
                            },
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


                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.transparent,
                                accentSecondary.withValues(alpha: 0.12),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.75),
                                accentSecondary.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.55),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: accentPrimary.withValues(alpha: isDark ? 0.25 : 0.45),
                        width: 1.5,
                      ),
                    ),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                          children: [
                            // Coran Section
                            _MenuSection(
                              icon: CupertinoIcons.book_fill,
                              title: 'Coran',
                              subtitle: 'Lecture et récitation',
                              onTap: () => Navigator.pop(context),
                            ),
                            
                            // Favoris Section
                            _MenuSection(
                              icon: CupertinoIcons.heart_fill,
                              title: 'Favoris',
                              subtitle: 'Vos sourates préférées',
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
                            
                            // Statistiques Section
                            _MenuSection(
                              icon: CupertinoIcons.chart_bar_alt_fill,
                              title: 'Statistiques',
                              subtitle: 'Vos progrès et historique',
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
                            
                            // Marque-pages Section
                            _MenuSection(
                              icon: CupertinoIcons.bookmark_fill,
                              title: 'Marque-pages',
                              subtitle: 'Pages sauvegardées',
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
                            
                            // Écouter Section
                            _MenuSection(
                              icon: CupertinoIcons.music_note_2,
                              title: 'Écouter',
                              subtitle: 'Récitateurs et audio',
                              trailing: ValueListenableBuilder<String>(
                                valueListenable: AudioService.instance.currentReciterNotifier,
                                builder: (context, reciter, _) => Text(
                                  reciter,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
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

                            // Hadith Section (Coming Soon)
                            _MenuSection(
                              icon: CupertinoIcons.book,
                              title: 'Hadith',
                              subtitle: 'Bientôt disponible',
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentTertiary,
                                      accentPrimary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentPrimary.withOpacity(0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
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

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentSecondary,
                                          accentPrimary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PRÉFÉRENCES',
                                    style: TextStyle(
                                      color: accentPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            // Historique
                            _MenuSection(
                              icon: CupertinoIcons.clock_fill,
                              title: 'Historique',
                              subtitle: 'Lectures récentes',
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


                            // Téléchargements
                            _MenuSection(
                              icon: CupertinoIcons.arrow_down_circle,
                              title: 'Téléchargements',
                              subtitle: 'Gérer les fichiers',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DownloadsScreen(),
                                  ),
                                );
                              },
                            ),

                            // Paramètres
                            _MenuSection(
                              icon: CupertinoIcons.settings,
                              title: 'Paramètres',
                              subtitle: 'Personnalisation',
                              onTap: () {
                                Navigator.pop(context);
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                    );
                                  }
                                });
                              },
                            ),


                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentSecondary,
                                          accentPrimary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'INFORMATIONS',
                                    style: TextStyle(
                                      color: accentPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // À propos
                            _MenuSection(
                              icon: CupertinoIcons.info_circle_fill,
                              title: 'À propos',
                              subtitle: 'Version et crédits',
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
            onPressed: () => Navigator.pop(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentPrimary = isDark ? const Color(0xFFFFD93D) : const Color(0xFFFF6B3D);
    final accentSecondary = const Color(0xFF2BB6FF);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A0B3D);
    final subColor = isDark ? Colors.white70 : const Color(0xFF4B3B7A);
    final tileBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75);
    final tileBorder = accentPrimary.withOpacity(isDark ? 0.35 : 0.6);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(0, 0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tileBorder, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accentSecondary.withOpacity(isDark ? 0.2 : 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône iOS simple
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentSecondary,
                    accentPrimary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentPrimary.withOpacity(isDark ? 0.5 : 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: isDark ? const Color(0xFF0B0F2A) : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
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
                  gradient: LinearGradient(
                    colors: [
                      accentSecondary.withValues(alpha: 0.35),
                      accentPrimary.withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: accentPrimary.withValues(alpha: 0.9),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
