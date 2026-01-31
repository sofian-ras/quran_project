import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'widgets/location_picker_dialog.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  bool _useGps = true; // true = GPS, false = manuel
  bool _loadingGps = false;

  static const String _prefCity = 'prayer_city';
  static const String _prefCountry = 'prayer_country';
  static const String _prefMethod = 'prayer_method';

  static const String _prefAdhanEnabled = 'adhan_enabled';
  static const String _prefMuezzin = 'adhan_muezzin';

  static const String _defaultCity = 'Paris';
  static const String _defaultCountry = 'France';
  static const String _defaultMethod = '2';

  static const bool _defaultAdhanEnabled = false;
  static const String _defaultMuezzin = 'Abdulbaset';

  String _city = _defaultCity;
  String _country = _defaultCountry;
  String _method = _defaultMethod;

  bool _adhanEnabled = _defaultAdhanEnabled;
  String _muezzin = _defaultMuezzin;

  final List<Map<String, String>> _methods = const [
    {'id': '2', 'label': 'ISNA (2)'},
    {'id': '3', 'label': 'Muslim World League (3)'},
    {'id': '4', 'label': 'Umm al-Qura, Makkah (4)'},
    {'id': '5', 'label': 'Egyptian Authority (5)'},
    {'id': '8', 'label': 'Gulf Region (8)'},
    {'id': '9', 'label': 'Kuwait (9)'},
    {'id': '10', 'label': 'Qatar (10)'},
    {'id': '12', 'label': 'Turkey (12)'},
    {'id': '13', 'label': 'Morocco (13)'},
    {'id': '15', 'label': 'Moon Sighting Committee (15)'},
    {'id': '16', 'label': 'Karachi (16)'},
    {'id': '18', 'label': 'France (18)'},
    {'id': '20', 'label': 'Tunisia (20)'},
    {'id': '21', 'label': 'Algeria (21)'},
  ];

  final List<String> _muezzins = const [
    'Abdulbaset',
    'Al-Sudais',
    'Mishary Alafasy',
    'Maher Al-Muaiqly',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initUseGps();
  }

  Future<void> _initUseGps() async {
    final prefs = await SharedPreferences.getInstance();
    final isManual = prefs.getBool('prayer_manual') ?? false;
    if (!mounted) return;
    setState(() => _useGps = !isManual);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final city = (prefs.getString(_prefCity) ?? _defaultCity).trim();
    final country = (prefs.getString(_prefCountry) ?? _defaultCountry).trim();

    final methodRaw = (prefs.getString(_prefMethod) ?? _defaultMethod).trim();
    final method = methodRaw.isEmpty ? _defaultMethod : methodRaw;

    final adhanEnabled = prefs.getBool(_prefAdhanEnabled) ?? _defaultAdhanEnabled;
    final muezzinRaw = (prefs.getString(_prefMuezzin) ?? _defaultMuezzin).trim();
    final muezzin = muezzinRaw.isEmpty ? _defaultMuezzin : muezzinRaw;

    if (!mounted) return;
    setState(() {
      _city = city;
      _country = country;
      _method = method;
      _adhanEnabled = adhanEnabled;
      _muezzin = _muezzins.contains(muezzin) ? muezzin : _defaultMuezzin;
    });
  }

  Future<void> _saveMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMethod, value);
    if (!mounted) return;
    setState(() => _method = value);
  }

  Future<void> _saveAdhanEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAdhanEnabled, value);
    if (!mounted) return;
    setState(() => _adhanEnabled = value);
  }

  Future<void> _saveMuezzin(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMuezzin, value);
    if (!mounted) return;
    setState(() => _muezzin = value);
  }

  String _methodLabel(String id) {
    return _methods.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {'label': 'Méthode ($id)'},
    )['label']!;
  }

  Future<void> _openLocationPicker() async {
    await showDialog(
      context: context,
      builder: (_) => const LocationPickerDialog(),
    );
    await _loadPrefs(); // recharge city/country après modification
  }

  Future<void> _toggleGps(bool v) async {
    if (v) {
      // ON -> GPS
      setState(() => _loadingGps = true);

      try {
        final location = await LocationService.refreshLocation(); // GPS + saveLocation()
        if (!mounted) return;

        if (location != null) {
          await _loadPrefs();
          if (!mounted) return;
          setState(() => _useGps = true);
        }
      } finally {
        if (!mounted) return;
        setState(() => _loadingGps = false);
      }
    } else {
      // OFF -> Manuel : ouvre le dialog ville/pays
      await _openLocationPicker(); // ce dialog doit mettre prayer_manual=true
      await _initUseGps();         // relit prayer_manual
      await _loadPrefs();          // recharge city/country affichés
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration des prières'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Localisation',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.gps_fixed_rounded),
              title: const Text('Utiliser le GPS'),
              subtitle: Text(_useGps ? 'Localisation automatique' : 'Ville / pays manuels'),
              value: _useGps,
              onChanged: _loadingGps ? null : (v) => _toggleGps(v),
            ),
          ),

          if (_loadingGps)
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              child: LinearProgressIndicator(),
            ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text('$_city, $_country'),
              subtitle: Text(_useGps ? 'Position actuelle' : 'Changer la ville (manuel)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _useGps ? null : _openLocationPicker,
            ),
          ),

          const SizedBox(height: 16),


          const Text(
            'Calcul',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate_rounded),
              title: const Text('Méthode de calcul'),
              subtitle: Text(_methodLabel(_method)),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _method,
                  items: _methods
                      .map((m) => DropdownMenuItem<String>(
                            value: m['id'],
                            child: Text(m['label']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _saveMethod(v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Adhan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Activer l’adhan'),
              subtitle: const Text('Lecture audio lors de l’heure de prière'),
              value: _adhanEnabled,
              onChanged: (v) => _saveAdhanEnabled(v),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over_rounded),
              title: const Text('Muezzin'),
              subtitle: Text(_muezzin),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _muezzin,
                  items: _muezzins
                      .map((m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(m),
                          ))
                      .toList(),
                  onChanged: _adhanEnabled
                      ? (v) {
                          if (v == null) return;
                          _saveMuezzin(v);
                        }
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Indication (sans fonctionnalité encore)
          const Text(
            'Notifications & audio (bientôt)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_rounded),
              title: Text('Notifications'),
              subtitle: Text('On ajoutera les rappels et l’adhan en arrière-plan plus tard.'),
            ),
          ),
        ],
      ),
    );
  }
}
