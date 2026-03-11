# 🚀 Rapport d'optimisation — Application Quran Flutter
**Analyse approfondie des performances — lib/ complète**

---

## Résumé exécutif

L'application souffre de **5 catégories majeures** de problèmes de performance qui causent les lags sur mobile. Les problèmes les plus critiques concernent les I/O disque répétitifs sur le thread principal, la persistance excessive lors d'opérations courantes, la gestion mémoire des images et la multiplication des instances Dio.

---

## 🔴 CRITIQUE — Impact maximum sur les lags

### 1. `AudioDownloadManager` — Écriture disque à chaque notification

**Fichier :** `services/qul_audio/audio_download_manager.dart`

**Problème :** La méthode `_notifyAndPersist()` est appelée **à chaque mise à jour de progression** du téléchargement. Elle déclenche une écriture dans `SharedPreferences` (qui est une I/O disque) de manière synchrone, **plusieurs fois par seconde** pendant un téléchargement actif.

```dart
// ❌ ACTUEL — appel sur CHAQUE tick de progression
onReceiveProgress: (received, total) {
  if (total > 0) {
    entry.progress = received / total;
    _notifyAndPersist(); // ← écriture disque à chaque tick !
  }
},
```

**Correction :**
```dart
// ✅ OPTIMISÉ — séparer notification UI et persistance
Timer? _persistDebounce;

void _notifyOnly() {
  entriesNotifier.value = Map.unmodifiable(_entries);
}

void _notifyAndPersist() {
  _notifyOnly();
  _persistDebounce?.cancel();
  _persistDebounce = Timer(const Duration(seconds: 2), _saveState);
}

// Dans le download :
onReceiveProgress: (received, total) {
  if (total > 0) {
    entry.progress = received / total;
    _notifyOnly(); // ← juste le notifier UI, pas de disque
  }
},
// Persister uniquement à la fin ou lors d'un changement de statut
```

---

### 2. `BookmarkService` — `SharedPreferences.getInstance()` à chaque appel

**Fichier :** `services/bookmark_service.dart`

**Problème :** Chaque méthode (`addBookmark`, `removeBookmark`, `isBookmarked`, `getBookmark`, `getBookmarks`...) appelle `SharedPreferences.getInstance()` individuellement. Or `getInstance()` est asynchrone et charge les préférences depuis le disque à chaque fois qu'aucune instance en cache n'existe au niveau du plugin. De plus, `getBookmarks()` désérialise le JSON **à chaque appel** sans cache mémoire.

```dart
// ❌ ACTUEL — désérialisation JSON à chaque appel, aucun cache
Future<bool> isBookmarked(int page) async {
  final bookmarks = await getBookmarks(); // lit le disque + désérialise
  return bookmarks.any((b) => b.page == page);
}
```

**Correction :**
```dart
// ✅ OPTIMISÉ — cache mémoire + SharedPreferences singleton
class BookmarkService {
  static SharedPreferences? _prefs;
  List<Bookmark>? _cache;

  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<Bookmark>> getBookmarks() async {
    if (_cache != null) return _cache!;
    final prefs = await _sharedPrefs;
    final jsonStr = prefs.getString(_bookmarksKey);
    _cache = jsonStr == null ? [] : _parseBookmarks(jsonStr);
    return _cache!;
  }

  Future<void> _saveBookmarks(List<Bookmark> bookmarks) async {
    _cache = bookmarks; // màj cache avant disque
    final prefs = await _sharedPrefs;
    await prefs.setString(_bookmarksKey, json.encode(bookmarks.map((b) => b.toJson()).toList()));
  }
}
```

**Ce pattern s'applique également à :** `VerseFavoritesService`, `VerseNotesService`, `LastReadingService`, `ReadingHistoryService`

---

### 3. `QuranTextDb.getRange()` — Boucle de requêtes SQL individuelles

**Fichier :** `services/quran_text_db.dart`

**Problème :** La méthode `getRange()` exécute N requêtes SQL en boucle (une par verset), ce qui est extrêmement coûteux pour de grandes plages.

