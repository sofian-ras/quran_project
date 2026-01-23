import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../surah_name.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
            Tab(text: 'Terminés'),
            Tab(text: 'Stockage'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInProgressTab(),
          _buildCompletedTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }

  Widget _buildInProgressTab() {
    return StreamBuilder<List<DownloadItem>>(
      stream: _downloadService.downloadsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: CupertinoIcons.arrow_down_circle,
            title: 'Aucun téléchargement en cours',
            subtitle: 'Téléchargez des pages ou des sourates\npour les lire hors ligne',
          );
        }

        final downloads = snapshot.data!;
        final inProgress = downloads.where((d) => 
          d.status == DownloadStatus.downloading || 
          d.status == DownloadStatus.paused
        ).toList();

        if (inProgress.isEmpty) {
          return _buildEmptyState(
            icon: CupertinoIcons.checkmark_circle,
            title: 'Tous les téléchargements terminés',
            subtitle: 'Consultez l\'onglet "Terminés"',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inProgress.length,
          itemBuilder: (context, index) {
            return _buildDownloadCard(inProgress[index]);
          },
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    return StreamBuilder<List<DownloadItem>>(
      stream: _downloadService.downloadsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: CupertinoIcons.arrow_down_circle,
            title: 'Aucun téléchargement terminé',
            subtitle: 'Les téléchargements complétés\napparaîtront ici',
          );
        }

        final completed = snapshot.data!
          .where((d) => d.status == DownloadStatus.completed)
          .toList();

        if (completed.isEmpty) {
          return _buildEmptyState(
            icon: CupertinoIcons.arrow_down_circle,
            title: 'Aucun téléchargement terminé',
            subtitle: 'Les téléchargements complétés\napparaîtront ici',
          );
        }

        // Grouper par type
        final pages = completed.where((d) => d.type == DownloadType.page).toList();
        final surahs = completed.where((d) => d.type == DownloadType.surah).toList();
        final audios = completed.where((d) => d.type == DownloadType.audio).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pages.isNotEmpty) ...[
              _buildSectionHeader('Pages du Coran', pages.length),
              const SizedBox(height: 8),
              ...pages.map((d) => _buildCompletedCard(d)),
              const SizedBox(height: 24),
            ],
            if (surahs.isNotEmpty) ...[
              _buildSectionHeader('Sourates complètes', surahs.length),
              const SizedBox(height: 8),
              ...surahs.map((d) => _buildCompletedCard(d)),
              const SizedBox(height: 24),
            ],
            if (audios.isNotEmpty) ...[
              _buildSectionHeader('Audio', audios.length),
              const SizedBox(height: 8),
              ...audios.map((d) => _buildCompletedCard(d)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStorageTab() {
    return StreamBuilder<List<DownloadItem>>(
      stream: _downloadService.downloadsStream,
      builder: (context, snapshot) {
        final downloads = snapshot.data ?? [];
        final completed = downloads.where((d) => d.status == DownloadStatus.completed).toList();

        // Calculer la taille totale (estimation)
        final pageCount = completed.where((d) => d.type == DownloadType.page).length;
        final surahCount = completed.where((d) => d.type == DownloadType.surah).length;
        final audioCount = completed.where((d) => d.type == DownloadType.audio).length;

        final totalMB = (pageCount * 0.5) + (surahCount * 2) + (audioCount * 3);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStorageCard(
              'Espace utilisé',
              '${totalMB.toStringAsFixed(1)} MB',
              CupertinoIcons.device_phone_portrait,
              AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildStorageCard(
              'Pages téléchargées',
              '$pageCount pages',
              CupertinoIcons.doc_text,
              AppColors.accent,
            ),
            const SizedBox(height: 12),
            _buildStorageCard(
              'Sourates complètes',
              '$surahCount sourates',
              CupertinoIcons.book,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStorageCard(
              'Fichiers audio',
              '$audioCount fichiers',
              CupertinoIcons.music_note_2,
              Colors.purple,
            ),
            const SizedBox(height: 24),
            if (completed.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _showClearDialog(),
                icon: const Icon(CupertinoIcons.trash),
                label: const Text('Tout supprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadCard(DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(item.type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitleForItem(item),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubtitleForItem(item),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(item.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _getStatusText(item.status),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getIconForType(item.type),
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          _getTitleForItem(item),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _getSubtitleForItem(item),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(CupertinoIcons.trash, size: 20),
          color: Colors.red,
          onPressed: () => _deleteItem(item),
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

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

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
        final surahName = surahFr[item.surahId] ?? 'Sourate ${item.surahId}';
        return surahName;
      case DownloadType.audio:
        final surahName = surahFr[item.surahId] ?? 'Sourate ${item.surahId}';
        return 'Audio - $surahName';
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
        return 'Téléchargement...';
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

  void _deleteItem(DownloadItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer ce téléchargement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              _downloadService.cancelDownload(item.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout supprimer'),
        content: const Text(
          'Voulez-vous vraiment supprimer tous les téléchargements ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implémenter la suppression globale
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tous les téléchargements ont été supprimés'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Tout supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
