import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'ui/home_screen.dart';
import 'ui/widgets/mini_audio_player.dart';
import 'package:quran/theme/app_theme.dart';
import 'package:quran/theme/theme_service.dart';
import 'services/audio_service.dart';
import 'services/navigation_service.dart';
import 'ui/bottom_nav_shell.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0x33000000), // 80 % transparent
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;
  await ThemeService.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const QuranApp());
}


class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> with WidgetsBindingObserver {
  static void _applyNavBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0x33000000),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Réapplique le style à chaque changement de thème
    ThemeService.themeMode.addListener(_applyNavBarStyle);
  }

  @override
  void dispose() {
    ThemeService.themeMode.removeListener(_applyNavBarStyle);
    WidgetsBinding.instance.removeObserver(this);
    AudioService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AudioService.instance.pause();
    }
    // Réapplique au retour au premier plan
    if (state == AppLifecycleState.resumed) {
      _applyNavBarStyle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Color(0x33000000),
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const BottomNavShell(),
          builder: (context, child) {
            return Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => Material(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        if (child != null) child,
                        const GlobalMiniPlayerOverlay(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),       // MaterialApp
        );       // AnnotatedRegion
      },
    );
  }
}