```dart
// ❌ ACTUEL — N requêtes SQL pour N versets
Future<List<QVerse>> getRange(int surah, int fromAyah, int toAyah) async {
  final out = <QVerse>[];
  for (int ayah = fromAyah; ayah <= toAyah; ayah++) {
    final v = await getVerseByKey('$surah:$ayah'); // 1 requête par verset !
    if (v != null) out.add(v);
  }
  return out;
}
```

**Correction :**
```dart
// ✅ OPTIMISÉ — 1 seule requête SQL avec WHERE ayah BETWEEN
Future<List<QVerse>> getRange(int surah, int fromAyah, int toAyah) async {
  // Générer les clés et utiliser getVersesByKeys (déjà optimisé avec IN clause)
  final keys = [for (int a = fromAyah; a <= toAyah; a++) '$surah:$a'];
  final map = await getVersesByKeys(keys);
  return keys
      .map((k) => map[k])
      .whereType<QVerse>()
      .toList();
}
```

---

### 4. `QuranPagePreloader` — `precacheImage` sur des fichiers locaux inutilement

**Fichier :** `services/quran_page_preloader.dart`

**Problème :** Le preloader précharge les pages adjacentes en appelant `precacheImage()` + `FileImage()`. Or Flutter gère déjà un cache d'images via `PaintingBinding.instance.imageCache`. Si le cache est plein (200 images × max 150 MB configuré dans `main.dart`), chaque page chassée du cache sera rechargée depuis le disque lors du swipe suivant, causant un jank visible.

Le vrai problème est que le cache est configuré pour **200 images** — une page Hafs 1024px fait ~500KB-1MB, donc 200 images × ~700KB ≈ **140MB de RAM**. Sur les téléphones bas de gamme (2-3GB), cela pompe une part énorme de la mémoire disponible.

**Correction :**

```dart
// main.dart — réduire le cache images selon la RAM disponible
// ❌ ACTUEL — trop agressif
PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024;
PaintingBinding.instance.imageCache.maximumSize = 200;

// ✅ OPTIMISÉ — adaptatif et raisonnable
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB max
PaintingBinding.instance.imageCache.maximumSize = 60; // 60 images max
```

```dart
// quran_page_preloader.dart — précharger moins de pages
// ❌ ACTUEL — range=2 par défaut = 4 pages en mémoire en plus
QuranPagePreloader({this.range = 2});

// ✅ OPTIMISÉ — range=1 suffit pour un scroll fluide
QuranPagePreloader({this.range = 1});
```

---

### 5. `AudioDownloadService.getDownloadedSurahs()` — 114 opérations I/O disque en série

**Fichier :** `services/audio_download_service.dart`

**Problème :** Cette méthode effectue 114 vérifications `File.exists()` **en série**, une par sourate. Sur mobile, chaque I/O prend ~1-5ms, soit **114-570ms** de blocage.

```dart
// ❌ ACTUEL — 114 I/O disque en série
Future<List<int>> getDownloadedSurahs() async {
  final List<int> downloaded = [];
  for (int i = 1; i <= 114; i++) {
    if (await isDownloaded(i)) { // I/O disque x114
      downloaded.add(i);
    }
  }
  return downloaded;
}
```

**Correction :**
```dart
// ✅ OPTIMISÉ — toutes les vérifications en parallèle
Future<List<int>> getDownloadedSurahs() async {
  final results = await Future.wait(
    List.generate(114, (i) async {
      final downloaded = await isDownloaded(i + 1);
      return downloaded ? i + 1 : 0;
    }),
  );
  return results.where((id) => id > 0).toList();
}
```

**Ce même pattern s'applique à `getTotalDownloadedSize()`.**

---

## 🟠 IMPORTANT — Impact significatif

### 6. Multiplication des instances `Dio`

**Problème :** Chaque service crée sa propre instance `Dio` séparée, ce qui multiplie les pools de connexions HTTP, les intercepteurs et la consommation mémoire.

