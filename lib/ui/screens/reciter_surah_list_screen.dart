// lib/ui/reciter_surah_list_screen.dart
//
// Liste des sourates pour un récitateur.
// Thème identique au home screen (gradient beige/dark).

import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';
import '../../services/download_service.dart';
import '../../data/surah_name.dart';
import '../widgets/mini_audio_player.dart';
// ── Gradients (même que home screen) ─────────────────────────────────────────
const _kDarkBgColors = [
  Color(0xFF020617),
  Color(0xFF0B1025),
  Color(0xFF1A0033),
  Color(0xFF2D1B4E),
];
const _kLightBgColors = [
  Color(0xFFFFF7E8),
  Color(0xFFF7EEDB),
  Color(0xFFF2E4CC),
];

LinearGradient _bgGrad(bool dark) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark ? _kDarkBgColors : _kLightBgColors,
    );

// Couleurs header (première teinte du gradient)
Color _headerBg(bool dark) =>
    dark ? const Color(0xFF020617) : const Color(0xFFFFF7E8);

// Accent audio uniquement
const _kPlay = Color(0xFF0E6B63);

// ── Noms arabes (114 sourates) ────────────────────────────────────────────────
const _surahAr = [
  '', // index 0 inutilisé
  'الفاتحة','البقرة','آل عمران','النساء','المائدة',
  'الأنعام','الأعراف','الأنفال','التوبة','يونس',
  'هود','يوسف','الرعد','إبراهيم','الحجر',
  'النحل','الإسراء','الكهف','مريم','طه',
  'الأنبياء','الحج','المؤمنون','النور','الفرقان',
  'الشعراء','النمل','القصص','العنكبوت','الروم',
  'لقمان','السجدة','الأحزاب','سبأ','فاطر',
  'يس','الصافات','ص','الزمر','غافر',
  'فصلت','الشورى','الزخرف','الدخان','الجاثية',
  'الأحقاف','محمد','الفتح','الحجرات','ق',
  'الذاريات','الطور','النجم','القمر','الرحمن',
  'الواقعة','الحديد','المجادلة','الحشر','الممتحنة',
  'الصف','الجمعة','المنافقون','التغابن','الطلاق',
  'التحريم','الملك','القلم','الحاقة','المعارج',
  'نوح','الجن','المزمل','المدثر','القيامة',
  'الإنسان','المرسلات','النبأ','النازعات','عبس',
  'التكوير','الانفطار','المطففين','الانشقاق','البروج',
  'الطارق','الأعلى','الغاشية','الفجر','البلد',
  'الشمس','الليل','الضحى','الشرح','التين',
  'العلق','القدر','البينة','الزلزلة','العاديات',
  'القارعة','التكاثر','العصر','الهمزة','الفيل',
  'قريش','الماعون','الكوثر','الكافرون','النصر',
  'المسد','الإخلاص','الفلق','الناس',
];

// ── Écran ─────────────────────────────────────────────────────────────────────
class ReciterSurahListScreen extends StatefulWidget {
  final String    name;
  final String?   arabicName;
  final String?   country;
  final String?   asset;
  final String    server;
  final String    moshafLabel;
  final List<int> surahList;

  const ReciterSurahListScreen({
    super.key,
    required this.name,
    this.arabicName,
    this.country,
    this.asset,
    required this.server,
    required this.moshafLabel,
    required this.surahList,
  });

  @override
  State<ReciterSurahListScreen> createState() => _ReciterSurahListScreenState();
}

class _ReciterSurahListScreenState extends State<ReciterSurahListScreen> {
  final AudioService    _audio = AudioService.instance;
  final DownloadService _dl    = DownloadService.instance;

