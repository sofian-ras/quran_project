// lib/ui/prayers_screen.dart
//
// Écran horaires de prière – redesign homogène avec l'app.
// Palette teal/mosquée identique à prayer_times_card_v2.
// Header : image mosquée + dégradé + étoiles + prière suivante + countdown live.
// Liste : per-prayer rows avec toggle adhan + toggle notif.
// Sections bas : son de l'adhan (muezzin + preview) + notifications.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../services/location_service.dart';
import '../widgets/location_picker_dialog.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kTeal  = Color(0xFF0E6B63);
const _kTeal2 = Color(0xFF0B4F4A);
const _kGold  = Color(0xFFFFD37A);

// Couleur unique pour toutes les prières actives : vert émeraude vif
const _kActiveGreen = Color(0xFF22C55E);

// ── Muezzins & URLs ──────────────────────────────────────────────────────────
const _kMuezzins = <String, String>{
  'AbdulBaset':          'Abdul Basit Abdul Samad',
  'AbdulBaset_Mujawwad': 'Abdul Basit (Mujawwad)',
  'Sudais':              'Abdurrahman As-Sudais',
  'Alafasy':             'Mishary Rashid Alafasy',
  'Husary':              'Mahmoud Khalil Al-Husary',
  'Minshawi':            'Mohamed Siddiq El-Minshawi',
  'Ghamadi':             'Saad Al-Ghamdi',
};

const _kAdhanUrls = <String, String>{
  'AbdulBaset':          'https://www.islamcan.com/audio/adhan/azan1.mp3',
  'AbdulBaset_Mujawwad': 'https://www.islamcan.com/audio/adhan/azan2.mp3',
  'Sudais':              'https://www.islamcan.com/audio/adhan/azan3.mp3',
  'Alafasy':             'https://www.islamcan.com/audio/adhan/azan4.mp3',
  'Husary':              'https://www.islamcan.com/audio/adhan/azan5.mp3',
  'Minshawi':            'https://www.islamcan.com/audio/adhan/azan6.mp3',
  'Ghamadi':             'https://www.islamcan.com/audio/adhan/azan7.mp3',
};

const _kMethods = <String, String>{
  '2':  'ISNA',
  '3':  'Muslim World League',
  '4':  'Umm al-Qura, Makkah',
  '5':  'Egyptian Authority',
  '8':  'Gulf Region',
  '9':  'Kuwait',
  '10': 'Qatar',
  '11': 'Singapour (MUIS)',
  '12': 'UOIF – France',
  '13': 'Turkey (Diyanet)',
  '14': 'Russie',
  '15': 'Moon Sighting Committee',
  '16': 'Dubai',
  '17': 'Malaysia (JAKIM)',
  '18': 'Tunisie',
  '19': 'Algérie',
  '20': 'Indonésie (KEMENAG)',
  '21': 'Maroc',
  '22': 'Portugal',
  '23': 'Jordanie',
};

