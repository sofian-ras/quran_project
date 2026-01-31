import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  static const String _prefCity = 'prayer_city';
  static const String _prefCountry = 'prayer_country';
  static const String _prefMethod = 'prayer_method';

  static const String _defaultCity = 'Paris';
  static const String _defaultCountry = 'France';
  static const String _defaultMethod = '2';

  late Future<_PrayersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPrayers();
  }

  Future<_PrayersData> _loadPrayers() async {
    final prefs = await SharedPreferences.getInstance();

    final city = (prefs.getString(_prefCity) ?? _defaultCity).trim();
    final country = (prefs.getString(_prefCountry) ?? _defaultCountry).trim();

    final methodRaw = (prefs.getString(_prefMethod) ?? _defaultMethod).trim();
    final method = methodRaw.isEmpty ? _defaultMethod : methodRaw;

    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': city,
      'country': country,
      'method': method,
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return _PrayersData.error(city: city, country: country, method: method);
    }

    final jsonBody = json.decode(res.body) as Map<String, dynamic>;
    final data = jsonBody['data'] as Map<String, dynamic>;
    final timings = data['timings'] as Map<String, dynamic>;

    final map = <String, String>{
      'Fajr': (timings['Fajr'] ?? '').toString(),
      'Dhuhr': (timings['Dhuhr'] ?? '').toString(),
      'Asr': (timings['Asr'] ?? '').toString(),
      'Maghrib': (timings['Maghrib'] ?? '').toString(),
      'Isha': (timings['Isha'] ?? '').toString(),
    };

    return _PrayersData(
      city: city,
      country: country,
      method: method,
      times: map,
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadPrayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prières'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration prières (bientôt)')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_PrayersData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data;
          if (data == null || data.times.isEmpty) {
            return const Center(child: Text('Impossible de charger les horaires.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.city}, ${data.country}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text('Méthode: ${data.method}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...data.times.entries.map((e) {
                return Card(
                  child: ListTile(
                    title: Text(e.key),
                    trailing: Text(
                      e.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _PrayersData {
  final String city;
  final String country;
  final String method;
  final Map<String, String> times;

  const _PrayersData({
    required this.city,
    required this.country,
    required this.method,
    required this.times,
  });

  factory _PrayersData.error({
    required String city,
    required String country,
    required String method,
  }) {
    return _PrayersData(
      city: city,
      country: country,
      method: method,
      times: const {},
    );
  }
}