  Set<int>                           _downloaded  = {};
  final Map<int, ValueNotifier<double?>> _dlProgress = {};
  bool         _dlAllRunning = false;
  CancelToken? _dlAllCancel;

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
  }

  @override
  void dispose() {
    for (final n in _dlProgress.values) { n.dispose(); }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _loadDownloaded() async {
    final ids = await _dl.listDownloadedSurahIds(widget.server);
    if (mounted) setState(() => _downloaded = ids.toSet());
  }

  ValueNotifier<double?> _progressFor(int id) =>
      _dlProgress.putIfAbsent(id, () => ValueNotifier<double?>(null));

  void _play(int surahId) {
    final displayName = widget.moshafLabel.isEmpty
        ? widget.name
        : '${widget.name} (${widget.moshafLabel})';
    _audio.setReciter(displayName, widget.server, assetPath: widget.asset);
    _audio.loadPlaylistAndPlay(surahId);
  }

  // ── Téléchargement sourate ──────────────────────────────────────────────────

  Future<void> _askAndDownloadSurah(int surahId) async {
    final frName = surahFr[surahId] ?? 'Sourate $surahId';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(color: _kPlay)),
        ),
      ),
    );
    final size = await _dl.fetchSurahSize(widget.server, surahId);
    if (!mounted) return;
    Navigator.of(context).pop();

    final sizeStr = size != null ? _dl.formatSize(size) : 'taille inconnue';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Télécharger $frName'),
        content: Text(
            'Cette sourate pèse environ $sizeStr.\nTélécharger pour une écoute hors-ligne ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Télécharger',
                  style: TextStyle(color: _kPlay))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final progress = _progressFor(surahId);
    final cancel   = CancelToken();
    final path = await _dl.downloadQuranSurah(
      widget.server, surahId,
      progress: progress, cancelToken: cancel,
    );
    if (path != null && mounted) {
      setState(() => _downloaded.add(surahId));
      await _audio.updateSurahSource(surahId, path);
      await _saveReciterInfo();
    }
  }

  // ── Téléchargement complet ──────────────────────────────────────────────────

  Future<void> _askAndDownloadAll() async {
    if (_dlAllRunning) return;
    final toDownload =
        widget.surahList.where((id) => !_downloaded.contains(id)).toList();
    if (toDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Toutes les sourates sont déjà téléchargées !')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(color: _kPlay)),
        ),
      ),
    );
    final estBytes = await _dl.estimateReciterSize(widget.server, toDownload);
    if (!mounted) return;
    Navigator.of(context).pop();

    final estStr =
        estBytes != null ? '~${_dl.formatSize(estBytes)}' : 'taille inconnue';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Télécharger tout'),
        content: Text(
          '${toDownload.length} sourate${toDownload.length > 1 ? 's' : ''} à télécharger.\n'
          'Taille estimée : $estStr\n\n'
          'Les fichiers seront disponibles hors-ligne.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Télécharger',
                  style: TextStyle(color: _kPlay))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _dlAllRunning = true);
    _dlAllCancel = CancelToken();

    for (final surahId in toDownload) {
      if (!mounted || (_dlAllCancel?.isCancelled ?? true)) break;
      final path = await _dl.downloadQuranSurah(
        widget.server, surahId,
        progress: _progressFor(surahId),
        cancelToken: _dlAllCancel,
      );
      if (path != null && mounted) {
        setState(() => _downloaded.add(surahId));
        await _audio.updateSurahSource(surahId, path);
      }
    }

    if (mounted) {
      setState(() { _dlAllRunning = false; _dlAllCancel = null; });
      await _saveReciterInfo();
    }
  }

  void _cancelAll() {
    _dlAllCancel?.cancel('Annulé');
    setState(() { _dlAllRunning = false; _dlAllCancel = null; });
  }

  Future<void> _saveReciterInfo() async {
    final ids = await _dl.listDownloadedSurahIds(widget.server);
    if (ids.isEmpty) return;
    await _dl.saveReciterDownloadInfo(
      server:      widget.server,
      name:        widget.name,
      arabicName:  widget.arabicName,
      country:     widget.country,
      asset:       widget.asset,
      moshafLabel: widget.moshafLabel,
      surahList:   ids,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final topPad  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bgGrad(isDark)),
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ReciterHeader(
                    name:             widget.name,
                    arabicName:       widget.arabicName,
                    country:          widget.country,
                    asset:            widget.asset,
                    moshafLabel:      widget.moshafLabel,
                    isDark:           isDark,
                    downloadedCount:  _downloaded.length,
                    totalCount:       widget.surahList.length,
                    isDownloadingAll: _dlAllRunning,
                    onDownloadAll:    _dlAllRunning ? _cancelAll : _askAndDownloadAll,
                    topPadding:       topPad,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final surahId = widget.surahList[i];
                        return _SurahRow(
                          surahId:      surahId,
                          isDark:       isDark,
                          audio:        _audio,
                          isDownloaded: _downloaded.contains(surahId),
                          dlProgress:   _dlProgress[surahId],
                          onPlay:       () => _play(surahId),
                          onDownload:   _downloaded.contains(surahId)
                              ? null
                              : () => _askAndDownloadSurah(surahId),
                        );
                      },
                      childCount: widget.surahList.length,
                    ),
                  ),
                ),
              ],
            ),


            // Mini lecteur ancré en bas (visible uniquement sur cet écran)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom,
              child: StreamBuilder<bool>(
                stream: _audio.isActiveStream,
                builder: (_, snap) {
                  if (!(snap.data ?? false)) return const SizedBox.shrink();
                  return MiniPlayerContainer(onDismiss: _audio.stopAll);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header SliverDelegate ─────────────────────────────────────────────────────

class _ReciterHeader extends SliverPersistentHeaderDelegate {
  final String  name;
  final String? arabicName;
  final String? country;
  final String? asset;
  final String  moshafLabel;
  final bool    isDark;
  final int     downloadedCount;
  final int     totalCount;
  final bool    isDownloadingAll;
  final VoidCallback onDownloadAll;
  final double  topPadding;

  _ReciterHeader({
    required this.name,
    this.arabicName,
    this.country,
    this.asset,
    required this.moshafLabel,
    required this.isDark,
    required this.downloadedCount,
    required this.totalCount,
    required this.isDownloadingAll,
    required this.onDownloadAll,
    required this.topPadding,
  });

  @override double get minExtent => kToolbarHeight + topPadding;
  @override double get maxExtent => kToolbarHeight + topPadding + 110;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final t   = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final fg  = isDark ? Colors.white       : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54     : const Color(0xFF64748B);
    final bg  = _headerBg(isDark);

    // Légère ombre quand épinglé et scrollé
    final shadow = overlaps || shrinkOffset > 10
        ? [BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )]
        : <BoxShadow>[];

    return Container(
      color: bg,
      child: Stack(
        children: [
          // Décoration géométrique subtile (remplace les étoiles teal)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GeoPainter(isDark: isDark)),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Barre de navigation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: fg, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: t > 0.5 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 120),
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: fg,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Bouton télécharger tout
                      IconButton(
                        tooltip: isDownloadingAll
                            ? 'Annuler'
                            : downloadedCount == totalCount
                                ? 'Tout est téléchargé'
                                : 'Télécharger tout',
                        icon: isDownloadingAll
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: fg, strokeWidth: 2),
                              )
                            : Icon(
                                downloadedCount == totalCount
                                    ? Icons.download_done_rounded
                                    : Icons.download_for_offline_rounded,
                                color: downloadedCount == totalCount
                                    ? _kPlay
                                    : fg,
                                size: 22,
                              ),
                        onPressed: downloadedCount == totalCount &&
                                !isDownloadingAll
                            ? null
                            : onDownloadAll,
                      ),
                    ],
                  ),
                ),

                // Infos étendues
                SizedBox(
                  height: (maxExtent - minExtent - shrinkOffset)
                      .clamp(0.0, maxExtent - minExtent),
                  child: ClipRect(
                    child: Opacity(
                    opacity: (1.0 - t * 2).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                      child: Row(
                        children: [
                          // Avatar
                          _Avatar(
                              name: name, asset: asset,
                              size: 56, isDark: isDark),
                          const SizedBox(width: 14),

                          // Texte
                          Expanded(
                            child: OverflowBox(
                              minHeight: 0,
                              maxHeight: double.infinity,
                              alignment: Alignment.centerLeft,
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name,
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (arabicName != null) ...[
                                  const SizedBox(height: 1),
                                  Text(arabicName!,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                          color: sub, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 5,
                                  children: [
                                    if (country != null)
                                      _InfoChip(
                                          label: country!,
                                          icon: Icons.public_rounded,
                                          isDark: isDark),
                                    if (moshafLabel.isNotEmpty)
                                      _InfoChip(
                                          label: moshafLabel,
                                          isDark: isDark),
                                    if (downloadedCount > 0)
                                      _InfoChip(
                                          label:
                                              '$downloadedCount/$totalCount téléchargées',
                                          icon: Icons.download_done_rounded,
                                          isDark: isDark,
                                          accent: true),
                                  ],
                                ),
                              ],
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),

          // Ligne de séparation subtile en bas
          if (shadow.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 1,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.07),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ReciterHeader old) =>
      old.isDark != isDark ||
      old.name != name ||
      old.downloadedCount != downloadedCount ||
      old.isDownloadingAll != isDownloadingAll ||
      old.topPadding != topPadding;
}

// ── Ligne sourate ─────────────────────────────────────────────────────────────

class _SurahRow extends StatelessWidget {
  final int          surahId;
  final bool         isDark;
  final AudioService audio;
  final bool         isDownloaded;
  final ValueNotifier<double?>? dlProgress;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;

  const _SurahRow({
    required this.surahId,
    required this.isDark,
    required this.audio,
    required this.isDownloaded,
    required this.onPlay,
    this.dlProgress,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final fg    = isDark ? Colors.white      : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white54    : const Color(0xFF64748B);
    final div   = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    final frName = surahFr[surahId] ?? 'Sourate $surahId';
    final arName = surahId < _surahAr.length ? _surahAr[surahId] : '';

    return ValueListenableBuilder<int?>(
      valueListenable: audio.currentPlayingSurahIdNotifier,
      builder: (_, current, __) {
        final isPlaying = current == surahId;

        return InkWell(
          onTap: onPlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isPlaying ? activeBg : Colors.transparent,
              border: Border(
                left: isPlaying
                    ? const BorderSide(color: _kPlay, width: 3)
                    : BorderSide.none,
                bottom: BorderSide(color: div, width: 0.5),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                isPlaying ? 13 : 16, 13, 8, 13),
            child: Row(
              children: [
                // Numéro
                SizedBox(
                  width: 36,
                  child: Text(
                    '$surahId',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPlaying ? _kPlay : muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Noms
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(frName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isPlaying
                                ? FontWeight.w700 : FontWeight.w600,
                            color: isPlaying ? _kPlay : fg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (arName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(arName,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontSize: 12,
                                color: muted,
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),

                // Icône téléchargement
                _DlIcon(
                  isDownloaded: isDownloaded,
                  dlProgress:   dlProgress,
                  isDark:       isDark,
                  onTap:        onDownload,
                ),
                const SizedBox(width: 4),

                // Icône lecture
                StreamBuilder<PlayerState>(
                  stream: audio.playerStateStream,
                  builder: (_, snap) {
                    final playing = snap.data?.playing ?? false;
                    final loading =
                        snap.data?.processingState == ProcessingState.buffering
                        || snap.data?.processingState ==
                            ProcessingState.loading;

                    if (isPlaying && loading) {
                      return const SizedBox(
                        width: 32, height: 32,
                        child: Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              color: _kPlay, strokeWidth: 2),
                        ),
                      );
                    }
                    return Icon(
                      isPlaying && playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_outline_rounded,
                      color: isPlaying
                          ? _kPlay
                          : (isDark ? Colors.white24 : Colors.black26),
                      size: 32,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Icône téléchargement réactive ────────────────────────────────────────────

class _DlIcon extends StatelessWidget {
  final bool         isDownloaded;
  final ValueNotifier<double?>? dlProgress;
  final bool         isDark;
  final VoidCallback? onTap;
  const _DlIcon({
    required this.isDownloaded,
    required this.isDark,
    this.dlProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dlProgress != null) {
      return ValueListenableBuilder<double?>(
        valueListenable: dlProgress!,
        builder: (_, prog, __) {
          if (prog != null) {
            return SizedBox(
              width: 28, height: 28,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: CircularProgressIndicator(
                  value: prog > 0 ? prog : null,
                  strokeWidth: 2,
                  color: _kPlay,
                ),
              ),
            );
          }
          return _static();
        },
      );
    }
    return _static();
  }

  Widget _static() {
    if (isDownloaded) {
      return Icon(Icons.download_done_rounded,
          color: _kPlay.withValues(alpha: 0.7), size: 20);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.download_outlined,
            color: isDark ? Colors.white24 : Colors.black26, size: 20),
      ),
    );
  }
}
// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String  name;
  final String? asset;
  final double  size;
  final bool    isDark;
  const _Avatar({
    required this.name,
    this.asset,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return ClipOval(
        child: Image.asset(
          asset!,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letter(),
        ),
      );
    }
    return _letter();
  }

  Widget _letter() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.12),
            isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(letter,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: size * 0.40,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}

// ── Chip d'info header ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String    label;
  final IconData? icon;
  final bool      isDark;
  final bool      accent;
  const _InfoChip({
    required this.label,
    this.icon,
    required this.isDark,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? _kPlay
        : (isDark ? Colors.white54 : const Color(0xFF64748B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black)
            .withValues(alpha: accent ? 0.08 : 0.06),
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

// ── Décoration géométrique subtile (remplace les étoiles teal) ───────────────

class _GeoPainter extends CustomPainter {
  final bool isDark;
  const _GeoPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(17);
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.04 : 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 8; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r  = 20 + rng.nextDouble() * 60;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_GeoPainter old) => old.isDark != isDark;
}
