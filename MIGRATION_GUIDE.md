# 🔄 Guide d'intégration du nouveau QuranImageService

## Objectif
Remplacer le système actuel de chargement d'images par le nouveau service robuste avec Isolate.

## ⚠️ Problèmes résolus

### Avant (AssetManager actuel)
- ❌ Unzipping bloque l'UI thread
- ❌ Pas de pre-caching intelligent
- ❌ Code dupliqué entre AssetManager et ReaderScreen

### Après (QuranImageService)
- ✅ Unzipping dans un Isolate (pas de freeze)
- ✅ Pre-caching automatique des 3 pages suivantes
- ✅ Code propre et séparé en services/widgets

---

## 🎯 Option 1: Remplacer complètement (Recommandé)

### Étape 1: Remplacer les imports dans reader_screen.dart

**AVANT:**
```dart
import '../asset_manager.dart';
```

**APRÈS:**
```dart
import '../services/quran_image_service.dart';
import 'widgets/quran_page_view.dart';
```

### Étape 2: Simplifier ReaderScreen

Remplacez tout le code de gestion d'images par:

```dart
class _ReaderScreenState extends State<ReaderScreen> {
  late int currentPage;
  String currentReading = 'hafs';
  bool _showUI = true;
  List<Map<String, dynamic>> fullSurahList = [];

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    currentReading = widget.reading;
    _initApp();
  }

  Future<void> _initApp() async {
    // Charger uniquement les données JSON (pas les images)
    final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
    final quranData = json.decode(jsonStr) as List<dynamic>;
    
    // Créer la liste des sourates
    final added = <int>{};
    final List<Map<String, dynamic>> list = [];
    for (final v in quranData) {
      final id = v['surah'] as int;
      if (!added.contains(id)) {
        list.add({
          'id': id,
          'name': SurahName.getName(id),
        });
        added.add(id);
      }
    }
    
    setState(() {
      fullSurahList = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Utiliser le nouveau QuranPageView
            GestureDetector(
              onTap: () {
                setState(() {
                  _showUI = !_showUI;
                });
              },
              child: QuranPageView(
                reading: currentReading,
                initialPage: currentPage,
                totalPages: 604,
                enablePrecaching: true,
                onPageChanged: (page) {
                  setState(() {
                    currentPage = page;
                  });
                  // Sauvegarder l'historique
                  ReadingHistoryService.addHistory(page, currentReading);
                },
              ),
            ),

            // Votre UI existante (AppBar, Bottom bar, etc.)
            if (_showUI) _buildTopBar(),
            if (_showUI) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // Gardez vos méthodes _buildTopBar() et _buildBottomBar() existantes
}
```

---

## 🎯 Option 2: Intégration progressive (Migration douce)

Si vous voulez tester d'abord sans tout casser:

### Étape 1: Garder AssetManager, ajouter le nouveau service

```dart
// Au début de reader_screen.dart
import '../asset_manager.dart'; // Ancien
import '../services/quran_image_service.dart'; // Nouveau
```

### Étape 2: Ajouter un bouton pour tester

```dart
// Dans vos actions AppBar
IconButton(
  icon: const Icon(Icons.new_releases),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuranReaderExampleScreen(
          reading: currentReading,
          initialPage: currentPage,
        ),
      ),
    );
  },
)
```

### Étape 3: Tester et comparer

1. Utilisez l'ancien code normalement
2. Cliquez sur le nouveau bouton pour tester le nouveau service
3. Comparez les performances
4. Quand satisfait, passez à l'Option 1

---

## 🔧 Modifications spécifiques

### 1. Remplacer le système de cache d'images

**AVANT (dans reader_screen.dart):**
```dart
final Map<int, File> _imageCache = {};
final Set<int> _loadingPages = {};
static const int _preloadRange = 2;

Future<void> _loadPageIntoCache(int pageNum) async {
  // Votre code existant...
}

void _cleanDistantPages(int centerPage) {
  // Votre code existant...
}
```

**APRÈS:**
```dart
// Rien! Tout est géré par QuranPageView automatiquement
```

### 2. Remplacer la méthode _initApp()

