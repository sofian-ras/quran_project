// lib/ui/widgets/ayah_action_sheet.dart
//
// Bottom sheet sobre qui s'affiche quand "Tafsir" est sélectionné.
// Structure : arabe · divider · traduction FR · divider · tafsir (source Qul)
//
// Usage :
//   AyahActionSheet.show(context, surah: 2, ayah: 255);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/quran_ayah_metadata_db.dart';
import '../../services/quran_text_db.dart';
import '../../services/quran_translation_pack_service.dart';
import '../../services/verse_favorites_service.dart';
import '../../services/audio_service.dart';
import '../../surah_name.dart';

class AyahActionSheet extends StatefulWidget {
  final int surah;
  final int ayah;

  const AyahActionSheet({
    super.key,
    required this.surah,
    required this.ayah,
  });

  static Future<void> show(
    BuildContext context, {
    required int surah,
    required int ayah,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahActionSheet(surah: surah, ayah: ayah),
    );
  }

  @override
  State<AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<AyahActionSheet> {
  StreamSubscription? _audioSub;
  QVerse? _verse;
  bool _loading = true;
  bool _isFavorite = false;
  bool _isPlaying = false;

  // ── Tafsir online ───────────────────────────────────
  int _tafsirId = 14; // Ibn Kathir arabe par défaut
  String? _onlineTafsir;
  bool _tafsirLoading = false;
  bool _tafsirSaved = false;
  bool _tafsirSaving = false;
  CancelToken? _tafsirCancelToken;

  String get _verseKey => '${widget.surah}:${widget.ayah}';
  String get _tafsirCacheKey => 'tafsir_${_tafsirId}_$_verseKey';
  String get _surahName => surahFr[widget.surah] ?? 'Sourate ${widget.surah}';

  @override
  void initState() {
    super.initState();
    _load();
    _audioSub = AudioService.instance.ayahPlayerStateStream.listen((st) {
      if (!mounted) return;
      final key = AudioService.instance.currentAyahKeyNotifier.value;
      setState(() => _isPlaying = st.playing && key == _verseKey);
    });
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _tafsirCancelToken?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // Phase 1 : arabe depuis la DB bundlée + favoris en parallèle → affichage immédiat
    final results = await Future.wait([
      QuranAyahMetadataDb.instance.getVerseText(widget.surah, widget.ayah),
      VerseFavoritesService.instance.isFavorite(_verseKey),
    ]);
    final ar  = (results[0] as String?) ?? '';
    final fav = results[1] as bool;

    if (!mounted) return;
    setState(() {
      _verse = QVerse(
        verseKey: _verseKey,
        surah:    widget.surah,
        ayah:     widget.ayah,
        ar:       ar,
        fr:       '',
        tafsir:   null,
      );
      _isFavorite = fav;
      _loading    = false;
    });

    // Phase 2 : traduction FR depuis le pack installé (arrière-plan, silencieux)
    try {
      await QuranTranslationPackService.migrateLegacyToQulIfNeeded();
      final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
      if (verse != null && verse.fr.isNotEmpty && mounted) {
        setState(() => _verse = verse);
      }
    } catch (_) {}

    // Phase 3 : tafsir — cache local ou fetch en ligne
    if (!mounted) return;
    final hasLocal = _verse?.tafsir != null && _verse!.tafsir!.isNotEmpty;
    if (!hasLocal) {
      final prefs  = await SharedPreferences.getInstance();
      final cached = prefs.getString(_tafsirCacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() { _onlineTafsir = cached; _tafsirSaved = true; });
      } else {
        _fetchTafsir();
      }
    }
  }

  Future<void> _fetchTafsir() async {
    if (_tafsirLoading) return;
    _tafsirCancelToken?.cancel();
    _tafsirCancelToken = CancelToken();
    setState(() {
      _tafsirLoading = true;
      _onlineTafsir = null;
    });
    try {
      final res = await Dio().get(
        'https://api.quran.com/api/v4/tafsirs/$_tafsirId/by_ayah/$_verseKey',
        cancelToken: _tafsirCancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final raw = res.data['tafsir']['text'] as String? ?? '';
      // Nettoyer le HTML
      final clean = raw
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r' {2,}'), ' ')
          .trim();
      if (!mounted) return;
      setState(() {
        _onlineTafsir = clean.isEmpty ? null : clean;
        _tafsirLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() => _tafsirLoading = false);
    }
  }

