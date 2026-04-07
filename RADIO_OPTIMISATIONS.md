# Optimisations Radio — À corriger par ordre de priorité

Généré le 2026-04-07. Reprendre ici sur le nouveau PC.

---

## PRIORITÉ 1 — Gain immédiat / visible par l'utilisateur

### [P1-A] `radio_bottom_sheet.dart` + `radio_browser_screen.dart`
**Problème : 174 ValueListenableBuilder simultanés**
Chaque `_StationTile` écoute `RadioService.instance.currentStationNotifier`.
Avec 174 stations chargées, cela crée 174 listeners actifs. Quand la station
change, Flutter rebuild les 174 tiles d'un coup.

**Fix :**
Extraire la détection `isActive` hors du tile. Passer `isActive` comme paramètre
`bool` calculé dans le parent, ou utiliser `RepaintBoundary` + `ValueKey` pour
isoler chaque tile.

```dart
// Avant (dans chaque tile) :
ValueListenableBuilder<RadioStation?>(
  valueListenable: RadioService.instance.currentStationNotifier,
  builder: (_, current, __) {
    final isActive = current?.id == station.id;
    ...

// Après (dans le parent, passer en paramètre) :
ValueListenableBuilder<RadioStation?>(
  valueListenable: RadioService.instance.currentStationNotifier,
  builder: (_, current, __) => ListView.builder(
    itemBuilder: (_, i) => _StationTile(
      station: list[i],
      isActive: current?.id == list[i].id,  // calculé une fois, passé en param
      ...
```

Fichiers concernés :
- `lib/ui/screens/radio_bottom_sheet.dart` → classe `_StationTile` (ligne ~365)
- `lib/ui/screens/radio_browser_screen.dart` → classe `_StationTile` (ligne ~1380)

---

### [P1-B] `radio_service.dart`
**Problème : `getRecents()` et `getPopular()` refont un appel réseau**
Les deux méthodes appellent `await getStations()` alors que les stations sont
déjà en mémoire dans `_memCache`.

**Fix :**
Remplacer `await getStations()` par `cachedStations` (déjà public) dans les
deux méthodes. Si le cache est vide, appeler `getStations()`.

```dart
// Avant :
Future<List<RadioStation>> getRecents() async {
  final all = await getStations();  // ← appel réseau potentiel

// Après :
Future<List<RadioStation>> getRecents() async {
  final all = cachedStations.isNotEmpty
      ? cachedStations
      : await getStations();
```

Lignes concernées : ~128 (getRecents) et ~153 (getPopular)

---

### [P1-C] `radio_service.dart`
**Problème : `getFavoriteIds()` lit SharedPreferences à chaque `isFavorite()`**
Chaque fois qu'une tile affiche l'état favori, elle lit le disque.
Avec 174 stations → 174 lectures disque potentielles.

**Fix :**
Ajouter un `ValueNotifier<Set<int>> _favoriteIdsCache` chargé une fois au
démarrage, mis à jour dans `toggleFavorite()`. Les tiles lisent le cache sans
I/O.

```dart
// Ajouter dans RadioService :
final ValueNotifier<Set<int>> favoriteIdsNotifier = ValueNotifier({});

Future<void> _loadFavoriteIds() async {
  favoriteIdsNotifier.value = await getFavoriteIds();
}
// Appeler _loadFavoriteIds() dans getStations() ou à l'init.

// Dans toggleFavorite() — mettre à jour le notifier :
favoriteIdsNotifier.value = Set.from(ids.map(int.parse));

// Dans les tiles — plus besoin de Future :
final isFav = RadioService.instance.favoriteIdsNotifier.value.contains(station.id);
```

---

### [P1-D] `radio_player_screen.dart`
**Problème : `onPanUpdate` → `setState()` à 60fps rebuild le Stack entier**
Chaque pixel de glissement rebuild tout le player (fond flouté, miniature,
contrôles, header).

**Fix :**
Utiliser un `AnimationController` + `AnimatedBuilder` pour le drag, isolé du
reste. Le `BackdropFilter` est particulièrement coûteux à recalculer.

```dart
// Ajouter AnimationController pour drag :
late final AnimationController _dragCtrl;
// Utiliser AnimatedBuilder uniquement sur le Transform.translate
// au lieu de setState sur tout le Scaffold.
```

Lignes concernées : `onPanUpdate` (~ligne 194), `Transform.translate` (~ligne 216)

---

## PRIORITÉ 2 — Batterie / animations inutiles

### [P2-A] `radio_browser_screen.dart`
**Problème : `_AutoScrollBanner` Timer.periodic 30ms tourne en permanence**
Le timer continue même si l'utilisateur est sur l'onglet "Favoris" ou
si l'écran est éteint.

**Fix :**
Écouter `_tabCtrl` dans `_AutoScrollBannerState`. Arrêter le timer quand
l'onglet Accueil n'est pas actif.

```dart
// Passer _tabCtrl en paramètre ou utiliser WidgetsBindingObserver :
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) { _timer?.cancel(); }
  if (state == AppLifecycleState.resumed) { _startScroll(); }
}
```

Fichier : `lib/ui/screens/radio_browser_screen.dart` → classe `_AutoScrollBannerState`

---