// ─────────────────────────────────────────────────────────────────────────────

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  static const _prefMethod  = 'prayer_method';
  static const _prefCity    = 'prayer_city';
  static const _prefCountry = 'prayer_country';
  static const _defMethod   = '12';
  static const _defCity     = 'Paris';
  static const _defCountry  = 'France';

  late Future<_PrayersData> _future;
  late final StreamController<DateTime> _clockCtrl;
  late final Timer _clockTimer;
  late final Stream<DateTime> _clock;
  String _currentMethod = _defMethod;

  @override
  void initState() {
    super.initState();
    _clockCtrl  = StreamController<DateTime>.broadcast();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clockCtrl.add(DateTime.now());
    });
    _clock  = _clockCtrl.stream;
    _future = _loadPrayers();
    _loadMethod();
  }

  Future<void> _loadMethod() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = (prefs.getString(_prefMethod) ?? _defMethod).trim();
    setState(() => _currentMethod = raw.isEmpty ? _defMethod : raw);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _clockCtrl.close();
    super.dispose();
  }

  Future<void> _saveMethod(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMethod, id);
    if (!mounted) return;
    setState(() => _currentMethod = id);
    _refresh();
  }

  void _showMethodSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final txtP = isDark ? Colors.white : const Color(0xFF0F172A);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('Méthode de calcul',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: txtP)),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: _kMethods.entries.map((e) {
                    final sel = e.key == _currentMethod;
                    return ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 2, 16, 2),
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: sel ? _kTeal : (isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          sel ? Icons.check_rounded : Icons.calculate_outlined,
                          color: sel ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                          size: 18,
                        ),
                      ),
                      title: Text(e.value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _kTeal : txtP,
                          )),
                      onTap: () {
                        _saveMethod(e.key);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLocationPicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationPickerDialog(),
    );
    _refresh();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<_PrayersData> _loadPrayers() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final rawM   = (prefs.getString(_prefMethod) ?? _defMethod).trim();
      final method = rawM.isEmpty ? _defMethod : rawM;

      final loc = await LocationService.getSavedOrCurrentLocation();

      Uri uri;
      if (!loc.isManual && loc.latitude != 0 && loc.longitude != 0) {
        uri = Uri.https('api.aladhan.com', '/v1/timings', {
          'latitude':  loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'method':    method,
        });
      } else {
        final city    = (prefs.getString(_prefCity)    ?? _defCity).trim();
        final country = (prefs.getString(_prefCountry) ?? _defCountry).trim();
        uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
          'city': city, 'country': country, 'method': method,
        });
      }

      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final root    = json.decode(res.body) as Map<String, dynamic>;
      final data    = root['data'] as Map<String, dynamic>;
      final timings = data['timings'] as Map<String, dynamic>;

      // Hijri date
      final hijri      = (data['date'] as Map?)?['hijri'] as Map?;
      final hijriDay   = hijri?['day']?.toString() ?? '';
      final hijriMonth = ((hijri?['month'] as Map?)?['en'] ?? '').toString();
      final hijriYear  = hijri?['year']?.toString() ?? '';
      final hijriLine  = (hijriDay.isNotEmpty && hijriMonth.isNotEmpty && hijriYear.isNotEmpty)
          ? '$hijriDay $hijriMonth $hijriYear AH'
          : '';

      final city    = loc.city.isNotEmpty    ? loc.city    : (prefs.getString(_prefCity)    ?? _defCity).trim();
      final country = loc.country.isNotEmpty ? loc.country : (prefs.getString(_prefCountry) ?? _defCountry).trim();

      return _PrayersData(
        city: city, country: country, method: method, hijriLine: hijriLine,
        times: {
          'Fajr':    (timings['Fajr']    ?? '').toString(),
          'Dhuhr':   (timings['Dhuhr']   ?? '').toString(),
          'Asr':     (timings['Asr']     ?? '').toString(),
          'Maghrib': (timings['Maghrib'] ?? '').toString(),
          'Isha':    (timings['Isha']    ?? '').toString(),
        },
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return _PrayersData.error(
        city:    (prefs.getString(_prefCity)    ?? _defCity).trim(),
        country: (prefs.getString(_prefCountry) ?? _defCountry).trim(),
        method:  (prefs.getString(_prefMethod)  ?? _defMethod).trim(),
      );
    }
  }

  void _refresh() => setState(() { _future = _loadPrayers(); });

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime? _parseToday(String t, DateTime now) {
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  String? _nextPrayer(Map<String, String> times) {
    if (times.isEmpty) return null;
    final now = DateTime.now();
    for (final e in times.entries) {
      final t = _parseToday(e.value, now);
      if (t != null && t.isAfter(now)) return e.key;
    }
    return times.keys.first;
  }

  String _countdown(String time) {
    final now = DateTime.now();
    var target = _parseToday(time, now);
    if (target == null) return '--:--';
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    final diff = target.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  static String _methodLabel(String id) => _kMethods[id] ?? 'Méthode $id';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark
        ? const [Color(0xFF020617), Color(0xFF0B1025), Color(0xFF1A0033), Color(0xFF2D1B4E)]
        : const [Color(0xFFF2ECE5), Color(0xFFF2ECE5), Color(0xFFF2ECE5)];
    final bg = gradColors.first;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradColors,
          ),
        ),
      child: FutureBuilder<_PrayersData>(
        future: _future,
        builder: (context, snap) {
          final loading  = snap.connectionState != ConnectionState.done;
          final data     = snap.data;
          final times    = data?.times ?? {};
          final nextName = times.isEmpty ? null : _nextPrayer(times);

          final topPadding = MediaQuery.of(context).padding.top;

          return CustomScrollView(
            slivers: [
              // ── HEADER ──────────────────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _PrayerHeaderDelegate(
                  isDark:        isDark,
                  loading:       loading,
                  data:          data,
                  nextName:      nextName,
                  clock:         _clock,
                  countdown:     _countdown,
                  bodyBg:        bg,
                  topPadding:    topPadding,
                  onRefresh:     _refresh,
                  onLocationTap: () => _showLocationPicker(context),
                ),
              ),

              if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _kTeal),
                  ),
                )
              else if (times.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 52,
                            color: isDark ? Colors.white30 : Colors.black26),
                        const SizedBox(height: 14),
                        Text('Impossible de charger les horaires',
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 15)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: _kTeal),
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ── METHOD CHIP ──────────────────────────────────────────────
                if (data != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        children: [
                          GestureDetector(
                            onTap: () => _showMethodSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calculate_outlined,
                                      size: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38),
                                  const SizedBox(width: 4),
                                  Text(
                                    _methodLabel(data.method),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.keyboard_arrow_right_rounded,
                                      size: 13,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── PRAYER ROWS ──────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final e      = times.entries.elementAt(i);
                        final isNext = e.key == nextName;
                        final isLast = i == times.length - 1;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PrayerRow(
                              isDark:    isDark,
                              name:      e.key,
                              time:      e.value,
                              isNext:    isNext,
                              clock:     _clock,
                              countdown: _countdown,
                            ),
                            // Séparateur léger entre les lignes non-carte
                            if (!isNext && !isLast)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                          ],
                        );
                      },
                      childCount: times.length,
                    ),
                  ),
                ),

                // ── ADHAN SECTION ────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _AdhanSection(isDark: isDark),
                  ),
                ),

                // ── NOTIFICATION SECTION ─────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NotifSection(isDark: isDark),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.only(
                      bottom: 36 + MediaQuery.of(context).padding.bottom),
                  sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ],
            ],
          );
        },
      ),
      ), // Container
    );
  }
}

