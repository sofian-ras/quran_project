// lib/ui/reciter_picker_screen.dart
//
// Sélecteur de récitateur – 3 pages swipeables :
//   0: Tous   1: Favoris ♥   2: Téléchargés ↓
// Même thème que le home screen (gradient beige/dark).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio_service.dart';
import '../../services/download_service.dart';
import 'reciter_surah_list_screen.dart';

// ── Gradients (identiques au home screen) ────────────────────────────────────
const _kDarkColors = [
  Color(0xFF020617),
  Color(0xFF0B1025),
  Color(0xFF1A0033),
  Color(0xFF2D1B4E),
];
const _kLightColors = [
  Color(0xFFFFF7E8),
  Color(0xFFF7EEDB),
  Color(0xFFF2E4CC),
];

LinearGradient _bgGrad(bool dark) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark ? _kDarkColors : _kLightColors,
    );

// Accent audio (teal, uniquement pour l'indicateur de lecture)
const _kPlay = Color(0xFF0E6B63);

// ── Modèle ────────────────────────────────────────────────────────────────────
class MoshafOption {
  final String moshafRaw;
  final String server;
  final List<int> surahList;
  const MoshafOption({
    required this.moshafRaw,
    required this.server,
    required this.surahList,
  });
}

class ReciterData {
  final int    id;
  final String name;
  final String? arabicName;
  final String? country;
  final List<String> tags;
  final String? asset;
  final String server;
  final String moshafRaw;
  final int    surahTotal;
  final List<int> surahList;
  final List<MoshafOption> allMoshafs;

  const ReciterData({
    required this.id,
    required this.name,
    this.arabicName,
    this.country,
    required this.tags,
    this.asset,
    required this.server,
    required this.moshafRaw,
    required this.surahTotal,
    required this.surahList,
    this.allMoshafs = const [],
  });
}

// ── Écran principal ───────────────────────────────────────────────────────────
class ReciterPickerScreen extends StatefulWidget {
  const ReciterPickerScreen({super.key});

  @override
  State<ReciterPickerScreen> createState() => _ReciterPickerScreenState();
}

class _ReciterPickerScreenState extends State<ReciterPickerScreen> {
  final AudioService _audio = AudioService.instance;
  late final PageController _pageCtrl;
  final TextEditingController _search = TextEditingController();

  List<ReciterData>           _all        = [];
  List<ReciterData>           _filtered   = [];
  Set<int>                    _favorites  = {};
  List<Map<String, dynamic>>  _dlReciters = [];
  int  _page    = 0;
  bool _loading = true;

  static const _kFavKey = 'reciter_favorites';