### [P2-B] `radio_bottom_sheet.dart`
**Problème : `_LeadingIcon` anime TOUTES les tiles, même les inactives**
`_LeadingIconState` a un `AnimationController.repeat()` sur chaque tile,
mais l'animation n'est visible que sur la station active. Les autres gaspillent
du CPU inutilement.

**Fix :**
Ne lancer `_ctrl.repeat()` que si `widget.isActive == true`.
Dans `didUpdateWidget`, arrêter si `!isActive`, relancer si `isActive`.

```dart
@override
void didUpdateWidget(_LeadingIcon old) {
  super.didUpdateWidget(old);
  if (widget.isActive && !_ctrl.isAnimating) {
    _ctrl.repeat(reverse: true);
  } else if (!widget.isActive && _ctrl.isAnimating) {
    _ctrl.stop();
    _ctrl.value = 0;
  }
}
```

Fichier : `lib/ui/screens/radio_bottom_sheet.dart` → classe `_LeadingIconState`

---

### [P2-C] `radio_player_screen.dart`
**Problème : `_pulseCtrl.repeat()` tourne même quand la radio est en pause**
L'animation pulse de la miniature tourne en boucle même si l'audio est mis
en pause.

**Fix :**
Dans le `StreamBuilder<PlayerState>`, démarrer/arrêter `_pulseCtrl` selon
`playing` :

```dart
// Dans le StreamBuilder builder :
if (playing && !_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
if (!playing && _pulseCtrl.isAnimating) { _pulseCtrl.stop(); _pulseCtrl.value = 0; }
```

Fichier : `lib/ui/screens/radio_player_screen.dart` → `_buildBody`, StreamBuilder (~ligne 407)

---

### [P2-D] `radio_player_screen.dart`
**Problème : Volume slider `setVolume()` appelé à chaque pixel sans throttle**
Si l'utilisateur glisse vite, 100+ appels à `setVolume()` par seconde.

**Fix :**
Ajouter un debounce de 50ms ou throttle :

```dart
Timer? _volDebounce;
// Dans onChanged :
_volDebounce?.cancel();
_volDebounce = Timer(const Duration(milliseconds: 50), () {
  AudioService.instance.setVolume(v);
});
```

Fichier : `lib/ui/screens/radio_player_screen.dart` → `_buildVolumeSlider`

---

## PRIORITÉ 3 — Réseau / I/O moins urgent

### [P3-A] `radio_service.dart`
**Problème : `SharedPreferences.getInstance()` appelé à chaque lecture/écriture**
Chaque méthode (trackPlay, getRecents, getFavorites, toggleFavorite) appelle
`SharedPreferences.getInstance()` indépendamment.

**Fix :**
Initialiser SharedPreferences une fois dans un champ `Future<SharedPreferences>`
et le réutiliser :

```dart
final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
// Puis dans chaque méthode :
final prefs = await _prefs;  // retourne immédiatement si déjà initialisé
```

---

### [P3-B] `radio_service.dart`
**Problème : Pas de protection contre double `_refreshInBackground()` simultanés**
Si `getStations()` est appelé deux fois rapidement, deux refresh réseau
partent en parallèle.

**Fix :**
Stocker la Future en cours et retourner la même si déjà active :

```dart
Future<List<RadioStation>>? _ongoingFetch;

Future<List<RadioStation>> _fetchFromApi() {
  _ongoingFetch ??= _doFetch().whenComplete(() => _ongoingFetch = null);
  return _ongoingFetch!;
}
```

---

### [P3-C] `audio_service.dart`
**Problème : `setAudioSource()` radio sans timeout**
Si le stream radio est lent ou mort, `setAudioSource()` peut bloquer
indéfiniment (ou jusqu'au timeout Dio de 10s).

**Fix :**
```dart
await _player.setAudioSource(...).timeout(
  const Duration(seconds: 15),
  onTimeout: () => throw TimeoutException('Stream radio indisponible'),
);
```

Fichier : `lib/services/audio_service.dart` → méthode `playRadio` (~ligne 870)

---

## Récapitulatif

| ID | Fichier | Problème | Impact |
|----|---------|----------|--------|
| P1-A | radio_bottom_sheet + browser | 174 listeners ValueListenable | ⚠⚠⚠ CPU |
| P1-B | radio_service | getRecents/getPopular refont réseau | ⚠⚠⚠ Réseau |
| P1-C | radio_service | getFavoriteIds lit disque à chaque tile | ⚠⚠⚠ I/O |
| P1-D | radio_player | onPanUpdate setState 60fps | ⚠⚠⚠ CPU |
| P2-A | radio_browser | AutoScrollBanner timer permanent | ⚠⚠ Batterie |
| P2-B | radio_bottom_sheet | LeadingIcon anime toutes les tiles | ⚠⚠ CPU |
| P2-C | radio_player | pulseCtrl tourne même en pause | ⚠⚠ Batterie |
| P2-D | radio_player | setVolume sans throttle | ⚠⚠ CPU |
| P3-A | radio_service | SharedPreferences.getInstance répété | ⚠ I/O |
| P3-B | radio_service | Double refresh simultané possible | ⚠ Réseau |
| P3-C | audio_service | setAudioSource sans timeout | ⚠ Réseau |
