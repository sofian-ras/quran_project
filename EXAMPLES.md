// ========================================
// EXEMPLE MINIMAL D'UTILISATION
// ========================================
// Copiez-collez ce code dans votre app pour tester rapidement

import 'package:flutter/material.dart';
import 'package:quran/ui/screens/quran_reader_example_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Reader',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Lecteur du Coran',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            
            // Bouton pour lecture Hafs
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuranReaderExampleScreen(
                      reading: 'hafs',
                      initialPage: 1,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Lire (Hafs)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton pour lecture Warsh
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuranReaderExampleScreen(
                      reading: 'warsh',
                      initialPage: 1,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Lire (Warsh)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// EXEMPLE AVEC CUSTOM WIDGET
// ========================================

import 'package:flutter/material.dart';
import 'package:quran/ui/widgets/quran_page_view.dart';

class CustomReaderScreen extends StatefulWidget {
  const CustomReaderScreen({super.key});

  @override
  State<CustomReaderScreen> createState() => _CustomReaderScreenState();
}

class _CustomReaderScreenState extends State<CustomReaderScreen> {
  int currentPage = 1;
  String reading = 'hafs';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page $currentPage'),
        actions: [
          // Sélecteur de lecture
          PopupMenuButton<String>(
            initialValue: reading,
            onSelected: (value) {
              setState(() => reading = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'hafs', child: Text('Hafs')),
              const PopupMenuItem(value: 'warsh', child: Text('Warsh')),
            ],
          ),
        ],
      ),
      body: QuranPageView(
        reading: reading,
        initialPage: currentPage,
        totalPages: 604,
        enablePrecaching: true,
        onPageChanged: (page) {
          setState(() => currentPage = page);
        },
      ),
    );
  }
}

// ========================================
// EXEMPLE AVEC SERVICE DIRECTEMENT
// ========================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quran/services/quran_image_service.dart';

class ManualServiceExample extends StatefulWidget {
  const ManualServiceExample({super.key});

  @override
  State<ManualServiceExample> createState() => _ManualServiceExampleState();
}

class _ManualServiceExampleState extends State<ManualServiceExample> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  File? currentImage;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    _initImages();
  }

  Future<void> _initImages() async {
    // Vérifier si les images sont téléchargées
    final isReady = await QuranImageService.areImagesDownloaded();

    if (!isReady) {
      // Télécharger
      setState(() => isDownloading = true);
      
      await QuranImageService.downloadAndExtractImages(
        onDownloadProgress: (progress) {
          setState(() => downloadProgress = progress);
        },
      );
      
      setState(() => isDownloading = false);
    }

    // Charger la première page
    await _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    final file = await QuranImageService.getPageFile('hafs', page);
    setState(() {
      currentImage = file;
      currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: downloadProgress),
              const SizedBox(height: 16),
              Text('${(downloadProgress * 100).toInt()}%'),
              const Text('Téléchargement...'),
            ],
          ),
        ),
      );
    }

    if (currentImage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Page $currentPage')),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Image.file(currentImage!),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: currentPage > 1
                    ? () => _loadPage(currentPage - 1)
                    : null,
              ),
              Text('$currentPage / 604'),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: currentPage < 604
                    ? () => _loadPage(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================
// EXEMPLE AVEC GESTION DU CACHE
// ========================================

import 'package:flutter/material.dart';
import 'package:quran/services/quran_image_service.dart';

class CacheManagementExample extends StatefulWidget {
  const CacheManagementExample({super.key});

  @override
  State<CacheManagementExample> createState() => _CacheManagementExampleState();
}

class _CacheManagementExampleState extends State<CacheManagementExample> {
  String cacheInfo = 'Chargement...';

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    final isDownloaded = await QuranImageService.areImagesDownloaded();
    final size = await QuranImageService.getCacheSize();
    final sizeMB = (size / (1024 * 1024)).toStringAsFixed(1);

    setState(() {
      cacheInfo = isDownloaded
          ? 'Images téléchargées: $sizeMB MB'
          : 'Images non téléchargées';
    });
  }

  Future<void> _clearCache() async {
    await QuranImageService.clearCache();
    _loadCacheInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache vidé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion du cache')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(cacheInfo, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.delete),
              label: const Text('Vider le cache'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCacheInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Rafraîchir'),
            ),
          ],
        ),
      ),
    );
  }
}
