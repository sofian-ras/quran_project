import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'prayers_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'reader_screen.dart';

import '../services/last_reading_service.dart';
import 'widgets/modern_bottom_nav_bar.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  // Permet de conserver le state/scroll de chaque tab (même avec IndexedStack,
  // ça aide surtout si certains widgets utilisent PageStorageKey).
  final PageStorageBucket _bucket = PageStorageBucket();

  late final List<Widget> _pages = <Widget>[
    const HomeScreen(key: PageStorageKey('tab_home')),
    const PrayersScreen(key: PageStorageKey('tab_prayers')),
    const FavoritesScreen(key: PageStorageKey('tab_favorites')),
    const SettingsScreen(key: PageStorageKey('tab_settings')),
  ];

  Future<void> _openReader() async {
    final last = await LastReadingService.getLastReading();
    final page = last?.pageNumber ?? 1;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          initialPage: page,
          reading: 'hafs',
        ),
      ),
    );
  }

  // UX: bouton retour Android
  // - si tu n'es pas sur Accueil, retour => revient à Accueil
  // - sinon => laisse Android fermer l'app
  Future<bool> _onWillPop() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  void _onTabChanged(int i) {
    if (i == _index) {
      // Optionnel: si l'utilisateur retape l'onglet courant,
      // tu peux ajouter un comportement plus tard (scroll-to-top, etc.).
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        body: PageStorage(
          bucket: _bucket,
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
        bottomNavigationBar: ModernBottomNavBar(
          index: _index,
          onChanged: _onTabChanged,
          onCenterTap: _openReader,
        ),
      ),
    );
  }
}
