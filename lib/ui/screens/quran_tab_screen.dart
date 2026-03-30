import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio_service.dart';
import '../../services/favorites_service.dart';
import '../../services/quran_image_service.dart';
import 'reader_screen.dart';
import 'translated_quran_screen.dart';
import 'surah_list_screen.dart';

class QuranTabScreen extends StatefulWidget {
  const QuranTabScreen({super.key});

  @override
  State<QuranTabScreen> createState() => _QuranTabScreenState();
}

class _QuranTabScreenState extends State<QuranTabScreen> {
  final AudioService _audio = AudioService.instance;

  late Future<List<Map<String, dynamic>>> _surahListFuture;
  final ValueNotifier<Set<int>> _favoriteIdsNotifier = ValueNotifier<Set<int>>({});

  // true = Coran image (ReaderScreen), false = Coran FR (TranslatedQuranScreen)
  bool _useImageReader = true;

  static const _kUseImageReader = 'quran_tab_use_image_reader';

  Future<void> _loadReaderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useImageReader = prefs.getBool(_kUseImageReader) ?? true;
    });
  }

  Future<void> _setReaderPreference(bool value) async {
    setState(() => _useImageReader = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseImageReader, value);
  }

  @override
  void initState() {
    super.initState();
    _surahListFuture = loadSurahList();
    _loadFavorites();
    _loadReaderPreference();
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.instance.getFavorites();
    if (!mounted) return;
    _favoriteIdsNotifier.value = ids;
  }

  Future<void> _openReader(int page) async {
    debugPrint('🔥🔥🔥 _openReader page=$page useImage=$_useImageReader');
    if (_useImageReader) {
      try {
        await QuranImageService.getPageFile('hafs', page);
        if (!mounted) return;
        final File? file = QuranImageService.getSyncCached(page);
        if (file != null) await precacheImage(FileImage(file), context);
        if (!mounted) return;
      } catch (_) {}
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(initialPage: page, reading: 'hafs'),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TranslatedQuranScreen(preferOffline: true),
        ),
      );
    }
  }

  void _playSurah(Map<String, dynamic> surah) async {
    final idRaw = surah['id'];
    final int? surahId = (idRaw is int) ? idRaw : int.tryParse(idRaw.toString());
    if (surahId == null) return;
    await _audio.loadPlaylistAndPlay(surahId);
  }

  Widget _buildToggle(bool isDark) {
    const green = Color(0xFF1B5E20);
    final bg = isDark ? const Color(0xFF1C2A1C) : const Color(0xFFE8F5E9);
    final unselText = isDark ? Colors.white54 : const Color(0xFF4A7A4A);

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Option Coran image
          GestureDetector(
            onTap: () => _setReaderPreference(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _useImageReader ? green : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: SvgPicture.asset(
                'assets/images/navbar/Quran_Kareem.svg',
                height: 18,
                colorFilter: ColorFilter.mode(
                  _useImageReader ? Colors.white : unselText,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          // Option Coran FR
          GestureDetector(
            onTap: () => _setReaderPreference(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !_useImageReader ? green : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Coran FR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_useImageReader ? Colors.white : unselText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _favoriteIdsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _surahListFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) {
          return const Center(child: Text('Erreur chargement sourates'));
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Liste des sourates vide.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vérifie assets/data/quran_data.json et pubspec.yaml',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        return SurahListScreen(
          surahList: list,
          favoriteIdsNotifier: _favoriteIdsNotifier,
          onOpenReader: _openReader,
          onPlaySurah: _playSurah,
          titleWidget: _buildToggle(isDark),
        );
      },
    );
  }
}
