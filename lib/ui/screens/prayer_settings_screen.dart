import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/location_service.dart';
import '../widgets/location_picker_dialog.dart';
import 'notification_settings_screen.dart';

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
  static const String _prefMuezzin = 'prayer_muezzin';

  static const String _defaultCity = 'Paris';
  static const String _defaultCountry = 'France';
  static const String _defaultMethod = '12';

  static const bool _defaultAdhanEnabled = false;
  static const String _defaultMuezzin = 'AbdulBaset';

  String _city = _defaultCity;
  String _country = _defaultCountry;
  String _method = _defaultMethod;

  bool _adhanEnabled = _defaultAdhanEnabled;
  String _muezzin = _defaultMuezzin;

  final List<Map<String, String>> _methods = const [
    {'id': '2',  'label': 'ISNA'},
    {'id': '3',  'label': 'Muslim World League'},
    {'id': '4',  'label': 'Umm al-Qura, Makkah'},
    {'id': '5',  'label': 'Egyptian Authority'},
    {'id': '8',  'label': 'Gulf Region'},
    {'id': '9',  'label': 'Kuwait'},
    {'id': '10', 'label': 'Qatar'},
    {'id': '11', 'label': 'Singapour (MUIS)'},
    {'id': '12', 'label': 'UOIF – France'},
    {'id': '13', 'label': 'Turkey (Diyanet)'},
    {'id': '14', 'label': 'Russie'},
    {'id': '15', 'label': 'Moon Sighting Committee'},
    {'id': '16', 'label': 'Dubai'},
    {'id': '17', 'label': 'Malaysia (JAKIM)'},
    {'id': '18', 'label': 'Tunisie'},
    {'id': '19', 'label': 'Algérie'},
    {'id': '20', 'label': 'Indonésie (KEMENAG)'},
    {'id': '21', 'label': 'Maroc'},
    {'id': '22', 'label': 'Portugal'},
    {'id': '23', 'label': 'Jordanie'},
  ];

  // key → display name (même liste que prayers_screen.dart)
  static const Map<String, String> _muezzins = {
    'AbdulBaset':          'Abdul Basit Abdul Samad',
    'AbdulBaset_Mujawwad': 'Abdul Basit (Mujawwad)',
    'Sudais':              'Abdurrahman As-Sudais',
    'Alafasy':             'Mishary Rashid Alafasy',
    'Husary':              'Mahmoud Khalil Al-Husary',
    'Minshawi':            'Mohamed Siddiq El-Minshawi',
    'Ghamadi':             'Saad Al-Ghamdi',
  };

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
      _muezzin = _muezzins.containsKey(muezzin) ? muezzin : _defaultMuezzin;
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Méthode de calcul',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _methodLabel(_method),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _method,
                      isExpanded: true,
                      items: _methods
                          .map((m) => DropdownMenuItem<String>(
                                value: m['id'],
                                child: Text(
                                  m['label']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _saveMethod(v);
                      },
                    ),
                  ),
                ],
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
              title: const Text("Activer l'adhan"),
              subtitle: const Text("Lecture audio lors de l'heure de prière"),
              value: _adhanEnabled,
              onChanged: (v) => _saveAdhanEnabled(v),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over_rounded),
              title: const Text('Muezzin'),
              subtitle: Text(_muezzins[_muezzin] ?? _muezzin),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _muezzin,
                  items: _muezzins.entries
                      .map((e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
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

          const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_rounded,
                  color: Color(0xFFF97316)),
              title: const Text('Configurer les notifications'),
              subtitle: const Text(
                  'Rappels de prières et rappel de lecture quotidien'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
