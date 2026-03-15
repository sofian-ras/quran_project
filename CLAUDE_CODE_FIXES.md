# Instructions de correction — ReaderScreen & services liés

Tu vas appliquer une série de corrections ciblées sur un projet Flutter (application Coran).
Lis chaque section dans l'ordre. Ne modifie aucun autre fichier que ceux mentionnés.
Pour chaque modification, applique-la puis passe à la suivante sans demander confirmation.

---

## FICHIER 1 : `lib/services/quran_pages_hitbox_db.dart`

### Correction C4 — Ajouter la méthode `getPageForAyah()`

Dans la classe `QuranPagesHitboxDb`, ajoute la méthode suivante juste après `getAyahRects()` :

```dart
/// Retourne le numéro de page d'un verset donné, ou null s'il n'existe pas.
Future<int?> getPageForAyah(int surah, int ayah) async {
  await _open();
  final rows = await _db!.rawQuery(
    'SELECT page FROM ayarects WHERE soraid = ? AND ayaid = ? LIMIT 1',
    [surah, ayah],
  );
  if (rows.isEmpty) return null;
  return rows.first['page'] as int?;
}
```

---

## FICHIER 2 : `lib/ui/screens/reader_screen.dart`

### Correction m4 — Supprimer l'import `dart:ui` inutile

Remplace :
```dart
import 'dart:ui';
```
Par : rien (supprime la ligne). `ImageFilter` et `BackdropFilter` sont déjà accessibles via `flutter/material.dart`.

> Si après suppression le projet ne compile pas à cause de `ImageFilter`, remets l'import. Sinon laisse-le supprimé.

---

### Correction m1 — Supprimer `GradientText` (dead code)

