# Guide des Réciteurs MP3Quran

## Ordre des réciteurs (gauche → droite)

Les réciteurs sont affichés dans l'ordre suivant, avec leurs URLs MP3Quran associées :

| # | Réciteur | Base URL |
|---|----------|----------|
| 1 | Abdurashid Sufi | `https://server12.mp3quran.net/abdurashid_sufi` |
| 2 | Abdulbaset | `https://server8.mp3quran.net/abdulbasit` |
| 3 | Shuraym | `https://server7.mp3quran.net/shur` |
| 4 | Sudais | `https://server11.mp3quran.net/sds` |
| 5 | Maher Almuaiqly | `https://server12.mp3quran.net/maher` |
| 6 | Ali Jabir | `https://server10.mp3quran.net/jbr` |
| 7 | As-shatri | `https://server11.mp3quran.net/shatri` |
| 8 | Al Ajmy | `https://server10.mp3quran.net/ajm` |
| 9 | Al Hudhaify | `https://server11.mp3quran.net/hudhaify` |
| 10 | Al Qatami | `https://server12.mp3quran.net/qtm` |
| 11 | Al Juhani | `https://server11.mp3quran.net/jhn` |
| 12 | Bandar Baleela | `https://server10.mp3quran.net/balilah` |
| 13 | Hani Arrifai | `https://server8.mp3quran.net/hani` |
| 14 | Alhusary | `https://server13.mp3quran.net/husr` |
| 15 | Mishari Alafasy | `https://server8.mp3quran.net/afs` |
| 16 | Saad Alghamdi | `https://server11.mp3quran.net/sgmd` |

## Construction de l'URL audio

### Format
```
${baseUrl}/${surahId.padLeft(3,'0')}.mp3
```

### Exemples
- **Al-Fatiha (surahId=1) avec Mishari Alafasy** : 
  - `https://server8.mp3quran.net/afs/001.mp3`

- **Al-Baqara (surahId=2) avec Sudais** : 
  - `https://server11.mp3quran.net/sds/002.mp3`

- **An-Nas (surahId=114) avec Abdulbaset** : 
  - `https://server8.mp3quran.net/abdulbasit/114.mp3`

## Utilisation dans le code

### Modèle Reciter
```dart
class Reciter {
  final String? baseUrl;
  
  /// Construit l'URL complète d'une sourate
  String getAudioUrl(int surahId) {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw Exception('baseUrl not configured for reciter: $name');
    }
    final paddedId = surahId.toString().padLeft(3, '0');
    return '$baseUrl/$paddedId.mp3';
  }
}
```

### Exemple d'utilisation
```dart
// Charger le réciteur depuis le JSON
final reciter = Reciter.fromJson(json);

// Obtenir l'URL de la sourate Al-Fatiha (1)
final url = reciter.getAudioUrl(1);
// => "https://server8.mp3quran.net/afs/001.mp3"
```

### onTap dans le widget
Lorsqu'un utilisateur clique sur un réciteur :
1. Le système charge la `baseUrl` depuis le fichier JSON
2. La fonction `_onReciterSelected` utilise cette URL directement
3. Si `baseUrl` n'est pas disponible, un fallback vers l'API MP3Quran est effectué

```dart
Future<void> _onReciterSelected(Reciter r) async {
  String? server;
  
  // Priorité à baseUrl si disponible
  if (r.baseUrl != null && r.baseUrl!.isNotEmpty) {
    server = r.baseUrl;
  } 
  // Fallback vers API
  else if (r.reciterId != null) {
    // ... logique API
  }
  
  // Lancer la lecture
  _audio.setReciter(r.name, server);
  await _audio.loadPlaylistAndPlay(1);
}
```

## Fichier de configuration

Les URLs sont configurées dans : [`assets/data/reciters_mapping.json`](assets/data/reciters_mapping.json)

```json
[
  {
    "name": "Mishari Alafasy",
    "reciterId": 185,
    "asset": "assets/images/reciters/mishari_rashid_alafasy.webp",
    "baseUrl": "https://server8.mp3quran.net/afs"
  }
]
```

## Notes importantes

- ⚠️ **L'ordre dans le JSON DOIT correspondre à l'ordre d'affichage des images**
- ✅ Les URLs sont testées et fonctionnelles
- 🔄 Le système utilise un fallback automatique vers l'API si `baseUrl` n'est pas disponible
- 📦 Le numéro de sourate est toujours formaté sur 3 chiffres avec des zéros (001, 002, etc.)