Instances identifiées :
- `AudioDownloadService._dio`
- `AudioDownloadManager._dio`
- `DownloadService._dio`
- `Mp3QuranApi._dio`
- `QulApiClient._dio`
- `QuraanicAudioService._dio`
- `QuranTranslationPackService._dio` (static)
- `QuranTextPackService._dio`
- `QuranImageService._dio` (static)

**Correction :** Créer un `DioSingleton` partagé :

```dart
// lib/services/http_client.dart
class AppHttpClient {
  AppHttpClient._();
  static final Dio instance = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Dio spécialisé pour les gros téléchargements
  static final Dio download = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));
}
```

---

### 7. `MiniPlayerService._prepareAndPlay()` — Téléchargement complet avant lecture

**Fichier :** `services/mini_player_service.dart`

**Problème :** En mode `surah` ou `selection`, le service télécharge **tous** les versets d'une sourate avant de commencer la lecture. Al-Baqara compte 286 versets → l'utilisateur attend la fin du téléchargement complet avant d'entendre le premier verset.

**Correction :**
```dart
// ✅ OPTIMISÉ — démarrer la lecture dès les premiers versets téléchargés
Future<void> _prepareAndPlay(QulReciter reciter, int surah, int startAyah) async {
  // Télécharger d'abord les 5 premiers versets pour démarrer rapidement
  const prerollSize = 5;
  final preroll = List.generate(
    prerollSize.clamp(0, kSurahAyahCounts[surah - 1] - startAyah + 1),
    (i) => startAyah + i,
  );
  
  await Future.wait(preroll.map((ayah) async {
    final url = await QulAudioResolver.instance.resolveAyah(reciter, surah, ayah);
    if (url != null) await mgr.downloadAyah(quranComId: qid, surah: surah, ayah: ayah, url: url);
  }));
  
  // Démarrer la lecture immédiatement
  await _startPlaylistMode(reciter, surah, startAyah);
  
  // Continuer le téléchargement en arrière-plan
  _downloadRemainingInBackground(reciter, surah, startAyah + prerollSize);
}
```

---

### 8. `TafsirService.getSurah()` — Ouverture/fermeture SQLite à chaque appel

**Fichier :** `services/tafsir_service.dart`

**Problème :** Chaque appel à `getSurah()` ouvre la base SQLite, lit les données, puis **ferme immédiatement** la connexion. Sur mobile, l'ouverture d'une base SQLite prend 20-100ms. Si l'UI appelle cette méthode à chaque rebuild (par exemple lors du scroll), c'est catastrophique.

```dart
// ❌ ACTUEL — ouvre ET ferme à chaque lecture
static Future<List<TafsirVerse>> getSurah(TafsirBook book, int surah) async {
  final path = await _dbPath(book);
  final db = await openDatabase(path, readOnly: true); // coûteux !
  try {
    // ... lecture
  } finally {
    await db.close(); // ← fermeture inutile
  }
}
```

**Correction :**
```dart
// ✅ OPTIMISÉ — pool de connexions persistantes + cache de sourate
class TafsirService {
  static final Map<String, Database> _openDbs = {};
  static final Map<String, List<TafsirVerse>> _surahCache = {};

  static Future<Database> _getDb(TafsirBook book) async {
    final path = await _dbPath(book);
    return _openDbs[book.slug] ??= await openDatabase(path, readOnly: true);
  }

  static Future<List<TafsirVerse>> getSurah(TafsirBook book, int surah) async {
    final cacheKey = '${book.slug}:$surah';
    if (_surahCache.containsKey(cacheKey)) return _surahCache[cacheKey]!;
    
    final db = await _getDb(book);
    final rows = await db.query('verses', where: 'surah = ?', whereArgs: [surah], orderBy: 'ayah ASC');
    final result = rows.map((r) => TafsirVerse(...)).toList();
    _surahCache[cacheKey] = result;
    return result;
  }
}
```

---

### 9. `print()` en production dans plusieurs services

