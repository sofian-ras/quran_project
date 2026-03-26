import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'ui/bottom_nav_shell.dart';
import 'ui/widgets/mini_audio_player.dart';
import 'package:quran/theme/app_theme.dart';
import 'package:quran/theme/theme_service.dart';
import 'services/app_usage_service.dart';
import 'services/audio_service.dart';
import 'services/navigation_service.dart';
import 'services/quran_translation_pack_service.dart';



Future<void> main() async {
  // Doit être le premier appel — requis avant tout channel platform.
  WidgetsFlutterBinding.ensureInitialized();

  // Inits bloquantes parallélisées : JustAudioBackground (lent) + ThemeService
  // (nécessaire avant runApp pour éviter le flash de thème).
  await Future.wait([
    JustAudioBackground.init(
      androidNotificationChannelId: 'com.quran.app.audio',
      androidNotificationChannelName: 'Coran Audio',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
    ThemeService.init(),
  ]);

  // Opérations non-bloquantes : lancées en arrière-plan sans retarder runApp.
  AppUsageService.init();
  QuranTranslationPackService.migrateLegacyToQulIfNeeded();

  final bool initDark = ThemeService.themeMode.value == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: initDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: initDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: initDark ? const Color(0xFF0F1F18) : const Color(0xFFF5F7F6),
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: initDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 60;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const QuranApp());
}


class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> with WidgetsBindingObserver {
  static Color _navBarColor(bool isDark) =>
      isDark ? const Color(0xFF0F1F18) : const Color(0xFFF5F7F6);

  void _applyNavBarStyle() {
    final isDark = ThemeService.themeMode.value == ThemeMode.dark ||
        (ThemeService.themeMode.value == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: _navBarColor(isDark),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
    if (state == AppLifecycleState.resumed) {
      _applyNavBarStyle();
      AppUsageService.onResume();
    } else if (state == AppLifecycleState.paused) {
      AppUsageService.onPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _navBarColor(isDark),
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  if (child != null) child,
                  const GlobalMiniPlayerOverlay(),
                ],
              ),
            );
          },
        ),       // MaterialApp
        );       // AnnotatedRegion
      },
    );
  }
}




