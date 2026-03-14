import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_usage_service.dart';
import '../theme/theme_service.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';
import 'statistics_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
const _kTeal  = Color(0xFF0E6B63);
const _kTeal2 = Color(0xFF0B4F4A);

const _kVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Prefs ──────────────────────────────────────────────────────────────────
  static const _kTime24h = 'time_format_24h';

  bool _time24h = true;

  // ── Time tracker ───────────────────────────────────────────────────────────
  int    _usageSeconds = 0;
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _startUsageTimer();
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _time24h = prefs.getBool(_kTime24h) ?? true);
  }

  Future<void> _setTime24h(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTime24h, v);
    if (!mounted) return;
    setState(() => _time24h = v);
  }

  // ── Usage timer ────────────────────────────────────────────────────────────
  void _startUsageTimer() {
    _usageSeconds = AppUsageService.totalSeconds;
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _usageSeconds = AppUsageService.totalSeconds);
    });
  }

  // ── Theme helper ───────────────────────────────────────────────────────────
  void _setTheme(ThemeMode mode) => ThemeService.setTheme(mode);

  // ── Play Store ─────────────────────────────────────────────────────────────
  Future<void> _openPlayStore() async {
    const url = 'https://play.google.com/store/apps/details?id=com.quran.app';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => screen),
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF2ECE5);
    final txtP    = isDark ? Colors.white             : const Color(0xFF0F172A);
    final txtS    = isDark ? Colors.white54           : Colors.black45;
    final div     = isDark ? Colors.white10           : Colors.black.withValues(alpha: 0.06);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, currentMode, _) {
        return Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            slivers: [
              // ── App bar ────────────────────────────────────────────────────
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
                    'Paramètres',
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

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── Apparence ─────────────────────────────────────────────
                    _SectionHeader('Apparence', txtS),
                    _Card(isDark: isDark, children: [

                      // Thème – segmented selector
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            const _IconBox(Icons.palette_rounded, Color(0xFF7C3AED)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Thème',
                                      style: TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w600, color: txtP)),
                                  const SizedBox(height: 8),
                                  _ThemeSelector(
                                    current: currentMode,
                                    isDark: isDark,
                                    onSelect: _setTheme,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, indent: 60, color: div),

                      // Format heure
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        child: Row(
                          children: [
                            const _IconBox(Icons.access_time_rounded, Color(0xFF0EA5E9)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Format horaire',
                                      style: TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w600, color: txtP)),
                                  Text(_time24h ? '24 heures' : '12 heures (AM/PM)',
                                      style: TextStyle(fontSize: 12, color: txtS)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('12h',
                                    style: TextStyle(fontSize: 12,
                                        color: _time24h ? txtS : _kTeal,
                                        fontWeight: FontWeight.w600)),
                                Switch(
                                  value: _time24h,
                                  onChanged: _setTime24h,
                                  activeThumbColor: _kTeal,
                  activeTrackColor: _kTeal.withValues(alpha: 0.5),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                Text('24h',
                                    style: TextStyle(fontSize: 12,
                                        color: _time24h ? _kTeal : txtS,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Ma bibliothèque ───────────────────────────────────────
                    _SectionHeader('Ma bibliothèque', txtS),
                    _Card(isDark: isDark, children: [
                      _NavTile(
                        icon: Icons.favorite_rounded,
                        iconBg: const Color(0xFFE11D48),
                        title: 'Favoris',
                        subtitle: 'Ayahs et sourates sauvegardés',
                        isDark: isDark, txtP: txtP, txtS: txtS,
                        onTap: () => _push(const FavoritesScreen()),
                      ),
                      Divider(height: 1, indent: 60, color: div),
                      _NavTile(
                        icon: Icons.bookmark_rounded,
                        iconBg: const Color(0xFF2563EB),
                        title: 'Signets',
                        subtitle: 'Marque-pages de lecture',
                        isDark: isDark, txtP: txtP, txtS: txtS,
                        onTap: () => _push(const BookmarksScreen()),
                      ),
                      Divider(height: 1, indent: 60, color: div),
                      _NavTile(
                        icon: Icons.bar_chart_rounded,
                        iconBg: const Color(0xFF7C3AED),
                        title: 'Statistiques',
                        subtitle: 'Suivi de votre progression',
                        isDark: isDark, txtP: txtP, txtS: txtS,
                        onTap: () => _push(const StatisticsScreen()),
                      ),
                      Divider(height: 1, indent: 60, color: div),
                      _NavTile(
                        icon: Icons.cloud_download_rounded,
                        iconBg: _kTeal,
                        title: 'Téléchargements',
                        subtitle: 'Récitations hors-ligne',
                        isDark: isDark, txtP: txtP, txtS: txtS,
                        onTap: () => _push(const DownloadsScreen()),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Application ───────────────────────────────────────────
                    _SectionHeader('Application', txtS),
                    _Card(isDark: isDark, children: [

                      // Temps passé
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const _IconBox(Icons.timer_rounded, Color(0xFFF59E0B)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Temps passé sur l\'app',
                                      style: TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w600, color: txtP)),
                                  Text(AppUsageService.formatDuration(_usageSeconds),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _kTeal,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, indent: 60, color: div),

                      // Évaluer
                      _NavTile(
                        icon: Icons.star_rounded,
                        iconBg: const Color(0xFFF59E0B),
                        title: 'Évaluer l\'application',
                        subtitle: 'Disponible sur le Play Store',
                        isDark: isDark, txtP: txtP, txtS: txtS,
                        onTap: _openPlayStore,
                      ),

                      Divider(height: 1, indent: 60, color: div),

                      // Version
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _IconBox(Icons.info_outline_rounded,
                                isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Version',
                                      style: TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w600, color: txtP)),
                                  Text(_kVersion,
                                      style: TextStyle(fontSize: 12, color: txtS)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── À propos ──────────────────────────────────────────────
                    _SectionHeader('À propos', txtS),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kTeal, _kTeal2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _kTeal.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_stories_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quran App',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                SizedBox(height: 6),
                                Text(
                                  'Une application conçue avec amour pour faciliter '
                                  'la lecture, l\'écoute et la mémorisation du Saint Coran. '
                                  'Qu\'Allah nous accorde la guidance et fasse de cette app '
                                  'une sadaqa jariya.',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'v$_kVersion  ·  Fait pour la Oummah',
                        style: TextStyle(fontSize: 11, color: txtS),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Theme selector widget ─────────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final bool isDark;
  final ValueChanged<ThemeMode> onSelect;

  const _ThemeSelector({
    required this.current,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ThemeChip(
          icon: Icons.wb_sunny_rounded,
          selected: current == ThemeMode.light,
          isDark: isDark,
          onTap: () => onSelect(ThemeMode.light),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          icon: Icons.nightlight_round,
          selected: current == ThemeMode.dark,
          isDark: isDark,
          onTap: () => onSelect(ThemeMode.dark),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          icon: Icons.brightness_auto_rounded,
          selected: current == ThemeMode.system,
          isDark: isDark,
          onTap: () => onSelect(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? _kTeal
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kTeal : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(icon,
            size: 18,
            color: selected ? Colors.white : (isDark ? Colors.white54 : Colors.black45)),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
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
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.15)
              : const Color(0xFF0E6B63).withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
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
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: Colors.white, size: 18),
  );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title, subtitle;
  final bool isDark;
  final Color txtP, txtS;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.txtP,
    required this.txtS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBox(icon, iconBg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: txtP)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: txtS)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26, size: 20),
        ],
      ),
    ),
  );
}
