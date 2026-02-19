import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'reciter_selector.dart';
import '../../services/audio_service.dart';
import '../downloads_screen.dart';
import '../favorites_screen.dart';
import '../../theme/theme_service.dart';
import '../bookmarks_screen.dart';
import '../settings_screen.dart';

class IOSSideMenu extends StatelessWidget {
  final VoidCallback? onSettingsClosed;

  const IOSSideMenu({super.key, this.onSettingsClosed});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Sidebar always "dark-green" (same in light and dark app theme)
    const bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF04110C),
        Color(0xFF062017),
        Color(0xFF0A3A2A),
        Color(0xFF0E5A3F),
      ],
    );

    // Text always light (same as dark mode)
    const Color text = Color(0xFFE8FFF4);
    const Color textMuted = Color(0xFFBFEBD8);
    final Color divider = Colors.white.withOpacity(0.12);

    // Accent stays green (optional)
    const Color accent = Color(0xFF2AAE7A);



    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(26),
        bottomRight: Radius.circular(26),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
            border: Border.all(
              color: (isDark ? Colors.white : const Color(0xFF3D2817)).withOpacity(0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.18),
                blurRadius: 28,
                offset: const Offset(10, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: accent.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: (isDark ? Colors.white : const Color(0xFF3D2817)).withOpacity(0.08),
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
                        const Expanded(
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
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                            builder: (context, reciter, _) => SizedBox(
                              width: 120,
                              child: Text(
                                reciter,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
                        const SizedBox(height: 10),
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
                ],
              ),
            ),
          ),
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
    const Color text = Color(0xFFE8FFF4);
    const Color textMuted = Color(0xFFBFEBD8);
    const Color accent = Color(0xFF2AAE7A);
    final Color divider = Colors.white.withOpacity(0.12);



    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(0, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: divider,
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: text, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailing != null)
              trailing!
            else
              const Icon(CupertinoIcons.chevron_right, color: textMuted, size: 16),
          ],
        ),
      ),

    );
  }
}
