import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

const _kMuezzins = <String, String>{
  'AbdulBaset':          'Abdul Basit Abdul Samad',
  'AbdulBaset_Mujawwad': 'Abdul Basit (Mujawwad)',
  'Sudais':              'Abdurrahman As-Sudais',
  'Alafasy':             'Mishary Rashid Alafasy',
  'Husary':              'Mahmoud Khalil Al-Husary',
  'Minshawi':            'Mohamed Siddiq El-Minshawi',
  'Ghamadi':             'Saad Al-Ghamdi',
};

// ── Palette (cohérente avec settings_screen) ──────────────────────────────────
const _kTeal  = Color(0xFF0E6B63);
const _kOrange = Color(0xFFF97316);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _dailyEnabled   = false;
  bool _prayersEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 8, minute: 0);
  String _muezzin      = 'AbdulBaset';
  bool _loading        = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotificationService.instance.init();
    final dailyEnabled   = await NotificationService.instance.isDailyEnabled();
    final prayersEnabled = await NotificationService.instance.arePrayersEnabled();
    final dailyTime      = await NotificationService.instance.getDailyTime();
    final prefs          = await SharedPreferences.getInstance();
    final muezzin        = prefs.getString('prayer_muezzin') ?? 'AbdulBaset';
    if (!mounted) return;
    setState(() {
      _dailyEnabled   = dailyEnabled;
      _prayersEnabled = prayersEnabled;
      _dailyTime      = dailyTime;
      _muezzin        = muezzin;
      _loading        = false;
    });
  }

  // ── Rappel quotidien ──────────────────────────────────────────────────────
  Future<void> _toggleDaily(bool value) async {
    if (value) {
      if (!Platform.isAndroid) {
        setState(() => _dailyEnabled = true);
        return;
      }
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
        return;
      }
      await NotificationService.instance.scheduleDailyReminder(_dailyTime);
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    if (!mounted) return;
    setState(() => _dailyEnabled = value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dailyTime = picked);
    if (_dailyEnabled) {
      await NotificationService.instance.scheduleDailyReminder(picked);
    }
  }

  // ── Prières ───────────────────────────────────────────────────────────────
  Future<void> _togglePrayers(bool value) async {
    if (value) {
      if (!Platform.isAndroid) {
        setState(() => _prayersEnabled = true);
        return;
      }
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
        return;
      }
      // Activer aussi l'adhan quand on active les alertes de prière.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('adhan_enabled', true);

      // Planifier depuis le cache (horaires du dernier fetch dans l'onglet Prières).
      final scheduled = await NotificationService.instance.scheduleFromCache();
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ouvrez l\'onglet Prières pour charger les horaires, '
              'puis revenez ici.',
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

  // ── Muezzin ───────────────────────────────────────────────────────────────
  Future<void> _pickMuezzin(
      bool isDark, Color txtP, Color txtS, Color div) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MuezzinSheet(
        current: _muezzin,
        isDark: isDark,
        txtP: txtP,
        txtS: txtS,
      ),
    );
    if (selected == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_muezzin', selected);
    setState(() => _muezzin = selected);
  }

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

                  // ── Rappel de lecture ─────────────────────────────────
                  _SectionHeader('Rappel de lecture', txtS),
                  _Card(isDark: isDark, children: [

                    // Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          const _IconBox(
                              Icons.menu_book_rounded, _kOrange),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rappel quotidien',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: txtP)),
                                Text('Rappel pour lire le Coran chaque jour',
                                    style:
                                        TextStyle(fontSize: 12, color: txtS)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _dailyEnabled,
                            onChanged: _toggleDaily,
                            activeThumbColor: _kTeal,
                            activeTrackColor:
                                _kTeal.withValues(alpha: 0.5),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, indent: 60, color: div),

                    // Heure
                    InkWell(
                      onTap: _dailyEnabled ? _pickTime : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            _IconBox(
                              Icons.access_time_rounded,
                              _dailyEnabled
                                  ? const Color(0xFF0EA5E9)
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.black26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Heure du rappel',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: _dailyEnabled
                                              ? txtP
                                              : txtS)),
                                  Text(
                                    _dailyEnabled
                                        ? _formatTime(_dailyTime)
                                        : 'Activez le rappel d\'abord',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _dailyEnabled
                                            ? _kTeal
                                            : txtS,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (_dailyEnabled)
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

                  // ── Prières ───────────────────────────────────────────
                  _SectionHeader('Prières', txtS),
                  _Card(isDark: isDark, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          const _IconBox(
                              Icons.mosque_rounded,
                              Color(0xFF7C3AED)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alertes de prière',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: txtP)),
                                Text(
                                    'Fajr, Dhuhr, Asr, Maghrib, Isha\n'
                                    'Horaires calculés selon votre position',
                                    style:
                                        TextStyle(fontSize: 12, color: txtS)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _prayersEnabled,
                            onChanged: _togglePrayers,
                            activeThumbColor: _kTeal,
                            activeTrackColor:
                                _kTeal.withValues(alpha: 0.5),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),

                    if (_prayersEnabled) ...[
                      Divider(height: 1, indent: 60, color: div),

                      // Sélecteur muezzin
                      InkWell(
                        onTap: () => _pickMuezzin(isDark, txtP, txtS, div),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              const _IconBox(
                                  Icons.record_voice_over_rounded,
                                  Color(0xFF0EA5E9)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Muezzin',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: txtP)),
                                    Text(
                                      _kMuezzins[_muezzin] ?? _muezzin,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _kTeal,
                                          fontWeight: FontWeight.w600),
                                    ),
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
                                'Les notifications seront envoyées selon '
                                'les horaires configurés dans Prières.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _kTeal.withValues(alpha: 0.8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),

                  // ── Note bas de page ──────────────────────────────────
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

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Widgets partagés ──────────────────────────────────────────────────────────
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
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: txtS,
            letterSpacing: 1.1,
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
          color: isDark
              ? const Color(0xFF111827)
              : const Color(0xFFF6F1EB),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

// ── Sélecteur de muezzin ──────────────────────────────────────────────────────
class _MuezzinSheet extends StatelessWidget {
  final String current;
  final bool isDark;
  final Color txtP;
  final Color txtS;

  const _MuezzinSheet({
    required this.current,
    required this.isDark,
    required this.txtP,
    required this.txtS,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111827) : const Color(0xFFF6F1EB);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Choisir le muezzin',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: txtP,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._kMuezzins.entries.map((e) {
            final isSelected = e.key == current;
            return InkWell(
              onTap: () => Navigator.pop(context, e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected ? _kTeal : txtP,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_rounded,
                          color: _kTeal, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
