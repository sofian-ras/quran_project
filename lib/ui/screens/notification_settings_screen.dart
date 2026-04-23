import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../services/streak_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kTeal   = Color(0xFF0E6B63);
const _kOrange = Color(0xFFF97316);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  // ── État ─────────────────────────────────────────────────────────────────
  bool _dailyEnabled      = false;
  bool _prayersEnabled    = false;
  bool _verseEnabled      = false;
  bool _dhikrEnabled      = false;
  bool _streakEnabled     = true;
  TimeOfDay _dailyTime    = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _verseTime    = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _dhikrMorning = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _dhikrEvening = const TimeOfDay(hour: 21, minute: 0);
  bool _loading           = true;
  bool _exactAlarmGranted = true;
  bool _batteryOk         = true;
  int  _currentStreak     = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance
          .isIgnoringBatteryOptimizations()
          .then((ok) { if (mounted) setState(() => _batteryOk = ok); });
    }
  }

  Future<void> _load() async {
    await NotificationService.instance.init();
    final svc = NotificationService.instance;
    final results = await Future.wait([
      svc.isDailyEnabled(),
      svc.arePrayersEnabled(),
      svc.isVerseEnabled(),
      svc.isDhikrEnabled(),
      svc.isStreakNotifEnabled(),
      svc.canScheduleExactNotifications(),
      svc.isIgnoringBatteryOptimizations(),
    ]);
    final times = await Future.wait([
      svc.getDailyTime(),
      svc.getVerseTime(),
      svc.getDhikrMorningTime(),
      svc.getDhikrEveningTime(),
    ]);
    if (!mounted) return;
    setState(() {
      _dailyEnabled      = results[0];
      _prayersEnabled    = results[1];
      _verseEnabled      = results[2];
      _dhikrEnabled      = results[3];
      _streakEnabled     = results[4];
      _exactAlarmGranted = results[5];
      _batteryOk         = results[6];
      _dailyTime         = times[0];
      _verseTime         = times[1];
      _dhikrMorning      = times[2];
      _dhikrEvening      = times[3];
      _currentStreak     = StreakService.instance.streak;
      _loading           = false;
    });
  }

  // ── Permissions ───────────────────────────────────────────────────────────
  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission de notifications refusée.'),
          action: SnackBarAction(
            label: 'Paramètres',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ),
      );
      return false;
    }
    return await _ensureExactAlarmPermission();
  }

  Future<bool> _ensureExactAlarmPermission() async {
    if (_exactAlarmGranted) return true;
    if (!mounted) return false;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alarmes et rappels'),
        content: const Text(
          'Pour recevoir les notifications à l\'heure exacte, '
          'activez "Alarmes et rappels" pour cette application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ouvrir', style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await NotificationService.instance.requestExactAlarmPermission();
      final granted =
          await NotificationService.instance.canScheduleExactNotifications();
      if (mounted) setState(() => _exactAlarmGranted = granted);
      return granted;
    }
    return true;
  }

  // ── Rappel de lecture ─────────────────────────────────────────────────────
  Future<void> _toggleDaily(bool value) async {
    if (value && !await _ensurePermissions()) return;
    if (value) {
      await NotificationService.instance.scheduleDailyReminder(_dailyTime);
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    if (!mounted) return;
    setState(() => _dailyEnabled = value);
  }

  Future<void> _pickDailyTime() async {
    final picked = await _showTimePicker(_dailyTime);
    if (picked == null || !mounted) return;
    setState(() => _dailyTime = picked);
    if (_dailyEnabled) {
      await NotificationService.instance.scheduleDailyReminder(picked);
    }
  }

  // ── Prières ───────────────────────────────────────────────────────────────
  Future<void> _togglePrayers(bool value) async {
    if (value && !await _ensurePermissions()) return;
    if (value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('adhan_enabled', true);
      final scheduled = await NotificationService.instance.scheduleFromCache();
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ouvrez l\'onglet Prières pour charger les horaires.',
            ),
          ),
        );
      }
    } else {
      await NotificationService.instance.cancelPrayerNotifications();
    }
    if (!mounted) return;
    setState(() => _prayersEnabled = value);
  }

  // ── Verset du jour ────────────────────────────────────────────────────────
  Future<void> _toggleVerse(bool value) async {
    if (value && !await _ensurePermissions()) return;
    if (value) {
      await NotificationService.instance.scheduleVerseNotification(_verseTime);
    } else {
      await NotificationService.instance.cancelVerseNotification();
    }
    if (!mounted) return;
    setState(() => _verseEnabled = value);
  }

  Future<void> _pickVerseTime() async {
    final picked = await _showTimePicker(_verseTime);
    if (picked == null || !mounted) return;
    setState(() => _verseTime = picked);
    if (_verseEnabled) {
      await NotificationService.instance.scheduleVerseNotification(picked);
    }
  }

  // ── Dhikr ─────────────────────────────────────────────────────────────────
  Future<void> _toggleDhikr(bool value) async {
    if (value && !await _ensurePermissions()) return;
    if (value) {
      await NotificationService.instance.scheduleDhikrNotifications(
        morning: _dhikrMorning,
        evening: _dhikrEvening,
      );
    } else {
      await NotificationService.instance.cancelDhikrNotifications();
    }
    if (!mounted) return;
    setState(() => _dhikrEnabled = value);
  }

  Future<void> _pickDhikrMorning() async {
    final picked = await _showTimePicker(_dhikrMorning);
    if (picked == null || !mounted) return;
    setState(() => _dhikrMorning = picked);
    if (_dhikrEnabled) {
      await NotificationService.instance.scheduleDhikrNotifications(
        morning: picked, evening: _dhikrEvening,
      );
    }
  }

  Future<void> _pickDhikrEvening() async {
    final picked = await _showTimePicker(_dhikrEvening);
    if (picked == null || !mounted) return;
    setState(() => _dhikrEvening = picked);
    if (_dhikrEnabled) {
      await NotificationService.instance.scheduleDhikrNotifications(
        morning: _dhikrMorning, evening: picked,
      );
    }
  }

  // ── Streak ────────────────────────────────────────────────────────────────
  Future<void> _toggleStreak(bool value) async {
    await NotificationService.instance.setStreakNotifEnabled(value);
    if (!mounted) return;
    setState(() => _streakEnabled = value);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<TimeOfDay?> _showTimePicker(TimeOfDay initial) =>
      showTimePicker(
        context: context,
        initialTime: initial,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF2ECE5);
    final txtP = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtS = isDark ? Colors.white54 : Colors.black45;
    final div  = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                'Notifications',
                style: TextStyle(
                  color: txtP,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              expandedTitleScale: 1.0,
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Bandeau batterie ──────────────────────────────────
                  if (!_batteryOk) ...[
                    _BatteryWarningCard(
                      isDark: isDark,
                      onFix: () => NotificationService.instance
                          .requestBatteryOptimizationExclusion(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Streak banner ─────────────────────────────────────
                  if (_currentStreak > 0) ...[
                    _StreakBanner(streak: _currentStreak, isDark: isDark),
                    const SizedBox(height: 16),
                  ],

                  // ── 1. Rappel de lecture ──────────────────────────────
                  _SectionHeader('Rappel de lecture', txtS),
                  _Card(isDark: isDark, children: [
                    _ToggleRow(
                      icon: Icons.menu_book_rounded,
                      color: _kOrange,
                      title: 'Rappel quotidien',
                      subtitle: 'Ne rate jamais ta lecture du Coran',
                      value: _dailyEnabled,
                      onChanged: _toggleDaily,
                      txtP: txtP, txtS: txtS,
                    ),
                    Divider(height: 1, indent: 60, color: div),
                    _TimeRow(
                      icon: Icons.access_time_rounded,
                      color: const Color(0xFF0EA5E9),
                      label: 'Heure du rappel',
                      time: _fmt(_dailyTime),
                      enabled: _dailyEnabled,
                      onTap: _pickDailyTime,
                      txtP: txtP, txtS: txtS, isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── 2. Verset du jour ─────────────────────────────────
                  _SectionHeader('Verset du jour', txtS),
                  _Card(isDark: isDark, children: [
                    _ToggleRow(
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Verset inspirant',
                      subtitle: 'Un verset du Coran chaque matin',
                      value: _verseEnabled,
                      onChanged: _toggleVerse,
                      txtP: txtP, txtS: txtS,
                    ),
                    Divider(height: 1, indent: 60, color: div),
                    _TimeRow(
                      icon: Icons.wb_sunny_rounded,
                      color: const Color(0xFFF59E0B),
                      label: 'Heure d\'envoi',
                      time: _fmt(_verseTime),
                      enabled: _verseEnabled,
                      onTap: _pickVerseTime,
                      txtP: txtP, txtS: txtS, isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── 3. Dhikr & Dua ────────────────────────────────────
                  _SectionHeader('Dhikr & Doua', txtS),
                  _Card(isDark: isDark, children: [
                    _ToggleRow(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Rappels spirituels',
                      subtitle: '2 rappels par jour (matin + soir)',
                      value: _dhikrEnabled,
                      onChanged: _toggleDhikr,
                      txtP: txtP, txtS: txtS,
                    ),
                    Divider(height: 1, indent: 60, color: div),
                    _TimeRow(
                      icon: Icons.wb_sunny_outlined,
                      color: const Color(0xFF10B981),
                      label: 'Dhikr du matin',
                      time: _fmt(_dhikrMorning),
                      enabled: _dhikrEnabled,
                      onTap: _pickDhikrMorning,
                      txtP: txtP, txtS: txtS, isDark: isDark,
                    ),
                    Divider(height: 1, indent: 60, color: div),
                    _TimeRow(
                      icon: Icons.nights_stay_rounded,
                      color: const Color(0xFF6366F1),
                      label: 'Dhikr du soir',
                      time: _fmt(_dhikrEvening),
                      enabled: _dhikrEnabled,
                      onTap: _pickDhikrEvening,
                      txtP: txtP, txtS: txtS, isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── 4. Prières ────────────────────────────────────────
                  _SectionHeader('Prières', txtS),
                  _Card(isDark: isDark, children: [
                    _ToggleRow(
                      icon: Icons.mosque_rounded,
                      color: const Color(0xFF7C3AED),
                      title: 'Alertes de prière',
                      subtitle: 'Fajr · Dhuhr · Asr · Maghrib · Isha',
                      value: _prayersEnabled,
                      onChanged: _togglePrayers,
                      txtP: txtP, txtS: txtS,
                    ),
                    if (_prayersEnabled) ...[
                      Divider(height: 1, indent: 60, color: div),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16,
                                color: _kTeal.withValues(alpha: 0.8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Horaires selon l\'onglet Prières.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _kTeal.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),

                  // ── 5. Série de lecture ───────────────────────────────
                  _SectionHeader('Série de lecture', txtS),
                  _Card(isDark: isDark, children: [
                    _ToggleRow(
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFEF4444),
                      title: 'Rappel de série',
                      subtitle: 'Alerte si tu risques de briser ta série',
                      value: _streakEnabled,
                      onChanged: _toggleStreak,
                      txtP: txtP, txtS: txtS,
                    ),
                    if (_streakEnabled && _currentStreak > 0) ...[
                      Divider(height: 1, indent: 60, color: div),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(60, 10, 16, 12),
                        child: Text(
                          'Série actuelle : $_currentStreak jour${_currentStreak > 1 ? "s" : ""} 🔥',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),

                  // ── Diagnostic ────────────────────────────────────────
                  _SectionHeader('Diagnostic', txtS),
                  _Card(isDark: isDark, children: [
                    InkWell(
                      onTap: _sendTestNotification,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const _IconBox(
                                Icons.notifications_active_rounded,
                                Color(0xFF0EA5E9)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tester maintenant',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: txtP)),
                                  Text(
                                      'Envoie une notification de test dans 5 s',
                                      style: TextStyle(
                                          fontSize: 12, color: txtS)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black26,
                                size: 20),
                          ],
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Les notifications respectent le mode Ne pas déranger',
                      style: TextStyle(fontSize: 11, color: txtS),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    HapticFeedback.lightImpact();
    await NotificationService.instance.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification envoyée — elle apparaît dans 5 secondes.'),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

// ── Streak banner ────────────────────────────────────────────────────────────
class _StreakBanner extends StatelessWidget {
  final int streak;
  final bool isDark;
  const _StreakBanner({required this.streak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEF4444);
    final bg = isDark ? const Color(0xFF2D0808) : const Color(0xFFFFF0F0);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak jour${streak > 1 ? "s" : ""} consécutif${streak > 1 ? "s" : ""}',
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: red,
                ),
              ),
              Text(
                'Continue comme ça, masha\'Allah !',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF7F1D1D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bandeau avertissement batterie ───────────────────────────────────────────
class _BatteryWarningCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onFix;
  const _BatteryWarningCard({required this.isDark, required this.onFix});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    final bg = isDark ? const Color(0xFF2D1F00) : const Color(0xFFFFF8E7);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.battery_alert_rounded, color: amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimisation batterie active',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: amber,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Peut bloquer les notifications en arrière-plan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onFix,
                  child: const Text(
                    'Désactiver maintenant →',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color txtS;
  const _SectionHeader(this.label, this.txtS);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: txtS, letterSpacing: 1.1,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _Card({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF6F1EB),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : const Color(0xFF0E6B63).withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox(this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color txtP;
  final Color txtS;
  const _ToggleRow({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
    required this.txtP, required this.txtS,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            _IconBox(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: txtP)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: txtS)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _kTeal,
              activeTrackColor: _kTeal.withValues(alpha: 0.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String time;
  final bool enabled;
  final VoidCallback onTap;
  final Color txtP;
  final Color txtS;
  final bool isDark;
  const _TimeRow({
    required this.icon, required this.color,
    required this.label, required this.time,
    required this.enabled, required this.onTap,
    required this.txtP, required this.txtS, required this.isDark,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconBox(
                icon,
                enabled ? color : (isDark ? Colors.white24 : Colors.black26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: enabled ? txtP : txtS,
                        )),
                    Text(
                      enabled ? time : 'Activez d\'abord',
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? _kTeal : txtS,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right_rounded,
                    color: isDark ? Colors.white24 : Colors.black26, size: 20),
            ],
          ),
        ),
      );
}
