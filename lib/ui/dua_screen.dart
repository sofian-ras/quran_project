// lib/ui/dua_screen.dart
import 'package:flutter/material.dart';
import '../services/dua_db.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  bool _loading = true;
  String? _error;

  String _query = '';
  List<Map<String, Object?>> _cats = [];
  Map<String, Object?>? _duaOfDay;

  @override
  void initState() {
    super.initState();
    _init();
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

    // Couleurs “beige/vert” proches du mockup, sans figer des tailles
    final bg = scheme.brightness == Brightness.dark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF2ECE5);
    final card = scheme.brightness == Brightness.dark
        ? const Color(0xFF111B2E)
        : const Color(0xFFF6F1EB);
    final stroke = scheme.brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
    final green = const Color(0xFF4B6B52);

    // Filtre catégories via recherche
    final filteredCats = _query.trim().isEmpty
        ? _cats
        : _cats.where((c) {
            final fr = (c['title_fr'] as String).toLowerCase();
            final ar = (c['title_ar'] as String).toLowerCase();
            final q = _query.toLowerCase();
            return fr.contains(q) || ar.contains(q);
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
            icon: Icon(Icons.favorite_rounded, color: green),
            tooltip: 'Favoris',
          ),
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

          // marges adaptatives
          final horizontal = w < 380 ? 12.0 : 16.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 18),
            children: [
              _searchBar(
                card: card,
                stroke: stroke,
                green: green,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 12),

              _quickActionsRow(
                card: card,
                stroke: stroke,
                green: green,
                onFav: () {},
                onDl: () {},
                onHistory: () {},
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
                    style: TextStyle(color: scheme.brightness == Brightness.dark ? Colors.white70 : Colors.black54),
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

              // Grille responsive sans overflow : maxCrossAxisExtent
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCats.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: w < 420 ? 320 : 360, // 1 ou 2 colonnes selon largeur
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: w < 360 ? 2.6 : 2.9, // plus haut sur petits écrans
                ),
                itemBuilder: (_, i) {
                  final c = filteredCats[i];
                  final id = c['id'] as String;
                  final titleFr = (c['title_fr'] as String).trim();
                  final titleAr = (c['title_ar'] as String).trim();

                  final title = titleFr.isNotEmpty ? titleFr : titleAr;
                  final subtitle = (titleFr.isNotEmpty && titleAr.isNotEmpty) ? titleAr : "";

                  return _categoryTile(
                    context: context,
                    title: title,
                    subtitle: subtitle,
                    card: card,
                    stroke: stroke,
                    green: green,
                    icon: _iconForCategoryId(id),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DuaCategoryScreen(
                            categoryId: id,
                            title: title,
                            subtitle: subtitle,
                            icon: _iconForCategoryId(id),
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

  IconData _iconForCategoryId(String id) {
    final x = id.toLowerCase();
    if (x.contains('morning')) return Icons.wb_sunny_outlined;
    if (x.contains('evening')) return Icons.nights_stay_outlined;
    if (x.contains('protect')) return Icons.shield_outlined;
    if (x.contains('rizq') || x.contains('provision')) return Icons.savings_outlined;
    if (x.contains('health')) return Icons.favorite_border_rounded;
    if (x.contains('travel')) return Icons.flight_takeoff_outlined;
    if (x.contains('family')) return Icons.home_outlined;
    if (x.contains('study')) return Icons.school_outlined;
    if (x.contains('difficulty') || x.contains('hard')) return Icons.flash_on_outlined;
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
        hintText: "Rechercher un duʿa (ex: protection, rizq...)",
        prefixIcon: Icon(Icons.search, color: green),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
  );
}

Widget _quickActionsRow({
  required Color card,
  required Color stroke,
  required Color green,
  required VoidCallback onFav,
  required VoidCallback onDl,
  required VoidCallback onHistory,
}) {
  // Wrap => pas de texte coupé + s’adapte à toutes tailles
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _pillAction(card: card, stroke: stroke, green: green, icon: Icons.bookmark_rounded, label: "Favoris", onTap: onFav),
      _pillAction(card: card, stroke: stroke, green: green, icon: Icons.download_rounded, label: "Téléchargés", onTap: onDl),
      _pillAction(card: card, stroke: stroke, green: green, icon: Icons.history_rounded, label: "Historique", onTap: onHistory),
    ],
  );
}

Widget _pillAction({
  required Color card,
  required Color stroke,
  required Color green,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 140), // pas fixe, juste minimum lisible
    child: Material(
      color: card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stroke),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x12000000),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: green),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: green),
                ),
              ),
            ],
          ),
        ),
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
          Text(fr, style: const TextStyle(height: 1.25)),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 360;
              final listenBtn = _primaryButton(green: green, label: "Écouter", icon: Icons.play_arrow_rounded, onTap: onListen);
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
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
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
  return Material(
    color: card,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: stroke),
          boxShadow: const [
            BoxShadow(blurRadius: 12, offset: Offset(0, 5), color: Color(0x12000000)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                    final fr = (c['title_fr'] as String).trim();
                    final ar = (c['title_ar'] as String).trim();
                    final title = fr.isNotEmpty ? fr : ar;

                    return ListTile(
                      leading: Icon(Icons.category_rounded, color: green),
                      title: Text(title),
                      subtitle: (fr.isNotEmpty && ar.isNotEmpty)
                          ? Text(ar, textDirection: TextDirection.rtl, style: TextStyle(color: scheme.brightness == Brightness.dark ? Colors.white70 : Colors.black54))
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DuaCategoryScreen(
                              categoryId: id,
                              title: title,
                              subtitle: (fr.isNotEmpty && ar.isNotEmpty) ? ar : "",
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
    final scheme = Theme.of(context).colorScheme;

    final bg = scheme.brightness == Brightness.dark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF2ECE5);
    final card = scheme.brightness == Brightness.dark
        ? const Color(0xFF111B2E)
        : const Color(0xFFF6F1EB);
    final stroke = scheme.brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
    final green = const Color(0xFF4B6B52);

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(padding: const EdgeInsets.all(16), child: Text("Erreur:\n\n$_error"))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: bg,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: green),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: [
                        IconButton(onPressed: () {}, icon: Icon(Icons.favorite_rounded, color: green)),
                        IconButton(onPressed: () {}, icon: Icon(Icons.download_rounded, color: green)),
                      ],
                      title: Text(
                        widget.title,
                        style: TextStyle(fontWeight: FontWeight.w800, color: green),
                      ),
                      centerTitle: true,
                      expandedHeight: MediaQuery.of(context).size.width * 0.42, // responsive
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                bg,
                                bg.withOpacity(0.92),
                                bg.withOpacity(0.82),
                              ],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: _categoryHeaderCard(
                                context: context,
                                card: card,
                                stroke: stroke,
                                green: green,
                                icon: widget.icon,
                                title: widget.title,
                                subtitle: widget.subtitle,
                                count: _items.length,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final d = _items[i];
                          final ar = (d['ar'] as String?) ?? '';
                          final fr = (d['fr'] as String?) ?? '';

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: _duaListCard(
                              context: context,
                              index: i + 1,
                              ar: ar,
                              fr: fr,
                              card: card,
                              stroke: stroke,
                              green: green,
                              onListen: () {},
                              onOpen: () {},
                              onFav: () {},
                            ),

                          );
                        },
                        childCount: _items.length,
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  ],
                ),
    );
  }
}