// ── HEADER DELEGATE ────────────────────────────────────────────────────────────

class _PrayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final bool loading;
  final _PrayersData? data;
  final String? nextName;
  final Stream<DateTime> clock;
  final String Function(String) countdown;
  final Color bodyBg;
  final double topPadding;
  final VoidCallback onRefresh;
  final VoidCallback onLocationTap;

  _PrayerHeaderDelegate({
    required this.isDark,
    required this.loading,
    required this.data,
    required this.nextName,
    required this.clock,
    required this.countdown,
    required this.bodyBg,
    required this.topPadding,
    required this.onRefresh,
    required this.onLocationTap,
  });

  @override
  double get maxExtent => 268 + topPadding;

  @override
  double get minExtent => kToolbarHeight + topPadding;

  @override
  bool shouldRebuild(_PrayerHeaderDelegate old) =>
      isDark != old.isDark ||
      loading != old.loading ||
      data != old.data ||
      nextName != old.nextName ||
      topPadding != old.topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t        = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final nextTime = data?.times[nextName];

    return ClipRect(
      child: Stack(
      fit: StackFit.expand,
      children: [
        // ── Mosque image (fade out as collapsed) ─────────────────────────────
        Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Image.asset(
            'assets/images/prieres/mosquee_fond_widget.webp',
            fit: BoxFit.cover,
          ),
        ),

        // ── Teal gradient (always visible) ───────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [
                Color(0xEE0E6B63),
                Color(0xEE0B4F4A),
                Color(0xF0083B37),
              ],
            ),
          ),
        ),

        // ── Stars (fade out quickly) ──────────────────────────────────────────
        Opacity(
          opacity: (1 - t * 2).clamp(0.0, 1.0),
          child: const IgnorePointer(
            child: CustomPaint(painter: _StarfieldPainter()),
          ),
        ),

        // ── Expanded content (fade out) ───────────────────────────────────────
        Opacity(
          opacity: (1 - t * 1.8).clamp(0.0, 1.0),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: topPadding),
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        'Horaires de prières',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 22),
                      onPressed: onRefresh,
                      tooltip: 'Actualiser',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Next prayer
              if (!loading && nextName != null && nextTime != null) ...[
                Text(
                  'PROCHAINE PRIÈRE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  nextTime,
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<DateTime>(
                  stream: clock,
                  builder: (_, __) =>
                      _CountdownPill(text: 'Dans ${countdown(nextTime)}'),
                ),
              ] else if (loading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: _kGold, strokeWidth: 2.5),
              ],

              const SizedBox(height: 16),

              // Location + hijri
              if (data != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      GestureDetector(
                        onTap: onLocationTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white60, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              '${data!.city}, ${data!.country}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_right_rounded,
                                color: Colors.white38, size: 14),
                          ],
                        ),
                      ),
                      if (data!.hijriLine.isNotEmpty) ...[
                        Text('·',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12)),
                        Text(
                          data!.hijriLine,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            ), // Column
          ), // SingleChildScrollView
        ),

        // ── Collapsed bar (fade in) ───────────────────────────────────────────
        Opacity(
          opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (nextName != null && nextTime != null)
                            Text(
                              '$nextName  ·  $nextTime',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (data?.hijriLine.isNotEmpty == true)
                            Text(
                              data!.hijriLine,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (nextTime != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: StreamBuilder<DateTime>(
                          stream: clock,
                          builder: (_, __) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              countdown(nextTime),
                              style: const TextStyle(
                                color: _kGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom fade to body bg (fades out when collapsing) ────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Opacity(
            opacity: (1 - t * 1.5).clamp(0.0, 1.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [Colors.transparent, bodyBg],
                ),
              ),
            ),
          ),
        ),
      ],
    ), // Stack
    ); // ClipRect
  }
}