**Fichier :** `services/mp3quran_api.dart`, `services/quranic_audio_service.dart`, `services/quran_image_service.dart`

**Problème :** L'utilisation de `print()` (au lieu de `debugPrint()`) effectue une écriture synchrone sur stdout, ce qui **bloque le thread principal** brièvement. En production, ces logs doivent être désactivés.

```dart
// ❌ ACTUEL — bloque le thread principal
print('Mp3QuranApi: Erreur...: $e');
print('❌ Erreur lors de la récupération...');
```

**Correction :**
```dart
// ✅ OPTIMISÉ
import 'package:flutter/foundation.dart';
debugPrint('...'); // limité à 1024 chars, géré par Flutter, no-op en release
```

---

### 10. `QuranPagesHitboxDb` — Requête SQL non indexée pour le tap detection

**Fichier :** `services/quran_pages_hitbox_db.dart`

**Problème :** La méthode `getAyahAt()` utilise une requête SQL avec des calculs de distance (`MAX(minx - ?, 0.0)`) sur toutes les lignes de la page. Si la table `ayarects` n'a pas d'index sur `page`, cela déclenche un **full table scan** à chaque tap de l'utilisateur.

**Correction :**
```sql
-- Vérifier et ajouter l'index si absent (dans ensureFromAsset ou à l'ouverture)
CREATE INDEX IF NOT EXISTS idx_ayarects_page ON ayarects(page);
```

```dart
Future<void> _open() async {
  if (_db != null) return;
  final path = await _resolveDbPath();
  _db = await openDatabase(path, readOnly: true);
  // Créer l'index en lecture seule n'est pas possible, vérifier à la création
}
```

---

## 🟡 MODÉRÉ — Améliorations de qualité

### 11. `DailyVerseService` — SharedPreferences appelé deux fois pour rien

**Fichier :** `services/daily_verse_service.dart`

**Problème :** La méthode `getDailyVerse()` appelle `SharedPreferences.getInstance()` puis lit `_lastDateKey`. Si c'est un nouveau jour, elle appelle `_saveDailyVerse()` qui rappelle `SharedPreferences.getInstance()` une deuxième fois.

**Correction :** Passer l'instance `prefs` en paramètre à `_saveDailyVerse()`.

---

### 12. `AppUsageService.onPause()` — SharedPreferences sans debounce

**Fichier :** `services/app_usage_service.dart`

**Problème :** `onPause()` est appelé à chaque fois que l'app passe en arrière-plan. Si l'utilisateur alterne rapidement entre apps, cela génère plusieurs écritures disque.

**Correction :**
```dart
static Timer? _saveDebounce;

static Future<void> onPause() async {
  if (_sessionStart == 0) return;
  final elapsed = (DateTime.now().millisecondsSinceEpoch - _sessionStart) ~/ 1000;
  _baseSeconds += elapsed;
  _sessionStart = 0;
  
  _saveDebounce?.cancel();
  _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTotalSeconds, _baseSeconds);
  });
}
```

---

### 13. `RecitersRepository` — Désérialisation JSON sur le thread principal

**Fichier :** `services/reciters_repository.dart`

**Problème :** Le JSON des récitateurs (`reciters_full.json`) est parsé **directement sur le thread principal** via `json.decode()`. Si ce fichier est volumineux, cela peut geler l'UI.

**Correction :**
```dart
Future<List<Reciter>> loadReciters() async {
  if (_cache != null) return _cache!;
  final jsonStr = await rootBundle.loadString('assets/data/reciters_full.json');
  // Déplacer le parsing dans un isolate
  final list = await compute(_parseReciters, jsonStr);
  _cache = list;
  return list;
}

static List<Reciter> _parseReciters(String jsonStr) {
  final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
  return data.map((e) => Reciter.fromJson(e as Map<String, dynamic>)).toList();
}
```

---

### 14. `DownloadService._notifyListeners()` — BehaviorSubject mis à jour trop fréquemment

**Fichier :** `services/download_service.dart`

