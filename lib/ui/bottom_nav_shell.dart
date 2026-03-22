import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'prayers_screen.dart';
import 'dua_screen.dart';
import 'settings_screen.dart';
import 'translated_quran_screen.dart';

import 'widgets/modern_bottom_nav_bar.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  // Onglets déjà visités : seuls ceux-ci sont construits dans l'IndexedStack.
  // Les autres restent un SizedBox.shrink() jusqu'à leur première visite,
  // évitant d'initialiser tous les écrans au démarrage.
  final Set<int> _visitedTabs = {0};

  final PageStorageBucket _bucket = PageStorageBucket();

  late final List<Widget> _pages = <Widget>[
    const HomeScreen(key: PageStorageKey('tab_home')),
    const PrayersScreen(key: PageStorageKey('tab_prayers')),
    const DuaScreen(key: PageStorageKey('tab_dua')),
    const SettingsScreen(key: PageStorageKey('tab_settings')),
  ];

  void _openReader() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TranslatedQuranScreen(
          preferOffline: true,
          showReaderToggle: true,
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
    if (i == _index) return;
    setState(() {
      _visitedTabs.add(i);
      _index = i;
    });
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
            children: List.generate(
              _pages.length,
              (i) => _visitedTabs.contains(i)
                  ? _pages[i]
                  : const SizedBox.shrink(),
            ),
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