**AVANT:**
```dart
Future<void> _initApp() async {
  // Télécharger et extraire le ZIP
  final assetsDownloaded = await AssetManager.areAssetsDownloaded();
  if (!assetsDownloaded) {
    await AssetManager._downloadAndExtractZipIfNeeded();
  }
  
  // Charger les données JSON
  final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
  // ...
}
```

**APRÈS:**
```dart
Future<void> _initApp() async {
  // Charger uniquement les données JSON
  // Le téléchargement des images est géré par QuranPageView
  final jsonStr = await rootBundle.loadString('assets/data/quran_data.json');
  // ...
}
```

### 3. Remplacer le FutureBuilder dans PageView

**AVANT:**
```dart
return PageView.builder(
  controller: _pageController,
  itemBuilder: (context, index) {
    final pageNum = index + 1;
    
    if (_imageCache.containsKey(pageNum)) {
      return _buildPageContent(_imageCache[pageNum]!);
    }
    
    return FutureBuilder<File>(
      future: AssetManager.getPageFile(currentReading, pageNum),
      builder: (context, snapshot) {
        // Code compliqué...
      },
    );
  },
);
```

**APRÈS:**
```dart
QuranPageView(
  reading: currentReading,
  initialPage: currentPage,
  totalPages: 604,
  onPageChanged: (page) {
    setState(() {
      currentPage = page;
    });
  },
)
```

---

## 📋 Checklist de migration

- [ ] Créer `lib/services/quran_image_service.dart`
- [ ] Créer `lib/ui/widgets/quran_page_view.dart`
- [ ] Créer `lib/ui/screens/quran_reader_example_screen.dart` (test)
- [ ] Tester le nouvel écran séparément
- [ ] Vérifier que le téléchargement fonctionne
- [ ] Vérifier que le pre-caching fonctionne
- [ ] Modifier `reader_screen.dart` pour utiliser `QuranPageView`
- [ ] Supprimer l'ancien code de cache (_imageCache, etc.)
- [ ] Tester le changement de lecture (hafs/warsh)
- [ ] Tester la navigation entre pages
- [ ] (Optionnel) Supprimer `asset_manager.dart` si plus utilisé ailleurs

---

## 🚨 Points d'attention

### 1. Extensions de fichiers
Le nouveau service gère automatiquement:
- Hafs = `.png`
- Warsh = `.jpg`

Pas besoin de logique conditionnelle.

### 2. Compatibilité avec l'historique
Le callback `onPageChanged` est compatible avec votre `ReadingHistoryService`:

```dart
onPageChanged: (page) {
  ReadingHistoryService.addHistory(page, currentReading);
}
```

### 3. Signets (Bookmarks)
Fonctionne exactement pareil, changez juste:

```dart
// Ancien
await AssetManager.getPageFile(reading, page);

// Nouveau
await QuranImageService.getPageFile(reading, page);
```

---

## 🎨 Bonus: Ajouter une barre de progression

Si vous voulez afficher la progression du téléchargement:

```dart
class _ReaderScreenState extends State<ReaderScreen> {
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  Future<void> _checkAndDownload() async {
    final isDownloaded = await QuranImageService.areImagesDownloaded();
    
    if (!isDownloaded) {
      setState(() => _isDownloading = true);
      
      await QuranImageService.downloadAndExtractImages(
        onDownloadProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );
      
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: _downloadProgress),
              SizedBox(height: 16),
              Text('${(_downloadProgress * 100).toInt()}%'),
              Text('Téléchargement des pages...'),
            ],
          ),
        ),
      );
    }
    
    return /* Votre UI normale */;
  }
}
```

---

## 📞 Support

Si vous rencontrez des problèmes:

1. **Vérifiez les logs**: Les méthodes utilisent `debugPrint()`
2. **Testez l'URL**: Ouvrez l'URL du ZIP dans un navigateur
3. **Videz le cache**: `await QuranImageService.clearCache()`
4. **Re-téléchargez**: Les images seront re-téléchargées automatiquement

---

## ✅ Avantages de la migration

1. **Performance**: Pas de freeze pendant l'extraction
2. **Mémoire**: Pre-caching intelligent (seulement 7 pages en mémoire)
3. **Maintenabilité**: Code propre et séparé
4. **Évolutivité**: Facile d'ajouter d'autres lectures (Qaloon, etc.)
5. **Debugging**: Logs clairs et détaillés