// Pill de countdown
class _CountdownPill extends StatelessWidget {
  final String text;
  const _CountdownPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: _kGold, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── PRAYER ROW ────────────────────────────────────────────────────────────────

class _PrayerRow extends StatefulWidget {
  final bool isDark;
  final String name;
  final String time;
  final bool isNext;
  final Stream<DateTime> clock;
  final String Function(String) countdown;

  const _PrayerRow({
    required this.isDark,
    required this.name,
    required this.time,
    required this.isNext,
    required this.clock,
    required this.countdown,
  });

  @override
  State<_PrayerRow> createState() => _PrayerRowState();
}

class _PrayerRowState extends State<_PrayerRow> {
  bool _adhanOn = false;
  bool _notifOn = false;

  static const _icons = <String, IconData>{
    'Fajr':    Icons.wb_twilight_rounded,
    'Dhuhr':   Icons.wb_sunny_outlined,
    'Asr':     Icons.wb_sunny_rounded,
    'Maghrib': Icons.nights_stay_rounded,
    'Isha':    Icons.nightlight_round,
  };

  String get _adhanPref => 'prayer_adhan_${widget.name.toLowerCase()}';
  String get _notifPref => 'prayer_notif_${widget.name.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _adhanOn = prefs.getBool(_adhanPref) ?? false;
      _notifOn = prefs.getBool(_notifPref) ?? false;
    });
  }

  Future<void> _setAdhan(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adhanPref, v);
    if (mounted) setState(() => _adhanOn = v);
  }

  Future<void> _setNotif(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPref, v);
    if (mounted) setState(() => _notifOn = v);
  }

Widget _togglesColumn(Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconToggle(
            icon: Icons.volume_up_rounded,
            value: _adhanOn,
            color: color,
            onChanged: _setAdhan,
            tooltip: 'Adhan',
          ),
          const SizedBox(height: 4),
          _IconToggle(
            icon: Icons.notifications_rounded,
            value: _notifOn,
            color: color,
            onChanged: _setNotif,
            tooltip: 'Notification',
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    const color  = _kActiveGreen;
    final isDark = widget.isDark;

    // ── Carte : prière suivante ────────────────────────────────────────────
    if (widget.isNext) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Color.lerp(const Color(0xFF111827), color, 0.14)!
              : Color.lerp(Colors.white, color, 0.07)!,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.50), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icône avec fond dégradé
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _icons[widget.name] ?? Icons.access_time_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Nom + countdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StreamBuilder<DateTime>(
                      stream: widget.clock,
                      builder: (_, __) => Text(
                        'Dans ${widget.countdown(widget.time)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color.withValues(alpha: 0.80),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Heure
              Text(
                widget.time,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 10),
              _togglesColumn(color),
            ],
          ),
        ),
      );
    }

    // ── Ligne épurée : autres prières ─────────────────────────────────────
    final nameColor = isDark ? Colors.white.withValues(alpha: 0.80) : const Color(0xFF374151);
    final timeColor = isDark ? Colors.white.withValues(alpha: 0.60) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      child: Row(
        children: [
          // Icône sans fond
          Icon(
            _icons[widget.name] ?? Icons.access_time_rounded,
            color: _kTeal.withValues(alpha: 0.70),
            size: 20,
          ),
          const SizedBox(width: 12),
          // Nom
          Expanded(
            child: Text(
              widget.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: nameColor,
              ),
            ),
          ),
          // Heure
          Text(
            widget.time,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: timeColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 10),
          _togglesColumn(color),
        ],
      ),
    );
  }
}

