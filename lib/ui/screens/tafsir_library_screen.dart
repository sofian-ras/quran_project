import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/tafsir_service.dart';
import '../../services/tafsir_download_manager.dart';
import 'tafsir_reader_screen.dart';

class TafsirLibraryScreen extends StatefulWidget {
  const TafsirLibraryScreen({super.key});

  @override
  State<TafsirLibraryScreen> createState() => _TafsirLibraryScreenState();
}

class _TafsirLibraryScreenState extends State<TafsirLibraryScreen> {
  final Map<String, bool> _downloaded = {};
  final Map<String, VoidCallback> _listeners = {};

  @override
  void initState() {
    super.initState();
    _checkAll();
    _setupListeners();
  }

  @override
  void dispose() {
    for (final book in TafsirService.catalog) {
      final cb = _listeners[book.slug];
      if (cb != null) {
        TafsirDownloadManager.instance.progressFor(book.slug).removeListener(cb);
      }
    }
    super.dispose();
  }

  /// Écoute chaque ValueNotifier de progression pour rafraîchir l'UI.
  void _setupListeners() {
    for (final book in TafsirService.catalog) {
      void listener() {
        if (!mounted) return;
        setState(() {});
        // Quand le téléchargement se termine (null), vérifier si installé
        if (TafsirDownloadManager.instance.progressFor(book.slug).value == null) {
          TafsirService.isDownloaded(book).then((ok) {
            if (mounted) setState(() => _downloaded[book.slug] = ok);
          });
        }
      }
      _listeners[book.slug] = listener;
      TafsirDownloadManager.instance.progressFor(book.slug).addListener(listener);
    }
  }

  Future<void> _checkAll() async {
    for (final book in TafsirService.catalog) {
      final ok = await TafsirService.isDownloaded(book);
      if (mounted) setState(() => _downloaded[book.slug] = ok);
    }
  }

  void _startDownload(TafsirBook book) {
    TafsirDownloadManager.instance.start(book);
    setState(() {}); // affiche immédiatement la barre de progression
  }

  void _cancelDownload(TafsirBook book) {
    TafsirDownloadManager.instance.cancel(book.slug);
  }

  Future<void> _deleteBook(TafsirBook book) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1C2333) : const Color(0xFFF5EDD7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Supprimer ?',
          style: TextStyle(
            color: dark ? const Color(0xFFE8D5B0) : const Color(0xFF2C1810),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Supprimer le téléchargement de « ${book.nameAr} » ?',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: dark ? const Color(0xFFB8A080) : const Color(0xFF5A3A20),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TafsirService.deleteBook(book);
      if (mounted) setState(() => _downloaded[book.slug] = false);
    }
  }

  void _openBook(TafsirBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TafsirReaderScreen(book: book)),
    );
  }