Supprime entièrement la classe `GradientText` définie en haut du fichier (de `class GradientText extends StatelessWidget` jusqu'à sa `}` fermante).

---

### Correction C2 — Supprimer l'import `last_reading_service.dart`

Supprime la ligne :
```dart
import '../services/last_reading_service.dart';
```

---

### Correction M1 — Clamper `currentPage` à l'initialisation

Dans `initState`, remplace :
```dart
currentPage = widget.initialPage;
```
Par :
```dart
currentPage = widget.initialPage.clamp(1, 604);
```

---

### Correction C3 — Supprimer le double audio (suppressGlobalPlayer)

Dans `initState`, après la ligne :
```dart
MiniPlayerService.instance.currentAyahKey.addListener(_onPlayingAyahChanged);
```

Ajoute :
```dart
AudioService.instance.suppressGlobalPlayer.value = true;
```

Dans `dispose`, avant `super.dispose()`, ajoute :
```dart
AudioService.instance.suppressGlobalPlayer.value = false;
```

Ajoute l'import nécessaire en haut du fichier si absent :
```dart
import '../services/audio_service.dart';
```

---

### Correction C1 — Mettre à jour `currentPage` lors du swipe

Dans le widget `QuranPageView(...)` (à l'intérieur du `Listener` dans le `Stack`), ajoute le callback `onPageChanged` s'il n'est pas déjà présent, ou remplace-le :

```dart
onPageChanged: (page) {
  if (!mounted) return;
  setState(() => currentPage = page.clamp(1, 604));
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(milliseconds: 800), () {
    if (mounted) _saveToHistory(currentPage);
  });
},
```

> Attention : si `QuranPageView` n'expose pas `onPageChanged`, utilise `onAyahTap` déjà présent pour mettre à jour `currentPage` mais garde aussi un callback de changement de page si le package le propose. Vérifie l'API du package `quran_pages_with_ayah_detector`.

---

### Correction M2 — Augmenter le délai du `_saveTimer` dans `onAyahTap`

Dans le callback `onAyahTap`, remplace :
```dart
_saveTimer = Timer(const Duration(milliseconds: 350), () {
```
Par :
```dart
_saveTimer = Timer(const Duration(milliseconds: 800), () {
```

Et dans la closure du timer, remplace `_saveToHistory(page)` par `_saveToHistory(currentPage)` pour utiliser la page courante au moment du déclenchement et non celle capturée dans la closure du tap :

```dart
_saveTimer = Timer(const Duration(milliseconds: 800), () {
  if (!mounted) return;
  _saveToHistory(currentPage);
});
```

---

### Correction C2 — Supprimer la double sauvegarde dans `_saveToHistory`

Dans la méthode `_saveToHistory`, supprime entièrement le bloc :
```dart
LastReadingService.saveLastReading(
  surahNumber: surah['id'] as int,
  pageNumber: page,
);
```

La méthode doit uniquement appeler `ReadingHistoryService.instance.saveLastReading(...)`.

---

### Correction M3 — Supprimer `_kJuzzStart` local et utiliser `juzzMap`

La constante `_kJuzzStart` en bas du fichier est une duplication de données déjà présentes dans `hizb_juzz.dart`. Remplace son usage dans `_NavigationPickerState._onJuzzChanged` :

Remplace :
```dart
final start     = _kJuzzStart[idx];
final surahId   = start[0];
final startAyah = start[1];
```
Par :
```dart
final juzzEntry = juzzMap[idx];
final startPage = juzzEntry['start_page']!;
// Trouver la sourate dont la page de début est >= startPage
final surahEntry = widget.surahList.lastWhere(
  (s) => (s['page'] as int) <= startPage,
  orElse: () => widget.surahList.first,
);
final surahId   = surahEntry['id'] as int;
final startAyah = 1;
```

Puis supprime la constante `_kJuzzStart` en bas du fichier.

> Note : cette correction change légèrement le comportement (startAyah toujours 1 au lieu d'un ayah précis par juzz). C'est acceptable : la navigation par juzz doit ouvrir la première page du juzz, l'utilisateur choisit ensuite le verset dans la roulette.

---

## FICHIER 3 : `lib/ui/widgets/mini_audio_player.dart`

### Correction m2 — Guard `mounted` dans `_SwipeToDismissPlayer`

Dans `_SwipeToDismissPlayerState.build`, dans le `GestureDetector.onVerticalDragEnd`, remplace :
```dart
onVerticalDragEnd: (d) {
  if (_offset > 60 || d.velocity.pixelsPerSecond.dy > 400) {
    widget.onDismiss();
  }
  setState(() => _offset = 0);
},
```
Par :
```dart
onVerticalDragEnd: (d) {
  final shouldDismiss = _offset > 60 || d.velocity.pixelsPerSecond.dy > 400;
  if (shouldDismiss) {
    widget.onDismiss();
    return; // ne pas appeler setState sur un widget qui va se démonter
  }
  if (mounted) setState(() => _offset = 0);
},
```

Et même chose pour `onVerticalDragCancel` :
```dart
onVerticalDragCancel: () {
  if (mounted) setState(() => _offset = 0);
},
```

### Correction M4 — SafeArea sur le GlobalMiniPlayerOverlay

Dans `GlobalMiniPlayerOverlay.build`, enveloppe `_SwipeToDismissPlayer` dans un `SafeArea` :

Remplace :
```dart
child: _SwipeToDismissPlayer(
  onDismiss: audio.stop,
),
```
Par :
```dart
child: SafeArea(
  bottom: true,
  top: false,
  child: _SwipeToDismissPlayer(
    onDismiss: audio.stop,
  ),
),
```

---

## FICHIER 4 : `lib/services/last_reading_service.dart`

### Nettoyage — Ce fichier est désormais inutile

Après avoir vérifié qu'aucun autre fichier du projet n'importe `last_reading_service.dart` (lance une recherche globale avec `grep -r "last_reading_service" lib/`), supprime le fichier.

> Si d'autres fichiers l'importent encore, ne supprime pas le fichier et signale-le.

---

## VÉRIFICATIONS FINALES

Une fois toutes les corrections appliquées :

1. Lance `flutter analyze` et corrige tous les warnings/erreurs introduits.
2. Vérifie que `dart:ui` peut être retiré sans erreur (sinon remets-le).
3. Vérifie qu'aucun fichier n'importe encore `last_reading_service.dart`.
4. Vérifie que `QuranPagesHitboxDb.getPageForAyah` compile correctement en vérifiant que la colonne `page` existe bien dans la table `ayarects` (schéma attendu : `page INT, soraid INT, ayaid INT, minx, miny, maxx, maxy`).

---

## RÉSUMÉ DES CORRECTIONS

| ID | Fichier | Nature |
|----|---------|--------|
| C1 | reader_screen.dart | currentPage mis à jour au swipe via onPageChanged |
| C2 | reader_screen.dart + last_reading_service.dart | Suppression double sauvegarde |
| C3 | reader_screen.dart | suppressGlobalPlayer activé dans Reader |
| C4 | quran_pages_hitbox_db.dart | Ajout méthode getPageForAyah() |
| M1 | reader_screen.dart | currentPage clampé à l'init |
| M2 | reader_screen.dart | Timer 800ms + utilise currentPage courant |
| M3 | reader_screen.dart | _kJuzzStart supprimé, juzzMap utilisé |
| M4 | mini_audio_player.dart | SafeArea sur GlobalMiniPlayerOverlay |
| m1 | reader_screen.dart | GradientText dead code supprimé |
| m2 | mini_audio_player.dart | Guard mounted dans SwipeToDismiss |
| m3 | reader_screen.dart | (context AlertDialog dans NotesListSheet — voir note) |
| m4 | reader_screen.dart | import dart:ui supprimé si non nécessaire |

### Note sur m3 (_NotesListSheet.confirmDismiss)
Dans `_NotesListSheetState.build`, le `confirmDismiss` passe `context: context` du widget parent.
Si après les autres corrections tu observes un crash lors du swipe-to-delete dans la liste de notes,
remplace `context: context` dans l'`AlertDialog` du `confirmDismiss` par le contexte local du builder :

```dart
confirmDismiss: (direction) async {
  // utilise `context` du ListWheelScrollView builder, pas du parent
  return await showDialog<bool>(
    context: context, // ce `context` vient du builder du ListView, c'est correct
    ...
  ) ?? false;
},
```
En pratique Flutter remonte correctement le contexte ici — ce point est à surveiller en test mais pas prioritaire.
