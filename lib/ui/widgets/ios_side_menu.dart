import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../bookmarks_screen.dart';
import '../favorites_screen.dart';
import '../settings_screen.dart';
import '../screens/hadith_screen.dart';
import '../screens/radio_screen.dart';
import '../screens/asma_screen.dart';
import 'reciter_selector.dart';

class IOSSideMenu extends StatelessWidget {
  final VoidCallback? onSettingsClosed;
  const IOSSideMenu({super.key, this.onSettingsClosed});

  // Ferme le drawer puis push sur le Navigator racine (évite écran noir)
  void _closeAndPush(BuildContext context, Widget page) {
    final nav = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.push(MaterialPageRoute(builder: (_) => page));
    });
  }

  // Ferme le drawer puis ouvre un bottom sheet sur le Navigator racine
  void _closeAndShowBottomSheet(BuildContext context, Widget sheet) {
    final nav = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: nav.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => sheet,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkApp = Theme.of(context).brightness == Brightness.dark;

    // Sidebar look (toujours dark-green)
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

    const Color text = Color(0xFFE8FFF4);
    const Color textMuted = Color(0xFFBFEBD8);
    const Color accent = Color(0xFF2AAE7A);
    final Color divider = Colors.white.withOpacity(0.12);

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
            border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkApp ? 0.35 : 0.18),
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.30),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.08),
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
                                  size: 26,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Quran',
                            style: TextStyle(
                              fontSize: 20,
                              color: text,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Menu (shrink)
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuSection(
                        icon: CupertinoIcons.book_fill,
                        title: 'Coran',
                        subtitle: 'Lecture et récitation',
                        divider: divider,
                        onTap: () => Navigator.pop(context),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.heart_fill,
                        title: 'Favoris',
                        subtitle: 'Vos sourates préférées',
                        divider: divider,
                        onTap: () => _closeAndPush(context, const FavoritesScreen()),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.bookmark_fill,
                        title: 'Marque-pages',
                        subtitle: 'Pages sauvegardées',
                        divider: divider,
                        onTap: () => _closeAndPush(context, const BookmarksScreen()),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.music_note_2,
                        title: 'Écouter',
                        subtitle: 'Récitateurs et audio',
                        divider: divider,
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
                        onTap: () => _closeAndShowBottomSheet(
                          context,
                          ReciterSelectorSheet(
                            onSelected: (name, server) {
                              AudioService.instance.setReciter(name, server);
                            },
                          ),
                        ),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.book_solid,
                        title: 'Hadith',
                        subtitle: 'Collections de hadiths',
                        divider: divider,
                        onTap: () => _closeAndPush(context, const HadithScreen()),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.antenna_radiowaves_left_right,
                        title: 'Radio Islamique',
                        subtitle: 'Écoute en streaming',
                        divider: divider,
                        onTap: () => _closeAndPush(context, const RadioScreen()),
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.star_fill,
                        title: '99 Noms d\'Allah',
                        subtitle: 'Asmaul Husna',
                        divider: divider,
                        onTap: () => _closeAndPush(context, const AsmaScreen()),
                      ),
                      const SizedBox(height: 10),
                      _MenuSection(
                        icon: CupertinoIcons.settings,
                        title: 'Paramètres',
                        subtitle: 'Personnalisation',
                        divider: divider,
                        onTap: () {
                          _closeAndPush(context, const SettingsScreen());
                          onSettingsClosed?.call();
                        },
                      ),
                      _MenuSection(
                        icon: CupertinoIcons.info_circle_fill,
                        title: 'À propos',
                        subtitle: 'Version et crédits',
                        divider: divider,
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog(context);
                        },
                      ),
                    ],
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
      builder: (context) => const CupertinoAlertDialog(
        title: Text('القرآن الكريم'),
        content: Column(
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
            child: Text('Fermer'),
            onPressed: null, // remplacé juste après
          ),
        ],
      ),
    );

    // corrige le bouton fermer (sans refactor)
    Future.delayed(Duration.zero, () {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }
}

class _MenuSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color divider;

  const _MenuSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.divider,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    const Color text = Color(0xFFE8FFF4);
    const Color textMuted = Color(0xFFBFEBD8);
    const Color accent = Color(0xFF2AAE7A);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(0, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: divider, width: 0.8)),
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
                  const SizedBox(height: 1),
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
