# QuranImageService - Documentation

## 📖 Vue d'ensemble

Service robuste pour gérer le téléchargement, l'extraction et l'affichage des pages du Coran sans bloquer l'interface utilisateur.

## ✨ Fonctionnalités principales

### 1. **Téléchargement non-bloquant**
- Télécharge le ZIP depuis GitHub Releases
- Progression en temps réel
- Timeout de 10 minutes pour les connexions lentes

### 2. **Extraction dans un Isolate**
- L'unzipping s'exécute dans un Isolate séparé via `compute()`
- **Aucun freeze de l'interface utilisateur**
- Traite ~1200 images sans ralentissement

### 3. **Pre-caching intelligent**
- Cache automatique des 3 pages suivantes
- Nettoyage des pages trop éloignées
- Utilise `precacheImage()` de Flutter

### 4. **Gestion des différentes lectures**
- Hafs (.png)
- Warsh (.jpg)
- Gestion automatique des extensions

## 🚀 Utilisation rapide

### 1. Utilisation basique

```dart
import 'package:quran/ui/screens/quran_reader_example_screen.dart';

// Dans votre navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const QuranReaderExampleScreen(
      reading: 'hafs',
      initialPage: 1,
    ),
  ),
);
```

### 2. Utilisation du widget directement

```dart
import 'package:quran/ui/widgets/quran_page_view.dart';

QuranPageView(
  reading: 'hafs',
  initialPage: 1,
  totalPages: 604,
  enablePrecaching: true,
  onPageChanged: (page) {
    print('Page actuelle: $page');
  },
)
```

### 3. Utilisation du service directement

```dart
import 'package:quran/services/quran_image_service.dart';

// Vérifier si les images sont téléchargées
bool isDownloaded = await QuranImageService.areImagesDownloaded();

// Télécharger si nécessaire
if (!isDownloaded) {
  await QuranImageService.downloadAndExtractImages(
    onDownloadProgress: (progress) {
      print('Téléchargement: ${(progress * 100).toInt()}%');
    },
  );
}

// Récupérer une page spécifique
File pageFile = await QuranImageService.getPageFile('hafs', 1);
```

## 📦 Architecture

```
lib/
├── services/
│   └── quran_image_service.dart    # Service principal
├── ui/
│   ├── widgets/
│   │   └── quran_page_view.dart     # Widget PageView avec pre-caching
│   └── screens/
│       └── quran_reader_example_screen.dart  # Exemple d'implémentation
```

## 🔧 API du Service

### `areImagesDownloaded()`
Vérifie si les images sont déjà téléchargées.

```dart
bool isReady = await QuranImageService.areImagesDownloaded();
```

### `getPageFile(String reading, int page)`
Récupère le fichier d'une page. Télécharge automatiquement si nécessaire.

```dart
File page1 = await QuranImageService.getPageFile('hafs', 1);
```

### `downloadAndExtractImages()`
Télécharge et extrait le ZIP complet avec callbacks de progression.

```dart
await QuranImageService.downloadAndExtractImages(
  onDownloadProgress: (progress) => print('Download: $progress'),
  onExtractionProgress: (progress) => print('Extract: $progress'),
);
```

### `clearCache()`
Supprime toutes les images téléchargées.

```dart
await QuranImageService.clearCache();
```

### `getCacheSize()`
Calcule la taille du cache en bytes.

```dart
int sizeBytes = await QuranImageService.getCacheSize();
double sizeMB = sizeBytes / (1024 * 1024);
```

## 🎯 Optimisations clés

### 1. Éviter le freeze de l'UI
```dart
// ❌ MAUVAIS - Bloque l'UI
final bytes = File(zipPath).readAsBytesSync();
final archive = ZipDecoder().decodeBytes(bytes);

// ✅ BON - S'exécute dans un Isolate
await compute(_extractZipTask, {'zipPath': zipPath});
```

### 2. Pre-caching intelligent
```dart
// Cache les 3 pages avant et après
for (int i = -3; i <= 3; i++) {
  final pageNum = currentPage + i;
  _loadPageIntoCache(pageNum);
}
```

### 3. Nettoyage automatique
```dart
// Supprime les pages à plus de 6 pages de distance
if ((pageNum - centerPage).abs() > 6) {
  _imageCache.remove(pageNum);
}
```

## 🔍 Dépannage

### Les images ne se chargent pas
1. Vérifiez votre connexion Internet
2. Vérifiez l'URL du ZIP
3. Videz le cache et re-téléchargez

### L'application freeze pendant l'extraction
- **Cause**: L'extraction ne s'exécute pas dans un Isolate
- **Solution**: Le service utilise déjà `compute()`, vérifiez que vous utilisez bien `QuranImageService`

### Consommation mémoire élevée
- Réduisez `_precacheRange` dans `QuranPageView`
- Le nettoyage automatique est déjà activé

## 📊 Performances

- **Téléchargement**: ~50-100 MB (dépend du ZIP)
- **Extraction**: ~30-60 secondes (dépend de l'appareil)
- **Mémoire**: ~50-100 MB pour 7 pages en cache
- **Défilement**: 60 FPS constant grâce au pre-caching

## 🛡️ Gestion des erreurs

Toutes les méthodes peuvent lancer des exceptions. Utilisez try-catch:

```dart
try {
  await QuranImageService.downloadAndExtractImages();
} catch (e) {
  print('Erreur: $e');
  // Afficher un message à l'utilisateur
}
```

## 📝 Notes importantes

1. **Premier lancement**: Le téléchargement prend quelques minutes
2. **Connexion requise**: Nécessite Internet pour le premier téléchargement
3. **Espace disque**: ~100 MB nécessaires
4. **Isolate**: L'extraction utilise un thread séparé automatiquement

## 🎨 Personnalisation

### Changer le nombre de pages pré-cachées

```dart
// Dans quran_page_view.dart
static const int _precacheRange = 5; // Au lieu de 3
```

### Ajouter une barre de progression

```dart
QuranImageService.downloadAndExtractImages(
  onDownloadProgress: (progress) {
    setState(() {
      _downloadProgress = progress;
    });
  },
);
```

## 🔗 Ressources

- **ZIP Source**: [GitHub Releases](https://github.com/sofian-ras/quran_project/releases/download/v1.0.0/quran_pages.zip)
- **Structure du ZIP**: 
  - `hafs/1.png` à `hafs/604.png`
  - `warsh/1.jpg` à `warsh/604.jpg`

## ⚡ Quick Start

1. Copiez les 3 fichiers dans votre projet
2. Importez `quran_reader_example_screen.dart`
3. Naviguez vers l'écran
4. C'est tout! 🎉

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const QuranReaderExampleScreen(),
  ),
);
```