**Problème :** `_notifyListeners()` est appelé à chaque tick de progression de téléchargement, ce qui fait émettre le `BehaviorSubject` (et re-render l'UI) des dizaines de fois par seconde.

**Correction :** Throttle les émissions à maximum 10 fois par seconde :

```dart
DateTime? _lastNotify;

void _notifyListeners() {
  final now = DateTime.now();
  if (_lastNotify == null || now.difference(_lastNotify!) > const Duration(milliseconds: 100)) {
    _downloadsSubject.add(_downloads.values.toList());
    _lastNotify = now;
  }
}
```

---

### 15. `main.dart` — `GlobalMiniPlayerOverlay` dans l'Overlay sur chaque rebuild

**Fichier :** `lib/main.dart`

**Problème :** Le `builder` de `MaterialApp` crée un nouvel `Overlay` avec un `OverlayEntry` **à chaque rebuild du `ValueListenableBuilder<ThemeMode>`**. Chaque changement de thème recrée tout l'overlay.

```dart
// ❌ ACTUEL — Overlay recréé à chaque changement de thème
builder: (context, child) {
  return Overlay(
    initialEntries: [
      OverlayEntry(builder: (context) => ...),
    ],
  );
},
```

**Correction :**
```dart
// ✅ OPTIMISÉ — Overlay statique, ne se rebuild pas
// Extraire dans un widget const séparé ou utiliser un OverlayPortal
builder: (context, child) {
  return Stack(
    children: [
      if (child != null) child,
      const GlobalMiniPlayerOverlay(),
    ],
  );
},
```

---

## 📋 Tableau récapitulatif des priorités

| # | Problème | Fichier | Impact | Effort |
|---|----------|---------|--------|--------|
| 1 | Écriture disque à chaque tick téléchargement | `audio_download_manager.dart` | 🔴 Critique | Faible |
| 2 | Pas de cache mémoire pour les bookmarks | `bookmark_service.dart` | 🔴 Critique | Faible |
| 3 | `getRange()` : N requêtes SQL en boucle | `quran_text_db.dart` | 🔴 Critique | Faible |
| 4 | Cache images trop agressif (140MB) | `main.dart` | 🔴 Critique | Très faible |
| 5 | 114 I/O disque en série | `audio_download_service.dart` | 🔴 Critique | Faible |
| 6 | 9 instances Dio séparées | Tous les services | 🟠 Important | Moyen |
| 7 | Attente téléchargement complet avant lecture | `mini_player_service.dart` | 🟠 Important | Moyen |
| 8 | SQLite ouvert/fermé à chaque appel | `tafsir_service.dart` | 🟠 Important | Faible |
| 9 | `print()` en production | Multiple | 🟠 Important | Très faible |
| 10 | Index manquant sur `ayarects(page)` | `quran_pages_hitbox_db.dart` | 🟠 Important | Très faible |
| 11 | SharedPreferences appelé 2× | `daily_verse_service.dart` | 🟡 Modéré | Très faible |
| 12 | onPause sans debounce | `app_usage_service.dart` | 🟡 Modéré | Très faible |
| 13 | JSON parsé sur le thread principal | `reciters_repository.dart` | 🟡 Modéré | Faible |
| 14 | BehaviorSubject trop fréquent | `download_service.dart` | 🟡 Modéré | Très faible |
| 15 | Overlay recréé au changement de thème | `main.dart` | 🟡 Modéré | Faible |

---

## 🎯 Plan d'action recommandé

### Phase 1 — Quick wins (1-2 jours)
Implémenter les corrections #4, #9, #10, #11, #12, #14 → gains immédiats sans refactoring majeur.

### Phase 2 — Optimisations core (3-5 jours)
Implémenter #1, #2, #3, #5, #8 → éliminent la majorité des lags observables.

### Phase 3 — Architecture (1-2 semaines)
Implémenter #6, #7, #13, #15 → amélioration structurelle à long terme.

---

*Rapport généré le 11 mars 2026 — Analyse statique du code source Flutter*
