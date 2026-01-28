import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../asset_manager.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../services/reading_history_service.dart';
import '../surah_name.dart';
import 'reader_screen.dart';
import 'screens/quran_loader.dart';
import 'surah_list_screen.dart';

class QuranTabScreen extends StatefulWidget {
  const QuranTabScreen({super.key});

  @override
  State<QuranTabScreen> createState() => _QuranTabScreenState();
}

class _QuranTabScreenState extends State<QuranTabScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>(<int>{});
  final AudioService _audio = AudioService.instance;

  List<Map<String, dynamic>> _surahList = [];
  bool _isLoading = true;
  String? _loadError;
  String _preferredReading = 'hafs';

  @override
  void initState() {
    super.initState();
    _loadSurahData();
    _loadPreferredReading();
    _loadFavorites();
  }

  Future<void> _loadSurahData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
      final quranData = json.decode(jsonStr) as List<dynamic>;

      final List<Map<String, dynamic>> list = [];
      final Map<int, int> ayahCounts = {};
      final Map<int, int> startPage = {};

      for (final v in quranData) {
        if (v is! Map) continue;
        final surahRaw = v['surah'];
        final pageRaw = v['page'];

        final int? id = (surahRaw is int) ? surahRaw : int.tryParse('$surahRaw');
        if (id == null) continue;

        final int page = (pageRaw is int) ? pageRaw : (int.tryParse('$pageRaw') ?? 1);
        ayahCounts[id] = (ayahCounts[id] ?? 0) + 1;
        startPage[id] = startPage[id] ?? page;
      }

      for (final id in ayahCounts.keys) {
        final dynamic ar = quranData.cast<dynamic>().firstWhere(
          (e) => e is Map && e['surah'] == id,
          orElse: () => <String, dynamic>{},
        );

        final String nameAr =
            (ar is Map && ar['sura_name'] != null) ? ar['sura_name'].toString() : 'Sourate $id';

        list.add({
          'id': id,
          'nameAr': nameAr,
          'nameFr': surahFr[id] ?? 'Sourate $id',
          'page': startPage[id] ?? 1,
          'ayahCount': ayahCounts[id] ?? 0,
        });
      }

      list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      if (!mounted) return;
      setState(() {
        _surahList = list;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadPreferredReading() async {
    final reading = await ReadingHistoryService.instance.getPreferredReading();
    if (mounted) {
      setState(() => _preferredReading = reading);
    }
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.instance.getFavorites();
    if (!mounted) return;
    setState(() => _favoriteIdsNotifier.value = favs);
  }

  Future<bool> _showPagesDownloadPrompt() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1734) : const Color(0xFFFFF7EA);
    final titleColor = isDark ? const Color(0xFFF6E9D7) : const Color(0xFF5B3F12);
    final textColor = isDark ? Colors.white70 : const Color(0xFF5B4A2F);
    final accent = const Color(0xFFD4AF37);

    final shouldDownload = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_download_rounded, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Telechargement requis',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Pour lire les pages (Hafs et Warsh), l\'application doit telecharger les images une seule fois.',
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: titleColor,
                          side: BorderSide(color: accent.withOpacity(0.6)),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: const Color(0xFF1B1205),
                        ),
                        child: const Text('Telecharger'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldDownload ?? false;
  }

  Future<void> _openReader(int page, {String? reading}) async {
    final selectedReading = reading ?? _preferredReading;
    final downloaded = await AssetManager.areAssetsDownloaded();

    if (!downloaded) {
      final shouldDownload = await _showPagesDownloadPrompt();
      if (!shouldDownload) return;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuranLoader(
            initialPage: page,
            reading: selectedReading,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          initialPage: page,
          reading: selectedReading,
        ),
      ),
    );
  }

  void _playSurah(Map<String, dynamic> s) {
    _audio.loadPlaylistAndPlay(s['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erreur: $_loadError', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return SurahListScreen(
      surahList: _surahList,
      favoriteIdsNotifier: _favoriteIdsNotifier,
      onOpenReader: (page) => _openReader(page),
      onPlaySurah: _playSurah,
    );
  }
}