  @override
  void initState() {
    super.initState();
    _audio.hasNavBar.value = false;
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onPageScroll);
    _search.addListener(_filter);
    _loadData();
    _loadFavorites();
    _loadDownloadedReciters();
  }

  @override
  void dispose() {
    _audio.suppressGlobalPlayer.value = false;
    _audio.hasNavBar.value = true;
    _pageCtrl.removeListener(_onPageScroll);
    _pageCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final p = _pageCtrl.page?.round() ?? 0;
    if (p != _page) setState(() => _page = p);
  }

  // ── Données ─────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/reciters_eng.json'),
      rootBundle.loadString('assets/data/reciters_mapping.json'),
      rootBundle.loadString('assets/data/reciters_bio.json'),
    ]);

    final apiList = (jsonDecode(results[0])['reciters'] as List)
        .cast<Map<String, dynamic>>();
    final mapping = (jsonDecode(results[1]) as List).cast<Map<String, dynamic>>();
    final bios    = (jsonDecode(results[2]) as List).cast<Map<String, dynamic>>();

    final assetById = <int, String>{
      for (final m in mapping) (m['reciterId'] as int): (m['asset'] as String),
    };
    final bioById = <int, Map<String, dynamic>>{
      for (final b in bios) (b['reciterId'] as int): b,
    };

    final items = <ReciterData>[];
    for (final r in apiList) {
      final id      = r['id'] as int;
      final name    = (r['name'] as String?) ?? '';
      final moshafs = (r['moshaf'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (moshafs.isEmpty || name.isEmpty) continue;

      // Toutes les options de récitation
      final allMoshafs = <MoshafOption>[];
      for (final m in moshafs) {
        final rawSrv = (m['server'] as String?) ?? '';
        if (rawSrv.isEmpty) continue;
        final srv    = rawSrv.endsWith('/') ? rawSrv : '$rawSrv/';
        final mRaw   = (m['name'] as String?) ?? '';
        final sStr   = (m['surah_list'] as String?) ?? '';
        final sIds   = sStr.split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
        allMoshafs.add(MoshafOption(moshafRaw: mRaw, server: srv, surahList: sIds));
      }
      if (allMoshafs.isEmpty) continue;

      // Moshaf par défaut : Hafs (type 11) > Hafs par nom > premier
      Map<String, dynamic>? best;
      for (final m in moshafs) {
        if ((m['moshaf_type'] as int?) == 11) { best = m; break; }
      }
      best ??= moshafs.where((m) =>
          (m['name'] as String? ?? '').toLowerCase().contains('hafs'))
          .firstOrNull;
      best ??= moshafs.first;

      final rawServer = (best['server'] as String?) ?? '';
      final server    = rawServer.endsWith('/') ? rawServer : '$rawServer/';
      final moshafRaw = (best['name'] as String?) ?? '';
      final total     = (best['surah_total'] as int?) ?? 114;
      final surahStr  = (best['surah_list'] as String?) ?? '';
      final surahList = surahStr.split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();

      final bio = bioById[id];
      items.add(ReciterData(
        id:          id,
        name:        name,
        arabicName:  bio?['arabicName'] as String?,
        country:     bio?['country']    as String?,
        tags:        (bio?['styleTags'] as List?)?.cast<String>() ?? const [],
        asset:       assetById[id],
        server:      server,
        moshafRaw:   moshafRaw,
        surahTotal:  total,
        surahList:   surahList,
        allMoshafs:  allMoshafs,
      ));
    }

    items.sort((a, b) {
      if (a.asset != null && b.asset == null) return -1;
      if (a.asset == null && b.asset != null) return 1;
      return a.name.compareTo(b.name);
    });

    if (!mounted) return;
    setState(() {
      _all      = items;
      _filtered = items;
      _loading  = false;
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kFavKey) ?? [];
    if (mounted) setState(() => _favorites = ids.map(int.parse).toSet());
  }

  Future<void> _toggleFav(int id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    await prefs.setStringList(
        _kFavKey, _favorites.map((e) => e.toString()).toList());
  }

  Future<void> _loadDownloadedReciters() async {
    final infos = await DownloadService.instance.getDownloadedReciterInfos();
    if (mounted) setState(() => _dlReciters = infos);
  }

  Future<void> _deleteDownloadedReciter(Map<String, dynamic> info) async {
    final server = info['server'] as String? ?? '';
    final name   = info['name']   as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer les audios téléchargés de $name ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DownloadService.instance.deleteAllQuranAudio(server);
    await DownloadService.instance.removeReciterDownloadInfo(server);
    await _loadDownloadedReciters();
  }

  void _openDownloadedReciter(Map<String, dynamic> info) {
    final server    = info['server']      as String? ?? '';
    final name      = info['name']        as String? ?? '';
    final arabic    = info['arabicName']  as String?;
    final country   = info['country']     as String?;
    final asset     = info['asset']       as String?;
    final moshafLbl = info['moshafLabel'] as String? ?? '';
    final rawList   = info['surahList']   as List<dynamic>? ?? [];
    final surahList = rawList.map((e) => (e as num).toInt()).toList();

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReciterSurahListScreen(
        name:        name,
        arabicName:  arabic,
        country:     country,
        asset:       asset,
        server:      server,
        moshafLabel: moshafLbl,
        surahList:   surahList.isEmpty
            ? List.generate(114, (i) => i + 1)
            : surahList,
      ),
    )).then((_) => _loadDownloadedReciters());
  }

  void _filter() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((r) =>
              r.name.toLowerCase().contains(q) ||
              (r.arabicName?.contains(q) ?? false) ||
              (r.country?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  void _openSurahList(ReciterData r) {
    if (r.allMoshafs.length > 1) {
      _showMoshafPicker(r);
    } else {
      _navigateToSurahList(r, r.server, r.moshafRaw,
          r.surahList.isEmpty ? List.generate(r.surahTotal, (i) => i + 1) : r.surahList);
    }
  }

  void _navigateToSurahList(ReciterData r, String server, String moshafRaw, List<int> surahList) {
    final label = _prettyMoshaf(moshafRaw);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReciterSurahListScreen(
        name:        r.name,
        arabicName:  r.arabicName,
        country:     r.country,
        asset:       r.asset,
        server:      server,
        moshafLabel: label,
        surahList:   surahList,
      ),
    )).then((_) => _loadDownloadedReciters());
  }

  void _showMoshafPicker(ReciterData r) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final entries  = r.allMoshafs
        .map((m) => (label: _prettyMoshaf(m.moshafRaw), moshaf: m))
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoshafPickerSheet(
        reciter:  r,
        entries:  entries,
        isDark:   isDark,
        onSelect: (m) {
          Navigator.of(context).pop();
          final surahList = m.surahList.isEmpty
              ? List.generate(114, (i) => i + 1)
              : m.surahList;
          _navigateToSurahList(r, m.server, m.moshafRaw, surahList);
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _prettyMoshaf(String raw) {
    final s = raw.toLowerCase();
    String rv = '';
    if      (s.contains('hafs'))                              { rv = 'Hafs'; }
    else if (s.contains('warsh'))                             { rv = 'Warsh'; }
    else if (s.contains('khalaf'))                            { rv = 'Khalaf'; }
    else if (s.contains('shu\'bah') || s.contains('shu3ba')) { rv = "Shu'bah"; }
    else if (s.contains('doori') || s.contains('al-doori'))  { rv = 'Ad-Doori'; }
    else if (s.contains('soosi') || s.contains('assosi') ||
             s.contains('sosi'))                              { rv = 'Soosi'; }
    else if (s.contains('kasaa') || s.contains('kasaee') ||
             s.contains('kasae'))                             { rv = "Kasaa'ee"; }
    String tp = '';
    if      (s.contains('murattal'))                          { tp = 'Murattal'; }
    else if (s.contains('mujawwad') || s.contains('mujawad')){ tp = 'Mujawwad'; }
    // Suffixe de version (ex: "2020")
    final ver = RegExp(r'\((\d{4})\)').firstMatch(raw)?.group(1);
    if (rv.isEmpty && tp.isEmpty) return raw;
    final base = [if (rv.isNotEmpty) rv, if (tp.isNotEmpty) tp].join(' • ');
    return ver != null ? '$base ($ver)' : base;
  }

  bool _isActive(ReciterData r) =>
      _audio.currentReciterNotifier.value
          .toLowerCase()
          .contains(r.name.toLowerCase());

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? Colors.white       : const Color(0xFF0F172A);
    final muted  = isDark ? Colors.white60     : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bgGrad(isDark)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top area ────────────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: fg, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // Title + subtitle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Récitateurs',
                              style: TextStyle(
                                color: fg,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              )),
                          const SizedBox(height: 2),
                          Text('Récitations du Saint Coran',
                              style: TextStyle(
                                color: muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab bar ─────────────────────────────────────────────────────
            _TabBar(
              page:   _page,
              isDark: isDark,
              onTap:  (i) => _pageCtrl.animateToPage(
                i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
              ),
            ),

            // ── Search bar (page 0) ─────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _page == 0
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _SearchField(
                          controller: _search, isDark: isDark),
                    )
                  : const SizedBox(width: double.infinity),
            ),

            // ── Compteur ────────────────────────────────────────────────────
            if (_page == 0 && !_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '${_filtered.length} récitateur${_filtered.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // ── Pages ───────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                children: [
                  _buildAllPage(isDark),
                  _buildFavPage(isDark),
                  _buildDlPage(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 0 : Tous ──────────────────────────────────────────────────────────

  Widget _buildAllPage(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return _EmptyState(
          icon: Icons.search_off_rounded,
          label: 'Aucun résultat',
          isDark: isDark);
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _ReciterRow(
        reciter:  _filtered[i],
        isDark:   isDark,
        isActive: _isActive(_filtered[i]),
        isFav:    _favorites.contains(_filtered[i].id),
        onTap:    () => _openSurahList(_filtered[i]),
        onFavTap: () => _toggleFav(_filtered[i].id),
      ),
    );
  }

  // ── Page 1 : Favoris ───────────────────────────────────────────────────────

  Widget _buildFavPage(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final favs = _all.where((r) => _favorites.contains(r.id)).toList();
    if (favs.isEmpty) {
      return _EmptyState(
        icon: Icons.favorite_border_rounded,
        label: 'Aucun récitateur favori\nAppuyez sur ♥ pour en ajouter',
        isDark: isDark,
      );
    }
    return ListView.builder(
      itemCount: favs.length,
      itemBuilder: (_, i) => _ReciterRow(
        reciter:  favs[i],
        isDark:   isDark,
        isActive: _isActive(favs[i]),
        isFav:    true,
        onTap:    () => _openSurahList(favs[i]),
        onFavTap: () => _toggleFav(favs[i].id),
      ),
    );
  }

  // ── Page 2 : Téléchargés ───────────────────────────────────────────────────

  Widget _buildDlPage(bool isDark) {
    if (_dlReciters.isEmpty) {
      return _EmptyState(
        icon: Icons.download_for_offline_rounded,
        label: 'Aucun récitateur téléchargé\nOuvrez un récitateur et\ntéléchargez des sourates',
        isDark: isDark,
      );
    }

    final fg    = isDark ? Colors.white       : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white54     : const Color(0xFF64748B);
    final div   = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return ListView.builder(
      itemCount: _dlReciters.length,
      itemBuilder: (_, i) {
        final info    = _dlReciters[i];
        final name    = info['name']        as String? ?? '';
        final arabic  = info['arabicName']  as String?;
        final country = info['country']     as String?;
        final asset   = info['asset']       as String?;
        final moshaf  = info['moshafLabel'] as String? ?? '';
        final count   = (info['surahList'] as List<dynamic>? ?? []).length;

        return InkWell(
          onTap: () => _openDownloadedReciter(info),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: div, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                _AvatarWidget(name: name, asset: asset, id: 0, size: 52),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: fg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (arabic != null) ...[
                        const SizedBox(height: 1),
                        Text(arabic,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 12, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, children: [
                        if (country != null)
                          _TagChip(label: country,
                              icon: Icons.public_rounded,
                              color: muted),
                        if (moshaf.isNotEmpty)
                          _TagChip(label: moshaf,
                              color: isDark ? Colors.white38 : Colors.black45),
                        _TagChip(
                          label: '$count sourate${count > 1 ? 's' : ''}',
                          icon: Icons.download_done_rounded,
                          color: _kPlay,
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 22),
                  onPressed: () => _deleteDownloadedReciter(info),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tab bar (thème home) ──────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int  page;
  final bool isDark;
  final void Function(int) onTap;

  static const _labels = ['Tous', 'Favoris', 'Téléchargés'];
  static const _icons  = [
    Icons.format_list_bulleted_rounded,
    Icons.favorite_rounded,
    Icons.download_rounded,
  ];

  const _TabBar({required this.page, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == page;

          // Couleurs : même logique que le home screen
          final bgActive   = isDark
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.80);
          final bgInactive = isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05);

          final textActive   = isDark ? Colors.white : Colors.white;
          final textInactive = isDark ? Colors.white38 : Colors.black45;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? bgActive : bgInactive,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[i],
                        size: 14,
                        color: active ? textActive : textInactive),
                    const SizedBox(width: 5),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? textActive : textInactive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Barre de recherche ────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  const _SearchField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hint = isDark ? Colors.white38    : Colors.black38;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, val, __) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher…',
          hintStyle: TextStyle(color: hint, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: hint, size: 20),
          suffixIcon: val.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: hint, size: 18),
                  onPressed: () {
                    controller.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: fill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── Ligne récitateur ──────────────────────────────────────────────────────────

class _ReciterRow extends StatelessWidget {
  final ReciterData reciter;
  final bool isDark;
  final bool isActive;
  final bool isFav;
  final VoidCallback onTap;
  final VoidCallback onFavTap;

  const _ReciterRow({
    required this.reciter,
    required this.isDark,
    required this.isActive,
    required this.isFav,
    required this.onTap,
    required this.onFavTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg    = isDark ? Colors.white       : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white54     : const Color(0xFF64748B);
    final div   = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: div, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
        child: Row(
          children: [
            // Avatar
            _AvatarWidget(
                reciter: reciter, size: 52),
            const SizedBox(width: 13),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reciter.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w700 : FontWeight.w600,
                            color: fg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.volume_up_rounded,
                            color: _kPlay, size: 14),
                      ],
                    ],
                  ),
                  if (reciter.arabicName != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      reciter.arabicName!,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4, runSpacing: 3,
                    children: [
                      if (reciter.country != null)
                        _TagChip(label: reciter.country!,
                            icon: Icons.public_rounded,
                            color: muted),
                      for (final tag in reciter.tags)
                        _TagChip(label: tag,
                            color: _kPlay.withValues(alpha: 0.8)),
                    ],
                  ),
                ],
              ),
            ),

            // Favori
            GestureDetector(
              onTap: onFavTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(isFav),
                    color: isFav
                        ? Colors.redAccent
                        : (isDark ? Colors.white24 : Colors.black26),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final ReciterData? reciter;
  final String? name;
  final String? asset;
  final int? id;
  final double size;

  const _AvatarWidget({
    this.reciter,
    this.name,
    this.asset,
    this.id,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final rAsset  = reciter?.asset  ?? asset;
    final rName   = reciter?.name   ?? name  ?? '';
    final rId     = reciter?.id     ?? id    ?? 0;

    if (rAsset != null) {
      return ClipOval(
        child: Image.asset(
          rAsset,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letter(rName, rId),
        ),
      );
    }
    return _letter(rName, rId);
  }

  Widget _letter(String n, int i) {
    final letter = n.isNotEmpty ? n[0].toUpperCase() : '?';
    final hue    = (i * 53.0) % 360;
    final c1     = HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor();
    final c2     = HSLColor.fromAHSL(1, (hue + 20) % 360, 0.5, 0.28).toColor();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Center(
        child: Text(letter,
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String   label;
  final IconData? icon;
  final Color    color;
  const _TagChip({required this.label, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  const _EmptyState(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white24 : Colors.black26;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de riwaya (bottom sheet) ───────────────────────────────────────

class _MoshafPickerSheet extends StatelessWidget {
  final ReciterData reciter;
  final List<({String label, MoshafOption moshaf})> entries;
  final bool isDark;
  final void Function(MoshafOption) onSelect;

  const _MoshafPickerSheet({
    required this.reciter,
    required this.entries,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bg  = isDark ? const Color(0xFF0B1025) : const Color(0xFFFFF7E8);
    final fg  = isDark ? Colors.white            : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54          : const Color(0xFF64748B);
    final div = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Nom du récitateur
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
            child: Text(
              reciter.name,
              style: TextStyle(
                  color: fg, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (reciter.arabicName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                reciter.arabicName!,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: sub, fontSize: 13),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Choisir une lecture',
              style: TextStyle(color: sub, fontSize: 12),
            ),
          ),

          Divider(color: div, height: 1),

          // Liste des riwayat
          ...entries.map((e) => InkWell(
            onTap: () => onSelect(e.moshaf),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: div, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kPlay.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      e.label,
                      style: const TextStyle(
                        color: _kPlay,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: sub),
                ],
              ),
            ),
          )),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