  Future<void> _saveTafsirLocally() async {
    if (_tafsirSaving || _onlineTafsir == null) return;
    setState(() => _tafsirSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tafsirCacheKey, _onlineTafsir!);
      if (!mounted) return;
      setState(() { _tafsirSaved = true; _tafsirSaving = false; });
    } catch (_) {
      if (mounted) setState(() => _tafsirSaving = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final now = await VerseFavoritesService.instance.toggleFavorite(_verseKey);
    if (!mounted) return;
    setState(() => _isFavorite = now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? 'Ajouté aux favoris' : 'Retiré des favoris'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await AudioService.instance.pauseAyah();
    } else {
      await AudioService.instance.playAyah(widget.surah, widget.ayah);
    }
  }

  Future<void> _copy() async {
    if (_verse == null) return;
    final text = '${_verse!.ar}\n\n${_verse!.fr}\n\n— $_surahName ${widget.ayah}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verset copié'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _share() async {
    if (_verse == null) return;
    final text =
        '﴾${_verse!.ar}﴿\n\n${_verse!.fr}\n\n— $_surahName, verset ${widget.ayah}';
    await Share.share(text, subject: '$_surahName — verset ${widget.ayah}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ── Barre d'actions ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _IconBtn(
                      icon: _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: const Color(0xFF4CAF50),
                      isDark: isDark,
                      onTap: _togglePlay,
                    ),
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: _isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFB8860B),
                      isDark: isDark,
                      onTap: _toggleFavorite,
                    ),
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: Icons.copy_rounded,
                      color: const Color(0xFF2196F3),
                      isDark: isDark,
                      onTap: _copy,
                    ),
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: Icons.share_rounded,
                      color: const Color(0xFF9C27B0),
                      isDark: isDark,
                      onTap: _share,
                    ),
                    const Spacer(),
                    Text(
                      '$_surahName · ${widget.ayah}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: isDark
                            ? const Color(0xFFF5D278).withValues(alpha: 0.85)
                            : const Color(0xFF8B6914),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: Icons.close,
                      color: isDark ? Colors.white38 : Colors.black26,
                      isDark: isDark,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Contenu scrollable ───────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(scrollController, isDark, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    ScrollController scrollController,
    bool isDark,
    ThemeData theme,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor =
        isDark ? Colors.white60 : const Color(0xFF555555);
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      children: [
        if (_verse != null) ...[
          // ── Texte arabe embelli ───────────────────────────
          Text(
            sanitizeQulText(_verse!.ar),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 2.0,
              wordSpacing: 3.0,
              letterSpacing: 0.0,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: divColor, height: 1),
          const SizedBox(height: 18),

          // ── Traduction française ──────────────────────────
          Text(
            _verse!.fr,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.8,
              fontSize: 15,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 28),
          Divider(color: divColor, height: 1),
          const SizedBox(height: 22),
        ] else ...[
          // Pack absent
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Texte non disponible',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            height: 1,
          ),
          const SizedBox(height: 22),
        ],

        // ── Section tafsir ────────────────────────────────
        _buildTafsirSection(isDark, theme),
      ],
    );
  }

  Widget _buildTafsirSection(bool isDark, ThemeData theme) {
    final gold = isDark ? const Color(0xFFF5D278) : const Color(0xFFB8860B);
    final hasLocal = _verse?.tafsir != null && _verse!.tafsir!.isNotEmpty;

    // Texte à afficher : local > online
    final displayText = hasLocal
        ? sanitizeQulText(_verse!.tafsir!)
        : _onlineTafsir;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête : label + sélecteur source ──────────
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 15, color: gold),
            const SizedBox(width: 6),
            Text(
              'Tafsir',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: gold,
              ),
            ),
            const Spacer(),

            // Sélecteur de tafsir (PopupMenu)
            if (!hasLocal)
              _TafsirSelector(
                selectedId: _tafsirId,
                isDark: isDark,
                gold: gold,
                onChanged: (id) async {
                  final prefs = await SharedPreferences.getInstance();
                  final cached = prefs.getString('tafsir_${id}_$_verseKey');
                  setState(() {
                    _tafsirId = id;
                    _onlineTafsir = cached;
                    _tafsirSaved = cached != null && cached.isNotEmpty;
                  });
                  if (cached == null || cached.isEmpty) _fetchTafsir();
                },
              ),

            // Badge DB local
            if (hasLocal)
              _SourceBadge(label: 'Qul · local', isDark: isDark),

            // Bouton téléchargement hors-ligne (uniquement pour le tafsir online)
            if (!hasLocal && displayText != null) ...[
              const SizedBox(width: 6),
              _DownloadBtn(
                saved: _tafsirSaved,
                saving: _tafsirSaving,
                isDark: isDark,
                gold: gold,
                onTap: _tafsirSaved ? null : _saveTafsirLocally,
              ),
            ],
          ],
        ),

        const SizedBox(height: 14),

        // ── Contenu ──────────────────────────────────────
        if (_tafsirLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: gold),
              ),
            ),
          )
        else if (displayText != null && displayText.isNotEmpty)
          SelectableText(
            displayText,
            style: TextStyle(
              height: 1.85,
              fontSize: 14,
              color: isDark
                  ? Colors.white54
                  : const Color(0xFF555555),
            ),
          )
        else
          Text(
            'Tafsir non disponible pour ce verset.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ),
      ],
    );
  }
}

