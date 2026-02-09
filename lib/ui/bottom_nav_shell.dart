import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'quran_tab_screen.dart';
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
  int _index = 0; // 0..3

  late final List<Widget> _pages = <Widget>[
    const HomeScreen(),
    const QuranTabScreen(),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  Future<void> _openReader() async {
    final last = await LastReadingService.getLastReading();
    final page = last?.pageNumber ?? 1;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          initialPage: page,
          reading: 'hafs',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: ModernBottomNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        onCenterTap: _openReader,
      ),
    );
  }
}
