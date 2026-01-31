import 'package:flutter/material.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';
import 'statistics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefMethod = 'prayer_method';
  static const String _defaultMethod = '2';

  String _method = _defaultMethod;

  final List<Map<String, String>> _methods = const [
    {'id': '2', 'label': 'ISNA (2)'},
    {'id': '3', 'label': 'Muslim World League (3)'},
    {'id': '4', 'label': 'Umm al-Qura, Makkah (4)'},
    {'id': '5', 'label': 'Egyptian General Authority (5)'},
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

  @override
  void initState() {
    super.initState();
    _loadMethod();
  }

  Future<void> _loadMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final m = (prefs.getString(_prefMethod) ?? _defaultMethod).trim();
    if (!mounted) return;
    setState(() => _method = m.isEmpty ? _defaultMethod : m);
  }

  Future<void> _saveMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMethod, value);
    if (!mounted) return;
    setState(() => _method = value);
  }

  String _methodLabel(String id) {
    return _methods.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {'label': 'ISNA (2)'},
    )['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ✅ Nouveau réglage
          ListTile(
            leading: const Icon(Icons.calculate_rounded),
            title: const Text('Méthode de calcul (prière)'),
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

          const Divider(height: 1),

          _SettingsTile(
            icon: Icons.cloud_download_rounded,
            title: 'Téléchargements',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.favorite_rounded,
            title: 'Favoris',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.bookmark_rounded,
            title: 'Signets',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.bar_chart_rounded,
            title: 'Statistiques',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}


class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