// ── Badge source ───────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SourceBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF888888),
        ),
      ),
    );
  }
}

// ── Sélecteur de tafsir ────────────────────────────────────────────────────────

class _TafsirSelector extends StatelessWidget {
  final int selectedId;
  final bool isDark;
  final Color gold;
  final void Function(int) onChanged;

  const _TafsirSelector({
    required this.selectedId,
    required this.isDark,
    required this.gold,
    required this.onChanged,
  });

  static const _options = [
    _TafsirOption(id: 14, label: 'Ibn Kathir (ar)'),
    _TafsirOption(id: 169, label: 'Ibn Kathir (en)'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _options.firstWhere(
      (o) => o.id == selectedId,
      orElse: () => _options.first,
    );

    return PopupMenuButton<int>(
      onSelected: onChanged,
      color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => _options
          .map(
            (o) => PopupMenuItem<int>(
              value: o.id,
              child: Row(
                children: [
                  if (o.id == selectedId)
                    Icon(Icons.check_rounded, size: 14, color: gold)
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 8),
                  Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : const Color(0xFF888888),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }
}

class _TafsirOption {
  final int id;
  final String label;
  const _TafsirOption({required this.id, required this.label});
}

// ── Bouton téléchargement hors-ligne ──────────────────────────────────────────

class _DownloadBtn extends StatelessWidget {
  final bool saved;
  final bool saving;
  final bool isDark;
  final Color gold;
  final VoidCallback? onTap;

  const _DownloadBtn({
    required this.saved,
    required this.saving,
    required this.isDark,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2, color: gold),
        ),
      );
    }

    if (saved) {
      return Tooltip(
        message: 'Disponible hors-ligne',
        child: Icon(Icons.download_done_rounded, size: 18, color: gold),
      );
    }

    return Tooltip(
      message: 'Sauvegarder pour hors-ligne',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.download_outlined,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ── Bouton icône compact ───────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

// ── Nettoyage du texte brut ────────────────────────────────────────────────────

String sanitizeQulText(String input) {
  var s = input;
  // Balises HTML/tajweed
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // Tokens typographiques résiduels
  s = s.replaceAll(
    RegExp(r'\b(rule|class|slnt|wght|wdth)\b[^ \n]*',
        caseSensitive: false),
    '',
  );
  // Caractères de direction invisibles qui cassent les ligatures (lam-alif, etc.)
  s = s.replaceAll('\u200C', ''); // ZWNJ – empêche les ligatures
  s = s.replaceAll('\u200D', ''); // ZWJ
  s = s.replaceAll('\u200E', ''); // LRM
  s = s.replaceAll('\u200F', ''); // RLM
  s = s.replaceAll('\u200B', ''); // Zero-width space
  // Normalise espaces et lignes
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
