import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/tafsir_service.dart';
import 'tafsir_reader_screen.dart';

class TafsirLibraryScreen extends StatefulWidget {
  const TafsirLibraryScreen({super.key});

  @override
  State<TafsirLibraryScreen> createState() => _TafsirLibraryScreenState();
}

class _TafsirLibraryScreenState extends State<TafsirLibraryScreen> {
  // slug → true/false
  final Map<String, bool> _downloaded = {};
  // slug → 0.0-1.0 (null = not downloading)
  final Map<String, double> _progress = {};
  // slug → CancelToken
  final Map<String, CancelToken> _tokens = {};

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  @override
  void dispose() {
    for (final t in _tokens.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _checkAll() async {
    for (final book in TafsirService.catalog) {
      final ok = await TafsirService.isDownloaded(book);
      if (mounted) setState(() => _downloaded[book.slug] = ok);
    }
  }

  Future<void> _startDownload(TafsirBook book) async {
    if (_progress.containsKey(book.slug)) return; // already downloading

    final token = CancelToken();
    setState(() {
      _tokens[book.slug] = token;
      _progress[book.slug] = 0.0;
    });

    try {
      await TafsirService.download(
        book,
        cancelToken: token,
        onProgress: (progress, surah) {
          if (mounted) setState(() => _progress[book.slug] = progress);
        },
      );
      if (mounted) {
        setState(() {
          _downloaded[book.slug] = true;
          _progress.remove(book.slug);
          _tokens.remove(book.slug);
        });
        _showSnack('${book.nameAr} téléchargé avec succès');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress.remove(book.slug);
          _tokens.remove(book.slug);
        });
        if (e is! DioException || e.type != DioExceptionType.cancel) {
          _showSnack('Erreur lors du téléchargement');
        }
      }
    }
  }

  void _cancelDownload(TafsirBook book) {
    _tokens[book.slug]?.cancel();
    setState(() {
      _progress.remove(book.slug);
      _tokens.remove(book.slug);
    });
  }

  Future<void> _deleteBook(TafsirBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer ?',
            style: TextStyle(color: _textColor(ctx), fontWeight: FontWeight.w600)),
        content: Text(
          'Supprimer le téléchargement de « ${book.nameAr} » ?',
          textDirection: TextDirection.rtl,
          style: TextStyle(color: _textColor(ctx).withAlpha(200), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Colours ────────────────────────────────────────────────────────────────

  static Color _bg(BuildContext ctx) {
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    return dark ? const Color(0xFF0A0F1A) : const Color(0xFFF2ECE5);
  }

  static Color _textColor(BuildContext ctx) {
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    return dark ? Colors.white : const Color(0xFF1A1A1A);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = _bg(context);
    final textColor = _textColor(context);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: dark ? const Color(0xFF0A0F1A) : const Color(0xFFF2ECE5),
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: dark ? Colors.white : const Color(0xFF1A1A1A), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bibliothèque des Tafsirs',
                      style: TextStyle(
                        fontSize: 28,
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Commentaires du Coran en arabe',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withAlpha(140),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Grid ────────────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = TafsirService.catalog[index];
                  return _BookCard(
                    book: book,
                    isDownloaded: _downloaded[book.slug] ?? false,
                    progress: _progress[book.slug],
                    onDownload: () => _startDownload(book),
                    onCancel: () => _cancelDownload(book),
                    onOpen: () => _openBook(book),
                    onDelete: () => _deleteBook(book),
                  );
                },
                childCount: TafsirService.catalog.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Book Card
// ══════════════════════════════════════════════════════════════════════════════

class _BookCard extends StatelessWidget {
  final TafsirBook book;
  final bool isDownloaded;
  final double? progress; // null = not downloading
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
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

    return GestureDetector(
      onTap: isDownloaded ? onOpen : (isDownloading ? null : onDownload),
      onLongPress: isDownloaded ? onDelete : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: book.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: book.gradient.last.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ── Decorative pattern ───────────────────────────────────────
              Positioned.fill(child: _BookPattern()),

              // ── Spine accent ─────────────────────────────────────────────
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(40),
                        Colors.white.withAlpha(10),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gold ornament line top
                    Center(
                      child: Container(
                        width: 40,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            const Color(0xFFD4AF37).withAlpha(200),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Arabic title
                    Expanded(
                      child: Center(
                        child: Text(
                          book.nameAr,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Author
                    Text(
                      book.authorAr,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 13,
                        color: Colors.white.withAlpha(170),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Gold ornament line bottom
                    Center(
                      child: Container(
                        width: 40,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            const Color(0xFFD4AF37).withAlpha(200),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action / status
                    _ActionArea(
                      isDownloaded: isDownloaded,
                      isDownloading: isDownloading,
                      progress: progress,
                      onDownload: onDownload,
                      onCancel: onCancel,
                      onOpen: onOpen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Action area (download / progress / read)
// ══════════════════════════════════════════════════════════════════════════════

class _ActionArea extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  const _ActionArea({
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      final pct = ((progress ?? 0) * 100).round();
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withAlpha(40),
              color: const Color(0xFFD4AF37),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: onCancel,
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(50), width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, color: Colors.white, size: 15),
            SizedBox(width: 6),
            Text(
              'Lire',
              style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Not downloaded
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withAlpha(120), width: 1),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_rounded, color: Color(0xFFD4AF37), size: 15),
          SizedBox(width: 6),
          Text(
            'Télécharger',
            style: TextStyle(
                color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Subtle background pattern for book cover
// ══════════════════════════════════════════════════════════════════════════════

class _BookPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PatternPainter());
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;

    // Diagonal lines
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
