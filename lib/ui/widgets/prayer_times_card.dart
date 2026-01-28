import 'dart:convert';

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

        return Container(
          padding: EdgeInsets.fromLTRB(14, 12 + widget.topInset, 14, 14),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1A0033), Color(0xFF2D1B4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFFFDFDFD),
                      const Color(0xFFF4F7FB),
                      const Color(0xFFE8EEF7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1E3A2F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horaires de prieres',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${resolved.city}, ${resolved.country}',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editLocation(resolved.city, resolved.country),
                    icon: Icon(Icons.edit_location_rounded, color: subColor),
                    tooltip: 'Changer ville',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _future = _loadTimes()),
                    icon: Icon(Icons.refresh_rounded, color: subColor),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: resolved.times.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final entry = resolved.times.entries.elementAt(index);
                    final isNext = entry.key == next;
                    return _TimeChip(
                      label: entry.key,
                      time: entry.value,
                      isHighlighted: isNext,
                      isDark: isDark,
                    );
                  },
                ),
              ),
              if (resolved.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  resolved.message!,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    final Color baseColor = isDark ? Colors.white : const Color(0xFF1E3A2F);
    final Color bg = isHighlighted
        ? (isDark ? Colors.white.withOpacity(0.2) : const Color(0xFF1E3A2F).withOpacity(0.12))
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05));

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
