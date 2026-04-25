// lib/ui/dua_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/dua_db.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  bool _loading = true;
  String? _error;

  String _query = '';
  Timer? _debounce;
  List<Map<String, Object?>> _cats = [];
  Map<String, Object?>? _duaOfDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _init() async {
    try {
      await DuaDb.instance.importFromAssetsIfEmpty();
      final cats = await DuaDb.instance.getCategories();

      Map<String, Object?>? duaOfDay;
      if (cats.isNotEmpty) {
        final firstCatId = cats.first['id'] as String;
        final duas = await DuaDb.instance.getDuasByCategory(firstCatId);
        if (duas.isNotEmpty) {
          final idx = DateTime.now().day % duas.length;
          duaOfDay = duas[idx];
        }
      }

      if (!mounted) return;
      setState(() {
        _cats = cats;
        _duaOfDay = duaOfDay;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Duʿa")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Erreur:\n\n$_error"),
        ),
      );
    }

    final dua = _duaOfDay;
    final scheme = Theme.of(context).colorScheme;

    final bg = scheme.brightness == Brightness.dark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF2ECE5);
    final card = scheme.brightness == Brightness.dark
        ? const Color(0xFF111B2E)
        : const Color(0xFFF6F1EB);
    final stroke = scheme.brightness == Brightness.dark ? Colors.white12 : Colors.black12;
    final green = const Color(0xFF4B6B52);

    String _catTitle(Map<String, Object?> c) {
      final fr = (c['title_fr'] as String?)?.trim() ?? '';
      final en = (c['title_en'] as String?)?.trim() ?? '';
      final ar = (c['title_ar'] as String?)?.trim() ?? '';
      return fr.isNotEmpty ? fr : (en.isNotEmpty ? en : ar);
    }

    String _catSubtitle(Map<String, Object?> c) {
      final fr = (c['title_fr'] as String?)?.trim() ?? '';
      final en = (c['title_en'] as String?)?.trim() ?? '';
      final ar = (c['title_ar'] as String?)?.trim() ?? '';

      // Si on affiche EN/FR en titre, et qu'on a un arabe dispo -> sous-titre
      if ((fr.isNotEmpty || en.isNotEmpty) && ar.isNotEmpty) return ar;

      // Sinon rien
      return '';
    }

    // Filtre catégories via recherche (fr/en/ar)
    final filteredCats = _query.trim().isEmpty
        ? _cats
        : _cats.where((c) {
            final fr = ((c['title_fr'] as String?) ?? '').toLowerCase();
            final en = ((c['title_en'] as String?) ?? '').toLowerCase();
            final ar = ((c['title_ar'] as String?) ?? '').toLowerCase();
            final q = _query.toLowerCase();
            return fr.contains(q) || en.contains(q) || ar.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Duʿa",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: green,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings_rounded, color: green),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final horizontal = w < 380 ? 12.0 : 16.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 18),
            children: [
              _searchBar(
                card: card,
                stroke: stroke,
                green: green,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),

              Text(
                "Duʿa du jour",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.brightness == Brightness.dark ? Colors.white : const Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 10),

              if (dua != null)
                _duaOfDayCard(
                  dua: dua,
                  card: card,
                  stroke: stroke,
                  green: green,
                  onListen: () {},
                  onOpen: () {},
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Aucun duʿa disponible.",
                    style: TextStyle(
                      color: scheme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Catégories",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.brightness == Brightness.dark ? Colors.white : const Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DuaAllCategoriesScreen()),
                      );
                    },
                    child: Text(
                      "Tout voir  >",
                      style: TextStyle(color: green, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = filteredCats[i];
                  final id = c['id'] as String;

                  final title = _catTitle(c);
                  final subtitle = _catSubtitle(c);

                  return _categoryTile(
                    context: context,
                    title: title,
                    subtitle: subtitle,
                    card: card,
                    stroke: stroke,
                    green: green,
                    icon: _iconForCategoryTitle(title),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DuaCategoryScreen(
                            categoryId: id,
                            title: title,
                            subtitle: subtitle,
                            icon: _iconForCategoryTitle(title),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconForCategoryTitle(String title) {
    final x = title.toLowerCase();
    if (x.contains('morning')) return Icons.wb_sunny_outlined;
    if (x.contains('evening') || x.contains('night')) return Icons.nights_stay_outlined;
    if (x.contains('prayer')) return Icons.mosque_outlined;
    if (x.contains('sleep')) return Icons.bedtime_outlined;
    if (x.contains('travel')) return Icons.flight_takeoff_outlined;
    if (x.contains('rain')) return Icons.umbrella_outlined;
    if (x.contains('fear') || x.contains('anxiety')) return Icons.shield_outlined;
    if (x.contains('forgiveness')) return Icons.volunteer_activism_outlined;
    return Icons.category_outlined;
  }
}

Widget _searchBar({
  required Color card,
  required Color stroke,
  required Color green,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: stroke),
      boxShadow: const [
        BoxShadow(
          blurRadius: 10,
          offset: Offset(0, 4),
          color: Color(0x14000000),
        ),
      ],
    ),
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: "Rechercher un duʿa (ar/en/fr)",
        prefixIcon: Icon(Icons.search, color: green),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
  );
}

Widget _duaOfDayCard({
  required Map<String, Object?> dua,
  required Color card,
  required Color stroke,
  required Color green,
  required VoidCallback onListen,
  required VoidCallback onOpen,
}) {
  final ar = (dua['ar'] as String?) ?? '';
  final fr = (dua['fr'] as String?) ?? '';
  final en = (dua['en'] as String?) ?? '';

  // Fallback: FR -> EN -> (vide)
  final shown = fr.trim().isNotEmpty ? fr : en;

  return Container(
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: stroke),
      boxShadow: const [
        BoxShadow(blurRadius: 14, offset: Offset(0, 6), color: Color(0x16000000)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ar,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 8),
          if (shown.trim().isNotEmpty) Text(shown, style: const TextStyle(height: 1.25)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 360;
              final listenBtn = _primaryButton(
                green: green,
                label: "Écouter",
                icon: Icons.play_arrow_rounded,
                onTap: onListen,
              );
              final openBtn = _secondaryButton(stroke: stroke, label: "Ouvrir", onTap: onOpen);

              if (narrow) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: listenBtn),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: openBtn),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: listenBtn),
                  const SizedBox(width: 10),
                  Expanded(child: openBtn),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _primaryButton({
  required Color green,
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return ElevatedButton.icon(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    icon: Icon(icon),
    label: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

Widget _secondaryButton({
  required Color stroke,
  required String label,
  required VoidCallback onTap,
}) {
  return OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: stroke),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

Widget _categoryTile({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Color card,
  required Color stroke,
  required Color green,
  required IconData icon,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final mutedColor = isDark ? Colors.white70 : Colors.black.withOpacity(0.55);

  return Material(
    color: card,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: green, size: 22),
            ),
            const SizedBox(width: 14),
            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.88),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 13, color: mutedColor, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: mutedColor, size: 20),
          ],
        ),
      ),
    ),
  );
}

