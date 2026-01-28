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
    final Color textColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1A1A1A);
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color iconColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8A6A1F);
    final Color tileHover = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF020617).withOpacity(0.96),
                  const Color(0xFF0B1025).withOpacity(0.94),
                  const Color(0xFF1A0033).withOpacity(0.92),
                  const Color(0xFF2D1B4E).withOpacity(0.92),
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFDFDFD),
                  const Color(0xFFF7F2E8),
                  const Color(0xFFEDEAE0),
                ],
                stops: const [0.0, 0.6, 1.0],
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
                      colors: isDark
                          ? [
                              const Color(0xFFD4AF37).withOpacity(0.15),
                              const Color(0xFFC9A65C).withOpacity(0.1),
                              const Color(0xFF8B7355).withOpacity(0.05),
                            ]
                          : [
                              const Color(0xFFFDFDFD),
                              const Color(0xFFEDEAE0),
                              const Color(0xFFDAD5C4),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: 1.5,
                      color: isDark
                          ? const Color(0xFFD4AF37).withOpacity(0.3)
                          : const Color(0xFFB0A895),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0xFFD4AF37).withOpacity(0.2)
                            : const Color(0xFFB0A895).withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                            colors: isDark
                                ? [
                                    const Color(0xFFFFD700),
                                    const Color(0xFFD4AF37),
                                    const Color(0xFFC9A65C),
                                  ]
                                : [
                                    const Color(0xFFEDEAE0),
                                    const Color(0xFFDAD5C4),
                                    const Color(0xFFB0A895),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFFD4AF37).withOpacity(0.5)
                                  : const Color(0xFFB0A895).withOpacity(0.5),
                              blurRadius: 12,
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
                                          color: const Color(0xFFD4AF37).withOpacity(0.5),
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
                            ? (isDark ? const Color(0xFFD4AF37).withOpacity(0.18) : const Color(0xFF8A6A1F).withOpacity(0.12))
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04));

                        final fg = selected ? iconColor : (isDark ? Colors.white70 : Colors.black54);

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
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.65),
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.35),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                        width: 1,
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
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFD4AF37),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFFD4AF37),
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
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFD4AF37),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'PRÉFÉRENCES',
                                    style: TextStyle(
                                      color: Color(0xFFD4AF37),
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
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFD4AF37),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'INFORMATIONS',
                                    style: TextStyle(
                                      color: Color(0xFFD4AF37),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(0, 0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Icône iOS simple
            Icon(
              icon,
              color: const Color(0xFFD4AF37),
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
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
                      const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
