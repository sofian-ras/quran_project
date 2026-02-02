import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'prayer_settings_screen.dart';
import '../services/location_service.dart';



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

  String _methodLabel(String id) {
    switch (id) {
      case '2':
        return 'ISNA (2)';
      case '3':
        return 'Muslim World League (3)';
      case '4':
        return 'Umm al-Qura (4)';
      case '5':
        return 'Egyptian Authority (5)';
      case '8':
        return 'Gulf Region (8)';
      case '9':
        return 'Kuwait (9)';
      case '10':
        return 'Qatar (10)';
      case '12':
        return 'Turkey (12)';
      case '13':
        return 'Morocco (13)';
      case '15':
        return 'Moon Sighting Committee (15)';
      case '16':
        return 'Karachi (16)';
      case '18':
        return 'France (18)';
      case '20':
        return 'Tunisia (20)';
      case '21':
        return 'Algeria (21)';
      default:
        return 'Méthode ($id)';
    }
  }


  @override
  void initState() {
    super.initState();
    _future = _loadPrayers();
  }

  Future<_PrayersData> _loadPrayers() async {
    final prefs = await SharedPreferences.getInstance();

    final methodRaw = (prefs.getString(_prefMethod) ?? _defaultMethod).trim();
    final method = methodRaw.isEmpty ? _defaultMethod : methodRaw;

    final location = await LocationService.getSavedOrCurrentLocation();

    Uri uri;
    if (!location.isManual && location.latitude != 0 && location.longitude != 0) {
      uri = Uri.https('api.aladhan.com', '/v1/timings', {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'method': method,
      });
    } else {
      final city = (prefs.getString(_prefCity) ?? _defaultCity).trim();
      final country = (prefs.getString(_prefCountry) ?? _defaultCountry).trim();

      uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
        'city': city,
        'country': country,
        'method': method,
      });
    }

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      final city = (prefs.getString(_prefCity) ?? _defaultCity).trim();
      final country = (prefs.getString(_prefCountry) ?? _defaultCountry).trim();
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

    // Header: priorise la ville/pays de LocationService si dispo
    final headerCity = (location.city.isNotEmpty)
        ? location.city
        : (prefs.getString(_prefCity) ?? _defaultCity).trim();
    final headerCountry = (location.country.isNotEmpty)
        ? location.country
        : (prefs.getString(_prefCountry) ?? _defaultCountry).trim();

    return _PrayersData(
      city: headerCity,
      country: headerCountry,
      method: method,
      times: map,
    );
  }


  void _refresh() {
    setState(() {
      _future = _loadPrayers();
    });
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
      target = target.add(const Duration(days: 1));
    }

    final diff = target.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prières'),
        centerTitle: true,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0EA5E9),
                Color(0xFF0284C7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrayerSettingsScreen()),
              );
              _refresh();
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

          final nextName = _nextPrayer(data.times) ?? 'Fajr';

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header avec localisation et méthode
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0EA5E9), // Bleu vif ciel
                        Color(0xFF0284C7), // Bleu vif plus foncé
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '${data.city}, ${data.country}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _methodLabel(data.method),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste de toutes les prières avec bords arrondis
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      itemCount: data.times.length,
                      itemBuilder: (context, index) {
                        final entry = data.times.entries.elementAt(index);
                        final name = entry.key;
                        final time = entry.value;
                        final isNext = name == nextName;
                        final remaining = isNext ? _remainingTo(time) : null;

                        return _PrayerCard(
                          name: name,
                          time: time,
                          isNext: isNext,
                          remaining: remaining,
                          icon: _getPrayerIcon(name),
                          onAdhanChanged: () => setState(() {}),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Section paramètres de notification
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Activer notifications
                      _NotificationToggle(
                        title: 'Activer les notifications',
                        subtitle: 'Recevoir une notification à chaque prière',
                        prefKey: 'prayer_notifications_enabled',
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),

                      const SizedBox(height: 16),

                      // Choix du muezzin
                      FutureBuilder<bool>(
                        future: _isAnyAdhanEnabled(),
                        builder: (context, snap) {
                          final enabled = snap.data ?? false;
                          return _MuezzinSelector(enabled: enabled);
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _isAnyAdhanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final prayer in prayers) {
      if (prefs.getBool('prayer_adhan_${prayer.toLowerCase()}') ?? false) {
        return true;
      }
    }
    return false;
  }

  IconData _getPrayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_rounded;
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.wb_sunny;
      case 'maghrib':
        return Icons.nights_stay_rounded;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }
}

// Widget pour une carte de prière avec switch adhan
class _PrayerCard extends StatefulWidget {
  final String name;
  final String time;
  final bool isNext;
  final String? remaining;
  final IconData icon;
  final VoidCallback? onAdhanChanged;

