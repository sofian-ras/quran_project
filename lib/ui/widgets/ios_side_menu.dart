import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'reciter_selector.dart';
import '../../services/audio_service.dart';

class IOSSideMenu extends StatelessWidget {
  const IOSSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B3D2E), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'القرآن الكريم',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Le Noble Coran',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC8A165),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // Coran Section
                  _MenuSection(
                    icon: CupertinoIcons.book_fill,
                    title: 'Coran',
                    subtitle: 'Lecture et récitation',
                    onTap: () => Navigator.pop(context),
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
                          color: Color(0xFFC8A165),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xFF0B3D2E),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                          ),
                          builder: (context) => ReciterSelectorSheet(
                            onSelected: (name, server) {
                              AudioService.instance.setReciter(name, server);
                            },
                          ),
                        );
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
                        color: const Color(0xFFC8A165).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bientôt',
                        style: TextStyle(
                          color: Color(0xFFC8A165),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'PRÉFÉRENCES',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Favoris
                  _MenuSection(
                    icon: CupertinoIcons.heart_fill,
                    title: 'Favoris',
                    subtitle: 'Sourates sauvegardées',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to favorites
                    },
                  ),

                  // Historique
                  _MenuSection(
                    icon: CupertinoIcons.clock_fill,
                    title: 'Historique',
                    subtitle: 'Lectures récentes',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8A165).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bientôt',
                        style: TextStyle(
                          color: Color(0xFFC8A165),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

                  // Paramètres
                  _MenuSection(
                    icon: CupertinoIcons.settings,
                    title: 'Paramètres',
                    subtitle: 'Personnalisation',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8A165).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bientôt',
                        style: TextStyle(
                          color: Color(0xFFC8A165),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'INFORMATIONS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC8A165), Color(0xFFD4AF77)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC8A165).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