// ---------------------
// Tout voir catégories
// ---------------------
class DuaAllCategoriesScreen extends StatefulWidget {
  const DuaAllCategoriesScreen({super.key});

  @override
  State<DuaAllCategoriesScreen> createState() => _DuaAllCategoriesScreenState();
}

class _DuaAllCategoriesScreenState extends State<DuaAllCategoriesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, Object?>> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _catTitle(Map<String, Object?> c) {
    final fr = (c['title_fr'] as String?)?.trim() ?? '';
    final en = (c['title_en'] as String?)?.trim() ?? '';
    final ar = (c['title_ar'] as String?)?.trim() ?? '';
    return fr.isNotEmpty ? fr : (en.isNotEmpty ? en : ar);
  }

  String _catSubtitle(Map<String, Object?> c) {
    final fr = (c['title_fr'] as String?)?.trim() ?? '';
    final en = (c['title_en'] as String?)?.trim() ?? '';
    final ar = (c['title_ar'] as String?)?.trim() ?? '';
    if ((fr.isNotEmpty || en.isNotEmpty) && ar.isNotEmpty) return ar;
    return '';
  }

  Future<void> _load() async {
    try {
      final cats = await DuaDb.instance.getCategories();
      if (!mounted) return;
      setState(() {
        _cats = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = const Color(0xFF4B6B52);

    return Scaffold(
      appBar: AppBar(title: const Text("Catégories")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Erreur:\n\n$_error"),
                )
              : ListView.separated(
                  itemCount: _cats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _cats[i];
                    final id = c['id'] as String;

                    final title = _catTitle(c);
                    final subtitle = _catSubtitle(c);

                    return ListTile(
                      leading: Icon(Icons.category_rounded, color: green),
                      title: Text(title),
                      subtitle: subtitle.isNotEmpty
                          ? Text(
                              subtitle,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: scheme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              ),
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DuaCategoryScreen(
                              categoryId: id,
                              title: title,
                              subtitle: subtitle,
                              icon: Icons.category_rounded,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// ---------------------
// Page catégorie (mockup #2)
// ---------------------
class DuaCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String title;
  final String subtitle;
  final IconData icon;

  const DuaCategoryScreen({
    super.key,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<DuaCategoryScreen> createState() => _DuaCategoryScreenState();
}

class _DuaCategoryScreenState extends State<DuaCategoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, Object?>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await DuaDb.instance.getDuasByCategory(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Erreur:\n\n$_error"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final dua = _items[i];
          final ar = (dua['ar'] as String?) ?? '';
          final fr = (dua['fr'] as String?) ?? '';
          final en = (dua['en'] as String?) ?? '';
          final shown = fr.trim().isNotEmpty ? fr : en;

          return ListTile(
            title: Text(ar, textDirection: TextDirection.rtl),
            subtitle: shown.trim().isNotEmpty ? Text(shown) : null,
          );
        },
      ),
    );
  }
}