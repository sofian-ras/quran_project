import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'ui/screens/bottom_nav_shell.dart';
import 'package:quran/theme/app_theme.dart';
import 'package:quran/theme/theme_service.dart';
import 'package:workmanager/workmanager.dart';
import 'services/app_usage_service.dart';
import 'services/audio_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_reschedule_worker.dart';
import 'services/quran_translation_pack_service.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // JustAudioBackground doit être prêt AVANT tout setAudioSource.
  // Avec unawaited, le service n'était pas encore lié quand l'utilisateur
  // tapait une sourate → échec silencieux dans loadPlaylistAndPlay.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.quran.app.audio',
    androidNotificationChannelName: 'Coran Audio',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: true,
  );

  // ThemeService doit être prêt avant runApp pour éviter le flash de thème.
  await ThemeService.init();

  // WorkManager : initialisation synchrone requise avant tout registerTask.
  // Try-catch : un crash ici empêcherait runApp() de s'exécuter.
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    unawaited(Workmanager().registerPeriodicTask(
      kRescheduleTaskUnique,
      kRescheduleTaskName,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.not_required),
    ));
  } catch (e) {
    debugPrint('[WorkManager] init failed: $e');
  }

  // Opérations non-bloquantes : lancées en arrière-plan sans retarder runApp.
  AppUsageService.init();
  QuranTranslationPackService.migrateLegacyToQulIfNeeded();
  // Re-planifie les notifications actives (one-shots expirés, nouvelles alarmes).
  unawaited(NotificationService.instance.scheduleOnStartup());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  PaintingBinding.instance.imageCache.maximumSizeBytes = 25 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 150;

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
        systemNavigationBarColor: Colors.transparent,
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
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
            return Material(
              color: Colors.transparent,
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),       // MaterialApp
        );       // AnnotatedRegion
      },
    );
  }
}