@override
  Widget build(BuildContext context) {
    final dark    = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.of(context).padding;
    final screen  = MediaQuery.of(context).size;
    // fond_tafsir.webp : 1035×1631 — banderole courbée, bas max Y=181
    const double imgH       = 1631.0;
    const double bannerHImg =  181.0;
    final bannerH = screen.height * (bannerHImg / imgH);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Fond image plein écran ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/tafsir/fond_tafsir.webp',
              fit: BoxFit.fill,
            ),
          ),

          // ── "Tafsir" centré dans la banderole ──────────────────────────────
          Positioned(
            top: padding.top + 4, left: 0, right: 0,
            height: bannerH - padding.top - 10,
            child: const Center(
              child: Text(
                'Tafsir',
                style: TextStyle(
                  fontSize:      18,
                  color:         Color(0xFF6B3E18),
                  letterSpacing: 3.0,
                  fontWeight:    FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Grille scrollable — clippée sous la ligne ───────────────────────
          Positioned(
            top: bannerH + 90, bottom: 0, left: 0, right: 0,
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, padding.bottom + 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                childAspectRatio: 0.60,
                crossAxisSpacing: 14,
                mainAxisSpacing:  18,
              ),
              itemCount: TafsirService.catalog.length,
              itemBuilder: (ctx, i) {
                final book = TafsirService.catalog[i];
                return _BookCard(
                  book:         book,
                  dark:         dark,
                  isDownloaded: _downloaded[book.slug] ?? false,
                  progress:     TafsirDownloadManager.instance.progressFor(book.slug).value,
                  onDownload:   () => _startDownload(book),
                  onCancel:     () => _cancelDownload(book),
                  onOpen:       () => _openBook(book),
                  onDelete:     () => _deleteBook(book),
                );
              },
            ),
          ),

          // ── Titre fixe + long trait ─────────────────────────────────────────
          Positioned(
            top: bannerH, left: 0, right: 0,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _SectionTitle(dark: dark),
                  const SizedBox(height: 8),
                  Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xFFC8A97E),
                  ),
                  const SizedBox(height: 8),
                ],
            ),
          ),

          // ── Bouton retour ───────────────────────────────────────────────────
          Positioned(
            top: padding.top, left: 0, right: 0,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Color(0xFF6B3E18)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Titre التفاسير + SVG calligraphie ─────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final bool dark;
  const _SectionTitle({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 70,
          child: SvgPicture.asset(
            'assets/images/tafsir/rabbi__header_h56.svg',
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(
              Color(0xFF6B3E18),
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Book Card
// ══════════════════════════════════════════════════════════════════════════════

class _BookCard extends StatelessWidget {
  final TafsirBook book;
  final bool       dark;
  final bool       isDownloaded;
  final double?    progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.dark,
    required this.isDownloaded,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = progress != null;
    // Parchment-style card: slightly darker than page background, subtle warm border
    const cardBg      = Colors.transparent;
    final borderColor = dark
        ? Colors.white.withAlpha(12)
        : const Color(0xFFC8B89A).withAlpha(85);
    final shadowColor = dark
        ? Colors.black.withAlpha(60)
        : Colors.black.withAlpha(18);

    return GestureDetector(
      onTap:      isDownloaded ? onOpen : (isDownloading ? null : onDownload),
      onLongPress: isDownloaded ? onDelete : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color:      shadowColor,
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Book cover image (≈ 60 % de la hauteur) ─────────────────────
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Image.asset(
                    'assets/tafsir/${book.slug}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _BookCoverPlaceholder(book: book),
                  ),
                ),
              ),
            ),

            // ── Info (≈ 40 % de la hauteur) ──────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titres
                    Column(
                      children: [
                        Text(
                          book.nameAr,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'UthmanTahaNaskh',
                            fontSize:   20,
                            color: dark
                                ? const Color(0xFFE8D5B0)
                                : const Color(0xFF4A3F30),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.nameFr,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: dark
                                ? const Color(0xFF9B8060)
                                : const Color(0xFF8B7050),
                          ),
                        ),
                      ],
                    ),

                    // Statut
                    _StatusChip(
                      isDownloaded:  isDownloaded,
                      isDownloading: isDownloading,
                      progress:      progress,
                      dark:          dark,
                      onCancel:      onCancel,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder quand l'image du livre n'est pas encore fournie ──────────────

class _BookCoverPlaceholder extends StatelessWidget {
  final TafsirBook book;
  const _BookCoverPlaceholder({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: book.gradient,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color:      book.gradient.last.withAlpha(80),
            blurRadius: 12,
            offset:     const Offset(2, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Reliure (bande gauche)
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Motif diagonal subtil
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(painter: _DiagonalPatternPainter()),
            ),
          ),
          // Texte centré
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 1,
                    color: Colors.white.withAlpha(90),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.nameAr,
                    textAlign:     TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily:  'UthmanTahaNaskh',
                      fontSize:    20,
                      color:       Colors.white,
                      fontWeight:  FontWeight.w700,
                      height:      1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.authorAr,
                    textAlign:     TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize:   12,
                      color:      Colors.white.withAlpha(170),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 1,
                    color: Colors.white.withAlpha(90),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const spacing = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool       isDownloaded;
  final bool       isDownloading;
  final double?    progress;
  final bool       dark;
  final VoidCallback onCancel;

  const _StatusChip({
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.dark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: dark
                  ? Colors.white.withAlpha(20)
                  : const Color(0xFFE8D9C0),
              color:     const Color(0xFFD4AF37),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${((progress ?? 0) * 100).round()}%',
                style: const TextStyle(
                    fontSize: 10,
                    color:    Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  'Annuler',
                  style: TextStyle(
                      fontSize: 10,
                      color: dark ? Colors.white38 : Colors.black38),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Shared golden chip style (manuscript aesthetic)
    final chipColors = dark
        ? [const Color(0xFF4A2E06), const Color(0xFF6B4510)]
        : [const Color(0xFFE8D5B3), const Color(0xFFCFAF7E)];
    final chipBorder  = dark ? const Color(0xFF8B6814) : const Color(0xFFC8A97E);
    final chipLabel   = dark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);

    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: chipColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder, width: 1.2),
        ),
        child: Row(
          mainAxisSize:      MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 12, color: chipLabel),
            const SizedBox(width: 5),
            Text(
              'Hors ligne',
              style: TextStyle(fontSize: 11, color: chipLabel,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Non téléchargé
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: chipColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(15),
            blurRadius: 3,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize:      MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_rounded, size: 12, color: chipLabel),
          const SizedBox(width: 5),
          Text(
            'Télécharger',
            style: TextStyle(fontSize: 11, color: chipLabel,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
