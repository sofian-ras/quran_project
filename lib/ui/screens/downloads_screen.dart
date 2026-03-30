import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/download_service.dart';
import '../../services/quran_image_service.dart';
import '../../services/qul_audio/audio_download_manager.dart' hide DownloadStatus;
import '../../services/qul_audio/qul_catalog_service.dart';
import '../../data/surah_name.dart';
import '../../theme/app_theme.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _AudioEntry {
  final int surahId;
  final String filePath; // fichier pour mp3quran/qul, dossier pour ayahCache
  final int sizeBytes;
  final int? quranComId;
  final bool isAyahCache; // true → filePath est un répertoire

  const _AudioEntry({
    required this.surahId,
    required this.filePath,
    required this.sizeBytes,
    this.quranComId,
    this.isAyahCache = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService.instance;
  late TabController _tabController;

  // Quran pages
  bool _quranReady = false;
  bool _quranDownloading = false;
  bool _quranExtracting = false;
  double _quranProgress = 0.0;
  int _quranCacheBytes = 0;
  Timer? _quranPollTimer;

  // Audio scan
  Future<Map<String, List<_AudioEntry>>>? _audioFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshQuranPagesState();
    _refreshAudio();
    _quranPollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final st = QuranImageService.instance.getDownloadStatus();
      final bool d = st['isDownloading'] == true;
      final bool e = st['isExtracting'] == true;
      final double prog = (st['downloadProgress'] is double)
          ? st['downloadProgress'] as double
          : 0.0;
      if (!mounted) return;
      if (d != _quranDownloading || e != _quranExtracting || prog != _quranProgress) {
        setState(() {
          _quranDownloading = d;
          _quranExtracting = e;
          _quranProgress = prog;
        });
      }
      if (!d && !e && _quranProgress >= 1.0) _refreshQuranPagesState();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quranPollTimer?.cancel();
    super.dispose();
  }

  // ── Quran pages ─────────────────────────────────────────────────────────────

  Future<void> _refreshQuranPagesState() async {
    final ready = await QuranImageService.instance.areImagesDownloaded();
    final size = ready ? await QuranImageService.instance.getCacheSize() : 0;
    if (!mounted) return;
    setState(() {
      _quranReady = ready;
      _quranCacheBytes = size;
    });
  }

  Future<void> _downloadQuranPages() async {
    setState(() {
      _quranDownloading = true;
      _quranExtracting = false;
      _quranProgress = 0.0;
    });
    try {
      await QuranImageService.instance.downloadAndExtractImages(
        onDownloadProgress: (prog) {
          if (!mounted) return;
          setState(() {
            _quranProgress = prog;
            _quranDownloading = true;
            _quranExtracting = false;
          });
        },
      );
    } catch (_) {
    } finally {
      await _refreshQuranPagesState();
      if (!mounted) return;
      setState(() {
        _quranDownloading = false;
        _quranExtracting = false;
      });
    }
  }

  Future<void> _clearQuranPages() async {
    await QuranImageService.instance.clearCache();
    await _refreshQuranPagesState();
  }

  // ── Audio scan ───────────────────────────────────────────────────────────────

  void _refreshAudio() => setState(() { _audioFuture = _scanAudioFiles(); });

  /// Scans quran_audio/ (mp3quran) + qul_audio/ (mushaf mini-player).
  /// quran_audio/001.mp3             → group 'default'
  /// quran_audio/{server_key}/001.mp3→ group = server_key
  /// qul_audio/{qid}/surah_{n}.mp3  → group 'qul_{qid}'
  Future<Map<String, List<_AudioEntry>>> _scanAudioFiles() async {
    final docs = await getApplicationDocumentsDirectory();
    final Map<String, List<_AudioEntry>> result = {};

    // ── quran_audio/ ────────────────────────────────────────────────────────
    final audioDir = Directory(p.join(docs.path, 'quran_audio'));
    if (await audioDir.exists()) {
      await for (final entity in audioDir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.mp3')) continue;
        final relative = p.relative(entity.path, from: audioDir.path);
        final parts = p.split(relative);
        String reciterKey;
        int? surahId;
        if (parts.length == 1) {
          reciterKey = 'default';
          surahId = int.tryParse(parts[0].replaceAll('.mp3', ''));
        } else {
          reciterKey = parts[0];
          surahId = int.tryParse(parts.last.replaceAll('.mp3', ''));
        }
        if (surahId == null || surahId < 1 || surahId > 114) continue;
        final size = await entity.length();
        result.putIfAbsent(reciterKey, () => []).add(_AudioEntry(
          surahId: surahId, filePath: entity.path, sizeBytes: size,
        ));
      }
    }

    // ── qul_audio/ ──────────────────────────────────────────────────────────
    // Sourates complètes téléchargées via le mini-lecteur
    final qulDir = Directory(p.join(docs.path, 'qul_audio'));
    if (await qulDir.exists()) {
      await for (final entity in qulDir.list(recursive: true)) {
        if (entity is! File) continue;
        final fname = p.basename(entity.path);
        if (!fname.startsWith('surah_') || !fname.endsWith('.mp3')) continue;
        final surahId = int.tryParse(
            fname.replaceFirst('surah_', '').replaceAll('.mp3', ''));
        if (surahId == null || surahId < 1 || surahId > 114) continue;
        final qid = int.tryParse(p.basename(p.dirname(entity.path)));
        if (qid == null) continue;
        final size = await entity.length();
        result.putIfAbsent('qul_$qid', () => []).add(_AudioEntry(
          surahId: surahId, filePath: entity.path, sizeBytes: size,
          quranComId: qid,
        ));
      }
    }

    // ── ayah_cache/ ─────────────────────────────────────────────────────────
    // Versets téléchargés via la barre audio du Coran traduit
    // Structure : ayah_cache/{qid|qul_N}/{surah_padded}/001001.mp3 …
    final ayahDir = Directory(p.join(docs.path, 'ayah_cache'));
    if (await ayahDir.exists()) {
      await for (final qidEntity in ayahDir.list()) {
        if (qidEntity is! Directory) continue;
        final qidStr = p.basename(qidEntity.path);
        // folderId est soit un entier (quranComId) soit 'qul_{qulId}'
        final qid = int.tryParse(qidStr);

        await for (final surahEntity in qidEntity.list()) {
          if (surahEntity is! Directory) continue;
          final surahId = int.tryParse(p.basename(surahEntity.path));
          if (surahId == null || surahId < 1 || surahId > 114) continue;

          int totalSize = 0;
          int fileCount = 0;
          await for (final f in surahEntity.list()) {
            if (f is File && f.path.endsWith('.mp3')) {
              totalSize += await f.length();
              fileCount++;
            }
          }
          if (fileCount == 0) continue;

          final groupKey = 'ayah_${qid ?? qidStr}';
          result.putIfAbsent(groupKey, () => []).add(_AudioEntry(
            surahId: surahId,
            filePath: surahEntity.path, // répertoire
            sizeBytes: totalSize,
            quranComId: qid,
            isAyahCache: true,
          ));
        }
      }
    }

    for (final list in result.values) {
      list.sort((a, b) => a.surahId.compareTo(b.surahId));
    }
    return result;
  }

  Future<void> _deleteAudioEntry(_AudioEntry entry) async {
    try {
      if (entry.isAyahCache) {
        // Supprimer tout le répertoire de la sourate
        final dir = Directory(entry.filePath);
        if (await dir.exists()) await dir.delete(recursive: true);
      } else {
        final f = File(entry.filePath);
        if (await f.exists()) await f.delete();
        // Nettoyer l'état persisté de l'AudioDownloadManager pour les entrées QUL
        if (entry.quranComId != null) {
          await AudioDownloadManager.instance.delete(
              AudioDownloadManager.surahKey(entry.quranComId!, entry.surahId));
        }
      }
    } catch (_) {}
    _refreshAudio();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _reciterLabel(String key) {
    if (key == 'default') return 'Récitation principale';

    // qul_audio : sourate complète téléchargée via mini-lecteur
    if (key.startsWith('qul_')) {
      final qid = int.tryParse(key.substring(4));
      if (qid != null) {
        final r = QulCatalogService.reciters
            .where((r) => r.quranComId == qid)
            .firstOrNull;
        if (r != null) return r.displayName;
      }
      return 'Récitateur';
    }

    // ayah_cache : versets téléchargés via Coran traduit
    if (key.startsWith('ayah_')) {
      final suffix = key.substring(5);
      // suffix est un quranComId entier ou 'qul_{qulId}'
      final qid = int.tryParse(suffix);
      if (qid != null) {
        final r = QulCatalogService.reciters
            .where((r) => r.quranComId == qid)
            .firstOrNull;
        if (r != null) return '${r.displayName} — versets';
      }
      if (suffix.startsWith('qul_')) {
        final qulId = int.tryParse(suffix.substring(4));
        if (qulId != null) {
          final r = QulCatalogService.reciters
              .where((r) => r.qulId == qulId)
              .firstOrNull;
          if (r != null) return '${r.displayName} — versets';
        }
      }
      return 'Récitateur — versets';
    }

    // Clé serveur mp3quran : nettoyage de l'URL encodée
    final cleaned = key
        .replaceAll(RegExp(r'^server\d+_mp3quran_net_'), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? key : cleaned;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1923) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Téléchargements'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'En cours'),
            Tab(text: 'Bibliothèque'),
            Tab(text: 'Stockage'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInProgressTab(),
          _buildLibraryTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }

  // ── Tab : En cours ───────────────────────────────────────────────────────────

  Widget _buildInProgressTab() {
    return StreamBuilder<List<DownloadItem>>(
      stream: _downloadService.downloadsStream,
      builder: (context, snapshot) {
        final inProgress = (snapshot.data ?? [])
            .where((d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.paused)
            .toList();

        if (!_quranDownloading && !_quranExtracting && inProgress.isEmpty) {
          return _buildEmptyState(
            icon: CupertinoIcons.checkmark_circle,
            title: 'Aucun téléchargement en cours',
            subtitle:
                'Téléchargez des sourates ou des pages\npour les accéder hors ligne',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_quranDownloading || _quranExtracting) _buildQuranPagesCard(),
            ...inProgress.map((d) => _buildDownloadCard(d)),
          ],
        );
      },
    );
  }

  // ── Tab : Bibliothèque ───────────────────────────────────────────────────────

  Widget _buildLibraryTab() {
    return FutureBuilder<Map<String, List<_AudioEntry>>>(
      future: _audioFuture,
      builder: (context, audioSnap) {
        final audioGroups = audioSnap.data ?? {};
        final totalAudio =
            audioGroups.values.fold(0, (s, l) => s + l.length);

        return RefreshIndicator(
          onRefresh: () async => _refreshAudio(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Pages du Coran ──────────────────────────────────
              _buildSectionHeader(
                icon: CupertinoIcons.doc_text,
                title: 'Pages du Coran',
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              _buildQuranPagesCard(),
              const SizedBox(height: 24),

              // ── Audio ───────────────────────────────────────────
              _buildSectionHeader(
                icon: CupertinoIcons.music_note_2,
                title: 'Audio téléchargé',
                count: totalAudio,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 10),

              if (audioSnap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (audioGroups.isEmpty)
                _buildEmptyAudioCard()
              else
                ...audioGroups.entries.map(
                  (e) => _buildReciterGroup(
                    reciterKey: e.key,
                    entries: e.value,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyAudioCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: _cardDecoration(isDark),
      child: Column(
        children: [
          Icon(CupertinoIcons.music_note_2, size: 44, color: Colors.grey[400]),
          const SizedBox(height: 14),
          Text(
            'Aucun audio téléchargé',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dans le lecteur audio, appuyez sur l\'icône\ntéléchargement pour sauvegarder une sourate.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReciterGroup({
    required String reciterKey,
    required List<_AudioEntry> entries,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSize = entries.fold(0, (s, e) => s + e.sizeBytes);
    final label = _reciterLabel(reciterKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Reciter header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.person_fill,
                      color: Colors.deepPurple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entries.length} sourate${entries.length > 1 ? 's' : ''} · ${_formatSize(totalSize)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.trash,
                      size: 18, color: Colors.red[400]),
                  tooltip: 'Supprimer toutes',
                  onPressed: () => _confirmDeleteGroup(entries),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),

          // ── Surah list ─────────────────────────────────────────
          ...entries.asMap().entries.map((e) {
            final isLast = e.key == entries.length - 1;
            return _buildAudioTile(e.value, isLast: isLast, isDark: isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildAudioTile(_AudioEntry entry,
      {required bool isLast, required bool isDark}) {
    final name = surahFr[entry.surahId] ?? 'Sourate ${entry.surahId}';
    final numStr = entry.surahId.toString().padLeft(3, '0');

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              numStr,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
              ),
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            _formatSize(entry.sizeBytes),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          trailing: IconButton(
            icon: Icon(CupertinoIcons.trash, size: 18, color: Colors.red[300]),
            onPressed: () => _confirmDeleteSurah(entry),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
      ],
    );
  }

  void _confirmDeleteSurah(_AudioEntry entry) {
    final name = surahFr[entry.surahId] ?? 'Sourate ${entry.surahId}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer l\'audio de $name ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAudioEntry(entry);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(List<_AudioEntry> entries) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la récitation'),
        content: Text(
            'Supprimer les ${entries.length} sourate${entries.length > 1 ? 's' : ''} de ce récitateur ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final e in entries) {
                _deleteAudioEntry(e);
              }
            },
            child: const Text('Tout supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Tab : Stockage ───────────────────────────────────────────────────────────

  Widget _buildStorageTab() {
    return FutureBuilder<Map<String, List<_AudioEntry>>>(
      future: _audioFuture,
      builder: (context, audioSnap) {
        final audioGroups = audioSnap.data ?? {};
        final totalAudioBytes = audioGroups.values
            .expand((l) => l)
            .fold(0, (s, e) => s + e.sizeBytes);
        final totalAudioCount =
            audioGroups.values.fold(0, (s, l) => s + l.length);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildQuranPagesCard(),
            const SizedBox(height: 12),
            _buildStorageCard(
              'Pages du Coran',
              _quranReady
                  ? _formatSize(_quranCacheBytes)
                  : 'Non téléchargé',
              CupertinoIcons.doc_text,
              AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildStorageCard(
              'Audio téléchargé',
              totalAudioCount == 0
                  ? 'Aucun fichier'
                  : '$totalAudioCount sourate${totalAudioCount > 1 ? 's' : ''} · ${_formatSize(totalAudioBytes)}',
              CupertinoIcons.music_note_2,
              Colors.deepPurple,
            ),
          ],
        );
      },
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    int? count,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStorageCard(
      String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? Colors.white60 : Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIconForType(item.type),
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getTitleForItem(item),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(_getSubtitleForItem(item),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildActionButton(item),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: item.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(item.progress * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                Text(_getStatusText(item.status),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(DownloadItem item) {
    if (item.status == DownloadStatus.downloading) {
      return IconButton(
        icon: const Icon(CupertinoIcons.pause_circle),
        color: AppColors.accent,
        onPressed: () => _downloadService.pauseDownload(item.id),
      );
    } else if (item.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.play_circle),
            color: AppColors.primary,
            onPressed: () => _downloadService.resumeDownload(item.id),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle),
            color: Colors.red,
            onPressed: () => _downloadService.cancelDownload(item.id),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildQuranPagesCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool active = _quranDownloading || _quranExtracting;
    final double mb = _quranCacheBytes / (1024 * 1024);

    String status;
    if (_quranReady) {
      status = 'Téléchargé · ${mb.toStringAsFixed(1)} MB';
    } else if (_quranExtracting) {
      status = 'Extraction / installation…';
    } else if (_quranDownloading) {
      status = 'Téléchargement ${(100 * _quranProgress).toInt()}%';
    } else {
      status = 'Non téléchargé · ~80 MB';
    }

    return Container(
      decoration: _cardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.doc_text,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pages du Coran (Hafs + Warsh)',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(status,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _quranExtracting ? null : _quranProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!_quranReady && !active)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadQuranPages,
                  icon: const Icon(CupertinoIcons.cloud_download),
                  label: const Text('Télécharger'),
                ),
              ),
            if (_quranReady && !active)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearQuranPages,
                  icon: const Icon(CupertinoIcons.trash),
                  label: const Text('Supprimer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // ── String helpers ────────────────────────────────────────────────────────────

  IconData _getIconForType(DownloadType type) {
    switch (type) {
      case DownloadType.page:
        return CupertinoIcons.doc_text;
      case DownloadType.surah:
        return CupertinoIcons.book;
      case DownloadType.audio:
        return CupertinoIcons.music_note_2;
    }
  }

  String _getTitleForItem(DownloadItem item) {
    switch (item.type) {
      case DownloadType.page:
        return 'Page ${item.pageNumber ?? ''}';
      case DownloadType.surah:
        return surahFr[item.surahId] ?? 'Sourate ${item.surahId}';
      case DownloadType.audio:
        final name = surahFr[item.surahId] ?? 'Sourate ${item.surahId}';
        return 'Audio — $name';
    }
  }

  String _getSubtitleForItem(DownloadItem item) {
    switch (item.type) {
      case DownloadType.page:
        return 'Page du Coran';
      case DownloadType.surah:
        return 'Sourate complète';
      case DownloadType.audio:
        return item.reciterName ?? 'Audio';
    }
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Téléchargement…';
      case DownloadStatus.paused:
        return 'En pause';
      case DownloadStatus.completed:
        return 'Terminé';
      case DownloadStatus.error:
        return 'Échoué';
      default:
        return '';
    }
  }
}
