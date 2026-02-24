// lib/ui/widgets/ayah_action_sheet.dart
//
// Bottom sheet qui s'affiche quand un verset est sélectionné.
// Affiche : texte arabe, traduction FR, tafsir (expandable),
//           boutons audio / copier / partager / favori.
//
// Usage :
//   AyahActionSheet.show(context, surah: 2, ayah: 255);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../services/quran_text_db.dart';
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

  /// Ouvre le bottom sheet.
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
  bool _showTafsir = false;
  bool _isPlaying = false;

  String get _verseKey => '${widget.surah}:${widget.ayah}';
  String get _surahName => surahFr[widget.surah] ?? 'Sourate ${widget.surah}';

  @override
  void initState() {
    super.initState();
    _load();
    // Écouter l'état audio pour mettre à jour le bouton play
    _audioSub = AudioService.instance.ayahPlayerStateStream.listen((st) {
      if (!mounted) return;
      final key = AudioService.instance.currentAyahKeyNotifier.value;
      setState(() {
        _isPlaying = st.playing && key == _verseKey;
      });
    });
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final verse = await QuranTextDb.instance.getVerseByKey(_verseKey);
    final fav = await VerseFavoritesService.instance.isFavorite(_verseKey);
    if (!mounted) return;
    setState(() {
      _verse = verse;
      _isFavorite = fav;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final now = await VerseFavoritesService.instance.toggleFavorite(_verseKey);
    if (!mounted) return;
    setState(() => _isFavorite = now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? 'Ajouté aux favoris ⭐' : 'Retiré des favoris'),
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
        content: Text('Verset copié 📋'),
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
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final handleColor = isDark ? Colors.white24 : Colors.black12;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // En-tête
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8860B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFB8860B).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '$_surahName · ${widget.ayah}',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFF5D278)
                              : const Color(0xFF8B6914),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Bouton fermer
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.06),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Contenu scrollable
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _verse == null
                        ? Center(
                            child: Text(
                              'Texte non disponible\n(pack texte non téléchargé)',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          )
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
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Texte arabe ──────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2A2A3E)
                : const Color(0xFFFAF6ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFB8860B).withOpacity(0.25),
            ),
          ),
          child: Text(
            _verse!.ar,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 26,
              height: 2.0,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Traduction française ──────────────────────────────
        Text(
          _verse!.fr,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.7,
            color: isDark ? Colors.white.withOpacity(0.87) : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 20),

        // ── Boutons d'action ──────────────────────────────────
        _buildActionButtons(isDark),
        const SizedBox(height: 20),

        // ── Tafsir (accordéon) ───────────────────────────────
        if (_verse!.tafsir != null && _verse!.tafsir!.isNotEmpty)
          _buildTafsirSection(isDark, theme),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        // Play / Pause
        Expanded(
          child: _ActionButton(
            icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: _isPlaying ? 'Pause' : 'Écouter',
            color: const Color(0xFF4CAF50),
            isDark: isDark,
            onTap: _togglePlay,
          ),
        ),
        const SizedBox(width: 10),

        // Favori
        Expanded(
          child: _ActionButton(
            icon: _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            label: _isFavorite ? 'Favori ★' : 'Favori',
            color: const Color(0xFFB8860B),
            isDark: isDark,
            onTap: _toggleFavorite,
          ),
        ),
        const SizedBox(width: 10),

        // Copier
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_rounded,
            label: 'Copier',
            color: const Color(0xFF2196F3),
            isDark: isDark,
            onTap: _copy,
          ),
        ),
        const SizedBox(width: 10),

        // Partager
        Expanded(
          child: _ActionButton(
            icon: Icons.share_rounded,
            label: 'Partager',
            color: const Color(0xFF9C27B0),
            isDark: isDark,
            onTap: _share,
          ),
        ),
      ],
    );
  }

  Widget _buildTafsirSection(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showTafsir = !_showTafsir),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: isDark
                      ? const Color(0xFFF5D278)
                      : const Color(0xFFB8860B),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tafsir',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF5D278)
                        : const Color(0xFF8B6914),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _showTafsir ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
            child: Text(
              _verse!.tafsir!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.75,
                color: isDark ? Colors.white70 : const Color(0xFF444444),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          crossFadeState: _showTafsir
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

// ── Bouton d'action générique ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