Widget _categoryHeaderCard({
  required BuildContext context,
  required Color card,
  required Color stroke,
  required Color green,
  required IconData icon,
  required String title,
  required String subtitle,
  required int count,
}) {
  return Container(
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: stroke),
      boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x16000000))],
    ),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: green, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 3),
              Text(
                "$count Duʿa • ${subtitle.isEmpty ? '' : subtitle}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.favorite_border_rounded,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black.withOpacity(0.45),
        ),
      ],
    ),
  );
}

Widget _duaListCard({
  required BuildContext context,
  required int index,
  required String ar,
  required String fr,
  required Color card,
  required Color stroke,
  required Color green,
  required VoidCallback onListen,
  required VoidCallback onOpen,
  required VoidCallback onFav,
}) {

  return Container(
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: stroke),
      boxShadow: const [BoxShadow(blurRadius: 14, offset: Offset(0, 6), color: Color(0x14000000))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Dhikr ${index.toString()}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
              IconButton(
                onPressed: onFav,
                icon: Icon(
                  Icons.favorite_border_rounded,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black.withOpacity(0.45),
                ),
                splashRadius: 18,
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Text(
            ar,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(fr, style: const TextStyle(height: 1.25)),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 360;
              final listenBtn = _primaryButton(green: green, label: "Écouter", icon: Icons.play_arrow_rounded, onTap: onListen);
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