// Mini toggle icon (adhan / notif)
class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final String tooltip;

  const _IconToggle({
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 26,
          decoration: BoxDecoration(
            color: value
                ? color.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 16,
            color: value
                ? color
                : Colors.grey.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

// ── ADHAN SECTION ─────────────────────────────────────────────────────────────

class _AdhanSection extends StatefulWidget {
  final bool isDark;
  const _AdhanSection({required this.isDark});

  @override
  State<_AdhanSection> createState() => _AdhanSectionState();
}

class _AdhanSectionState extends State<_AdhanSection> {
  String _muezzin      = 'AbdulBaset';
  bool   _adhanEnabled = false;
  final AudioPlayer _player = AudioPlayer();
  String? _playing;
  String? _downloading;
  Timer? _autoStopTimer;

  /// Retourne le chemin local du fichier adhan (télécharge si absent du cache).
  Future<String> _getOrDownloadAdhan(String key) async {
    final dir  = await getApplicationCacheDirectory();
    final file = File('${dir.path}/adhan_$key.mp3');
    if (!await file.exists()) {
      final res = await http.get(Uri.parse(_kAdhanUrls[key]!));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await file.writeAsBytes(res.bodyBytes);
    }
    return file.path;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _muezzin      = prefs.getString('prayer_muezzin') ?? 'AbdulBaset';
      _adhanEnabled = prefs.getBool('adhan_enabled')    ?? false;
    });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_enabled', v);
    if (mounted) setState(() => _adhanEnabled = v);
  }

  Future<void> _setMuezzin(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_muezzin', key);
    if (mounted) setState(() => _muezzin = key);
  }

  Color get _accentColor => _kTeal;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg     = isDark ? const Color(0xFF111827) : Colors.white;
    final txtP   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtS   = isDark ? Colors.white54 : Colors.black45;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'SON DE L\'ADHAN', isDark: isDark),

        // Toggle global adhan
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text('Adhan à la prière',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: txtP)),
            subtitle: Text("Jouer l'appel à la prière",
                style: TextStyle(fontSize: 12, color: txtS)),
            value: _adhanEnabled,
            onChanged: _setEnabled,
            activeThumbColor: Colors.white,
            activeTrackColor: _accentColor,
            inactiveThumbColor: Colors.grey.shade400,
          ),
        ),

        const SizedBox(height: 8),

        // Sélecteur muezzin
        AnimatedOpacity(
          opacity: _adhanEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 220),
          child: GestureDetector(
            onTap: _adhanEnabled ? () => _showMuezzinSheet(context) : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // avatar icône muezzin
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kTeal, _kTeal2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _kTeal.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.record_voice_over_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Muezzin',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: txtP)),
                        Text(_kMuezzins[_muezzin] ?? _muezzin,
                            style: TextStyle(fontSize: 12, color: txtS)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white30 : Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMuezzinSheet(BuildContext context) {
    final isDark = widget.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final txtP = isDark ? Colors.white : const Color(0xFF0F172A);
          final txtS = isDark ? Colors.white54 : Colors.black45;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Choisir un Muezzin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: txtP,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _kMuezzins.entries.map((e) {
                    final sel         = e.key == _muezzin;
                    final playing     = _playing == e.key;
                    final downloading = _downloading == e.key;

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.fromLTRB(20, 4, 12, 4),
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: sel
                              ? _kTeal
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          sel
                              ? Icons.check_rounded
                              : Icons.person_rounded,
                          color: sel
                              ? Colors.white
                              : (isDark ? Colors.white38 : Colors.black38),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? _kTeal : txtP,
                        ),
                      ),
                      subtitle: sel
                          ? Text('Sélectionné',
                              style:
                                  TextStyle(fontSize: 11, color: txtS))
                          : null,
                      trailing: GestureDetector(
                        onTap: () async {
                          if (playing) {
                            _autoStopTimer?.cancel();
                            await _player.stop();
                            setSheet(() => _playing = null);
                            if (mounted) setState(() => _playing = null);
                          } else {
                            // Indique le téléchargement/chargement
                            setSheet(() => _downloading = e.key);
                            if (mounted) setState(() => _downloading = e.key);
                            try {
                              await _player.stop();
                              final path = await _getOrDownloadAdhan(e.key);
                              setSheet(() {
                                _downloading = null;
                                _playing = e.key;
                              });
                              if (mounted) {
                                setState(() {
                                  _downloading = null;
                                  _playing = e.key;
                                });
                              }
                              await _player.setAudioSource(
                                AudioSource.uri(
                                  Uri.file(path),
                                  tag: MediaItem(
                                    id: 'adhan_${e.key}',
                                    title: e.value,
                                    artist: 'Adhan',
                                  ),
                                ),
                              );
                              await _player.play();
                              // Auto-stop après 30 s
                              _autoStopTimer?.cancel();
                              _autoStopTimer = Timer(const Duration(seconds: 30), () {
                                _player.stop();
                                if (mounted) setState(() => _playing = null);
                              });
                            } catch (err) {
                              setSheet(() {
                                _downloading = null;
                                _playing = null;
                              });
                              if (mounted) {
                                setState(() {
                                  _downloading = null;
                                  _playing = null;
                                });
                              }
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Impossible de charger l\'aperçu audio'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: playing
                                ? _kTeal.withValues(alpha: 0.15)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kTeal,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  color: _kTeal,
                                  size: 22,
                                ),
                        ),
                      ),
                      onTap: () {
                        _setMuezzin(e.key);
                        _player.stop();
                        setSheet(() => _playing = null);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 10),
            ],
          );
        },
      ),
    ).whenComplete(() {
      _player.stop();
      if (mounted) setState(() => _playing = null);
    });
  }
}