  const _PrayerCard({
    required this.name,
    required this.time,
    required this.isNext,
    this.remaining,
    required this.icon,
    this.onAdhanChanged,
  });

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  bool _adhanEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAdhanState();
  }

  Future<void> _loadAdhanState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adhanEnabled = prefs.getBool('prayer_adhan_${widget.name.toLowerCase()}') ?? false;
    });
  }

  Future<void> _setAdhanState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_adhan_${widget.name.toLowerCase()}', value);
    setState(() {
      _adhanEnabled = value;
    });
    widget.onAdhanChanged?.call();
  }

  Color _getPrayerColor(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return const Color(0xFF6366F1); // Indigo vif
      case 'dhuhr':
        return const Color(0xFFEAB308); // Jaune doré
      case 'asr':
        return const Color(0xFFF97316); // Orange vif
      case 'maghrib':
        return const Color(0xFFEC4899); // Rose vif
      case 'isha':
        return const Color(0xFF8B5CF6); // Violet vif
      default:
        return const Color(0xFF10B981); // Vert par défaut
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayerColor = _getPrayerColor(widget.name);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: widget.isNext
          ? LinearGradient(
              colors: [
                prayerColor.withOpacity(0.15),
                prayerColor.withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
          : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  prayerColor,
                  prayerColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: prayerColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Nom et temps restant
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: widget.isNext ? prayerColor : Colors.grey[800],
                    letterSpacing: 0.2,
                  ),
                ),
                if (widget.isNext && widget.remaining != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Dans ${widget.remaining}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: prayerColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Heure
          Text(
            widget.time,
            style: TextStyle(
              fontSize: widget.isNext ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: widget.isNext ? prayerColor : Colors.grey[700],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 12),
          // Switch Adhan
          Column(
            children: [
              Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: _adhanEnabled ? prayerColor : Colors.grey[400],
              ),
              const SizedBox(height: 2),
              Transform.scale(
                scale: 0.65,
                child: Switch(
                  value: _adhanEnabled,
                  onChanged: _setAdhanState,
                  activeColor: prayerColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget pour toggle notification/adhan
class _NotificationToggle extends StatefulWidget {
  final String title;
  final String subtitle;
  final String prefKey;
  final ValueChanged<bool>? onChanged;

  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.prefKey,
    this.onChanged,
  });

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    _loadValue();
  }

  Future<void> _loadValue() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _value = prefs.getBool(widget.prefKey) ?? false;
    });
  }

  Future<void> _setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefKey, value);
    setState(() {
      _value = value;
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          widget.subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        value: _value,
        onChanged: _setValue,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

// Widget pour sélectionner le muezzin
class _MuezzinSelector extends StatefulWidget {
  final bool enabled;

  const _MuezzinSelector({required this.enabled});

  @override
  State<_MuezzinSelector> createState() => _MuezzinSelectorState();
}

class _MuezzinSelectorState extends State<_MuezzinSelector> {
  String _selected = 'AbdulBaset';
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMuezzin;

  static const Map<String, String> _muezzins = {
    'AbdulBaset': 'Abdul Basit Abdul Samad',
    'AbdulBaset_Mujawwad': 'Abdul Basit (Mujawwad)',
    'Sudais': 'Abdurrahman As-Sudais',
    'Alafasy': 'Mishary Rashid Alafasy',
    'Husary': 'Mahmoud Khalil Al-Husary',
    'Minshawi': 'Mohamed Siddiq El-Minshawi',
    'Ghamadi': 'Saad Al-Ghamdi',
  };

  // URLs d'exemple pour l'adhan de chaque muezzin (à adapter selon vos sources)
  static const Map<String, String> _adhanUrls = {
    'AbdulBaset': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'AbdulBaset_Mujawwad': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'Sudais': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'Alafasy': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'Husary': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'Minshawi': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
    'Ghamadi': 'https://www.islamcan.com/audio/adhan/adhan-makkah.mp3',
  };

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selected = prefs.getString('prayer_muezzin') ?? 'AbdulBaset';
    });
  }

  Future<void> _setSelected(String? value) async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_muezzin', value);
    setState(() {
      _selected = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.5,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(
            Icons.record_voice_over_rounded,
            color: widget.enabled ? Theme.of(context).primaryColor : Colors.grey,
            size: 28,
          ),
          title: const Text(
            'Muezzin',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _muezzins[_selected] ?? _selected,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.grey[400],
          ),
          enabled: widget.enabled,
          onTap: widget.enabled ? () => _showMuezzinPicker(context) : null,
        ),
      ),
    );
  }

  void _showMuezzinPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Choisir un Muezzin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const Divider(),
                  ListView(
                    shrinkWrap: true,
                    children: _muezzins.entries.map((entry) {
                      final isSelected = entry.key == _selected;
                      final isPlaying = _playingMuezzin == entry.key;
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey,
                        ),
                        title: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[800],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.stop_circle : Icons.play_circle,
                            color: const Color(0xFF0EA5E9),
                            size: 32,
                          ),
                          onPressed: () async {
                            if (isPlaying) {
                              await _audioPlayer.stop();
                              setModalState(() {
                                _playingMuezzin = null;
                              });
                            } else {
                              final url = _adhanUrls[entry.key];
                              if (url != null) {
                                try {
                                  await _audioPlayer.stop();
                                  await _audioPlayer.setUrl(url);
                                  await _audioPlayer.play();
                                  setModalState(() {
                                    _playingMuezzin = entry.key;
                                  });
                                  // Arrêter automatiquement après 30 secondes
                                  Future.delayed(const Duration(seconds: 30), () {
                                    _audioPlayer.stop();
                                    if (mounted) {
                                      setModalState(() {
                                        _playingMuezzin = null;
                                      });
                                    }
                                  });
                                } catch (e) {
                                  // Erreur de chargement
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Impossible de charger l\'aperçu')),
                                    );
                                  }
                                }
                              }
                            }
                          },
                        ),
                        onTap: () {
                          _setSelected(entry.key);
                          _audioPlayer.stop();
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _audioPlayer.stop();
      setState(() {
        _playingMuezzin = null;
      });
    });
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
