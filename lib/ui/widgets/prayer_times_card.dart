import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _defaultCity = 'Paris';
const String _defaultCountry = 'France';

class PrayerTimesCard extends StatefulWidget {
  final double topInset;

  const PrayerTimesCard({super.key, this.topInset = 0});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  static const String _prefCity = 'prayer_city';
  static const String _prefCountry = 'prayer_country';

  late Future<_PrayerTimesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTimes();
  }

  Future<_PrayerTimesData> _loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final city = (prefs.getString(_prefCity) ?? _defaultCity).trim();
    final country = (prefs.getString(_prefCountry) ?? _defaultCountry).trim();

    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': city,
      'country': country,
      'method': '2',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _PrayerTimesData.error(
          city: city,
          country: country,
          message: 'Erreur de chargement',
        );
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>?;
      final timings = data?['timings'] as Map<String, dynamic>? ?? const {};

      return _PrayerTimesData(
        city: city,
        country: country,
        times: _extractTimes(timings),
      );
    } catch (_) {
      return _PrayerTimesData.error(
        city: city,
        country: country,
        message: 'Connexion impossible',
      );
    }
  }

  Map<String, String> _extractTimes(Map<String, dynamic> timings) {
    return {
      'Fajr': _cleanTime(timings['Fajr']),
      'Dhuhr': _cleanTime(timings['Dhuhr']),
      'Asr': _cleanTime(timings['Asr']),
      'Maghrib': _cleanTime(timings['Maghrib']),
      'Isha': _cleanTime(timings['Isha']),
    };
  }

  String _cleanTime(dynamic raw) {
    if (raw == null) return '--:--';
    final value = raw.toString().trim();
    if (value.isEmpty) return '--:--';
    return value.split(' ').first;
  }

  Future<void> _editLocation(String city, String country) async {
    final cityController = TextEditingController(text: city);
    final countryController = TextEditingController(text: country);
    final result = await showDialog<_LocationResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Localisation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'Ville'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Pays'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _LocationResult(
                  city: cityController.text.trim(),
                  country: countryController.text.trim(),
                ),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    cityController.dispose();
    countryController.dispose();

    if (result == null) return;
    if (result.city.isEmpty || result.country.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCity, result.city);
    await prefs.setString(_prefCountry, result.country);

    if (!mounted) return;
    setState(() => _future = _loadTimes());
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.08);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B1F2A);
    final subColor = isDark ? Colors.white70 : Colors.black54;

    return FutureBuilder<_PrayerTimesData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final resolved = data ?? _PrayerTimesData.loading();
        final next = _nextPrayer(resolved.times);

        final nextName = _nextPrayer(resolved.times) ?? 'Fajr';
        final nextTime = resolved.times[nextName] ?? '--:--';
        final remaining = _remainingTo(nextTime);

        final rows = resolved.times.entries
            .map((e) => PrayerRowData(e.key, e.value, isNext: e.key == nextName))
            .toList();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final subColor = isDark ? Colors.white70 : Colors.black54;

        return Padding(
          padding: EdgeInsets.only(top: widget.topInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  PrayerTimesHeroCard(
                    location: '${resolved.city}, ${resolved.country}',
                    dateLine: _formatDateLine(DateTime.now()),
                    nextPrayerName: nextName,
                    nextPrayerTime: nextTime,
                    remaining: remaining,
                    rows: rows,
                  ),

                  // Boutons (edit + refresh) en haut à droite
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.edit_location_rounded, size: 18, color: Colors.white),
                                onPressed: () => _editLocation(resolved.city, resolved.country),
                                tooltip: 'Changer ville',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                                onPressed: () => setState(() => _future = _loadTimes()),
                                tooltip: 'Actualiser',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (resolved.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  resolved.message!,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String? _nextPrayer(Map<String, String> times) {
    if (times.isEmpty) return null;
    final now = DateTime.now();
    for (final entry in times.entries) {
      final time = _parseToday(entry.value, now);
      if (time != null && time.isAfter(now)) {
        return entry.key;
      }
    }
    return times.keys.first;
  }

  DateTime? _parseToday(String time, DateTime now) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _remainingTo(String time) {
    final now = DateTime.now();
    final dt = _parseToday(time, now);
    if (dt == null) return '--:--';

    var target = dt;
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1)); // ex: après Isha -> Fajr demain
    }

    final diff = target.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatDateLine(DateTime now) {
    const wd = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${wd[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String time;
  final bool isHighlighted;
  final bool isDark;

  const _TimeChip({
    required this.label,
    required this.time,
    required this.isHighlighted,
    required this.isDark,
  });


  @override
  Widget build(BuildContext context) {
    final Color baseColor = isDark ? Colors.white : const Color(0xFF0B3D1F);
    final Color bg = isHighlighted
        ? (isDark ? Colors.white.withOpacity(0.2) : const Color(0xFF1F8F4A).withOpacity(0.18))
        : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF0F5A2A).withOpacity(0.15));

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? baseColor.withOpacity(isDark ? 0.6 : 0.35)
              : baseColor.withOpacity(0.12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: baseColor.withOpacity(isDark ? 0.9 : 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: baseColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimesData {
  final String city;
  final String country;
  final Map<String, String> times;
  final String? message;

  const _PrayerTimesData({
    required this.city,
    required this.country,
    required this.times,
    this.message,
  });

  factory _PrayerTimesData.error({
    required String city,
    required String country,
    required String message,
  }) {
    return _PrayerTimesData(
      city: city,
      country: country,
      times: const {
        'Fajr': '--:--',
        'Dhuhr': '--:--',
        'Asr': '--:--',
        'Maghrib': '--:--',
        'Isha': '--:--',
      },
      message: message,
    );
  }

  factory _PrayerTimesData.loading() {
    return const _PrayerTimesData(
      city: _defaultCity,
      country: _defaultCountry,
      times: {
        'Fajr': '--:--',
        'Dhuhr': '--:--',
        'Asr': '--:--',
        'Maghrib': '--:--',
        'Isha': '--:--',
      },
      message: 'Chargement...',
    );
  }
}

class _LocationResult {
  final String city;
  final String country;

  const _LocationResult({required this.city, required this.country});
}

class PrayerRowData {
  final String name;
  final String time;
  final bool isNext;
  const PrayerRowData(this.name, this.time, {this.isNext = false});
}

class PrayerTimesHeroCard extends StatelessWidget {
  final String location;
  final String dateLine;        // ex: "Mer. 28 jan • 17 Rajab"
  final String nextPrayerName;  // ex: "Asr"
  final String nextPrayerTime;  // ex: "15:42"
  final String remaining;       // ex: "01:12"
  final List<PrayerRowData> rows;
  final VoidCallback? onTap;

  const PrayerTimesHeroCard({
    super.key,
    required this.location,
    required this.dateLine,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.remaining,
    required this.rows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fg = Colors.white;
    final Color fgSoft = Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background image
            Container(
              height: 230,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/fond_widget_vert.webp'),
                  fit: BoxFit.cover,
                  // assombrit pour que le texte reste lisible
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF0B3D1F).withOpacity(isDark ? 0.45 : 0.22),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),

            // Light overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(isDark ? 0.45 : 0.30),
                        Colors.black.withOpacity(isDark ? 0.25 : 0.15),
                        Colors.black.withOpacity(isDark ? 0.55 : 0.35),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Glass content
            // Content (sans grand cadre transparent)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header line
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateLine,
                                style: TextStyle(
                                  color: fgSoft,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Next prayer au centre (seul cadre conservé = WetGlass)
                    Expanded(
                      child: Center(
                        child: WetGlassNextPrayer(
                          nextPrayerName: nextPrayerName,
                          nextPrayerTime: nextPrayerTime,
                          remaining: remaining,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerPill extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;
  final bool isDark;

  const _PrayerPill({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = isDark ? const Color(0xFFE5E7EB) : Colors.white;

    final bg = isNext
        ? const Color(0xFF1F8F4A).withOpacity(0.22)
        : Colors.white.withOpacity(isDark ? 0.08 : 0.14);

    final border = isNext
        ? const Color(0xFF1F8F4A).withOpacity(0.35)
        : Colors.white.withOpacity(isDark ? 0.12 : 0.20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: fg.withOpacity(isNext ? 1 : 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            time,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// White text accent
const Color gold = Color(0xFFFFFFFF);

class WetGlassNextPrayer extends StatelessWidget {
  final String nextPrayerName;
  final String nextPrayerTime;
  final String remaining;
  final bool isDark;

  const WetGlassNextPrayer({
    super.key,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.remaining,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const Color textMain = Colors.white;
    final Color textSoft = Colors.white.withOpacity(0.85);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Fond vitre
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isDark ? 0.08 : 0.14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.14 : 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prochaine prière',
                    style: TextStyle(
                      color: textSoft, // BLANC
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        nextPrayerName,
                        style: TextStyle(
                          color: textMain, // BLANC
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(color: Colors.white.withOpacity(0.55), blurRadius: 14),
                            Shadow(color: Colors.white.withOpacity(0.25), blurRadius: 28),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        nextPrayerTime,
                        style: TextStyle(
                          color: textMain, // BLANC
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          shadows: [
                            Shadow(color: Colors.white.withOpacity(0.55), blurRadius: 14),
                            Shadow(color: Colors.white.withOpacity(0.25), blurRadius: 28),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                      ),
                    ),
                    child: Text(
                      '- $remaining',
                      style: TextStyle(
                        color: textMain, // BLANC
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        shadows: [
                          Shadow(color: Colors.white.withOpacity(0.45), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Effet "vitre mouillée"
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      left: -40,
                      top: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(isDark ? 0.12 : 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    _drop(24, 18, 16, isDark),
                    _drop(58, 40, 10, isDark),
                    _drop(120, 26, 12, isDark),
                    _drop(210, 18, 14, isDark),
                    _drop(280, 44, 10, isDark),
                    _drop(70, 110, 14, isDark),
                    _drop(170, 118, 10, isDark),
                    _drop(260, 108, 12, isDark),

                    Positioned(
                      right: 26,
                      top: 78,
                      child: Transform.rotate(
                        angle: 0.25,
                        child: Container(
                          width: 90,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(isDark ? 0.10 : 0.16),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _drop(double left, double top, double size, bool isDark) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(isDark ? 0.10 : 0.14),
          border: Border.all(
            color: Colors.white.withOpacity(isDark ? 0.12 : 0.18),
          ),
        ),
      ),
    );
  }
}