// ── NOTIFICATION SECTION ──────────────────────────────────────────────────────

class _NotifSection extends StatefulWidget {
  final bool isDark;
  const _NotifSection({required this.isDark});

  @override
  State<_NotifSection> createState() => _NotifSectionState();
}

class _NotifSectionState extends State<_NotifSection> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _enabled = prefs.getBool('prayer_notifications_enabled') ?? false);
  }

  Future<void> _set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_notifications_enabled', v);
    if (mounted) setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg     = isDark ? const Color(0xFF111827) : Colors.white;
    final txtP   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtS   = isDark ? Colors.white54 : Colors.black45;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'NOTIFICATIONS', isDark: isDark),

        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text('Rappels de prière',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: txtP)),
                subtitle: Text('Notification avant chaque prière',
                    style: TextStyle(fontSize: 12, color: txtS)),
                value: _enabled,
                onChanged: _set,
                activeThumbColor: Colors.white,
                activeTrackColor: _kTeal,
                inactiveThumbColor: Colors.grey.shade400,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _enabled
                    ? Column(
                        children: [
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Icon(Icons.access_time_rounded,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 22),
                            title: Text('Délai avant la prière',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: txtP)),
                            subtitle: Text('5 minutes avant',
                                style:
                                    TextStyle(fontSize: 12, color: txtS)),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Les notifications nécessitent les permissions de l\'application. '
            'Activez-les dans les réglages de votre téléphone si besoin.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.26),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

// ── STARFIELD PAINTER ─────────────────────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const count = 65;
    final rng   = math.Random(42);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x  = rng.nextDouble() * size.width;
      final y  = rng.nextDouble() * size.height;
      final r  = rng.nextDouble() * 1.3 + 0.2;
      final op = rng.nextDouble() * 0.5 + 0.12;
      paint.color = Colors.white.withValues(alpha: op);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── DATA ──────────────────────────────────────────────────────────────────────

class _PrayersData {
  final String city;
  final String country;
  final String method;
  final String hijriLine;
  final Map<String, String> times;

  const _PrayersData({
    required this.city,
    required this.country,
    required this.method,
    required this.hijriLine,
    required this.times,
  });

  factory _PrayersData.error({
    required String city,
    required String country,
    required String method,
  }) =>
      _PrayersData(
        city: city,
        country: country,
        method: method,
        hijriLine: '',
        times: const {},
      );
}
