import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'ui/screens/initial_loading_screen.dart';
import 'ui/widgets/mini_audio_player.dart';
import 'package:quran/theme/app_theme.dart';
import 'package:quran/theme/theme_service.dart';
import 'services/app_usage_service.dart';
import 'services/audio_service.dart';
import 'services/navigation_service.dart';
import 'services/quran_translation_pack_service.dart';
import 'services/page_images_service.dart';

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
  PageImagesService.init();
  QuranTranslationPackService.migrateLegacyToQulIfNeeded();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0x33000000),
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
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
    if (state == AppLifecycleState.resumed) {
      _applyNavBarStyle();
      AppUsageService.onResume();
    } else if (state == AppLifecycleState.paused) {
      AppUsageService.onPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392, 800),
      minTextAdapt: true,
      builder: (_, __) => ValueListenableBuilder<ThemeMode>(
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
          home: const InitialLoadingScreen(),
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
    ),    // ValueListenableBuilder
    );    // ScreenUtilInit
  }
}




