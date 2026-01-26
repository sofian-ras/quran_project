# 📖 QuranLoader - Écran de chargement élégant

## Vue d'ensemble

`QuranLoader` est un écran de chargement magnifique qui affiche le verset coranique pendant le téléchargement des images du Coran.

---

## ✨ Caractéristiques

### 🎨 Design
- **Couleur de fond**: Beige clair (#FAF9F6) - Apaisant et élégant
- **Indicateur**: CircularProgressIndicator avec pourcentage (0-100%)
  - Couleur: Vert islamique (#2E7D32) pendant le téléchargement
  - Couleur: Or (#D4AF37) pendant l'extraction
- **Ombres**: Ombres douces pour profondeur

### 📝 Textes
- **Verset arabe**: "﴿إِنَّا سَنُلْقِي عَلَيْكَ قَوْلًا ثَقِيلًا﴾" (Sourate Al-Muzzammil 73:5)
  - Police: ScheherazadeNew (28px)
  - Couleur: Vert foncé (#1B5E20)
  - Interligne et espacement optimisés pour la lisibilité

- **Traduction française**: "Patientez, les paroles d'Allah sont lourdes"
  - Style italique, 16px
  - Couleur: Gris foncé (#424242)

### 📊 Informations de progression
- Pourcentage affiché au centre (ex: "65%")
- Taille téléchargée (ex: "52.0 MB / 80 MB")
- Statut: "Téléchargement en cours..." ou "Extraction en cours..."
- Note: "Téléchargement unique · Les prochaines ouvertures seront instantanées"

---

## 🚀 Utilisation

### Option 1: Navigation simple

```dart
import 'package:flutter/material.dart';
import 'package:quran/ui/screens/quran_loader.dart';

// Dans votre menu principal ou bouton
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const QuranLoader(
      reading: 'hafs',
      initialPage: 1,
    ),
  ),
);
```

### Option 2: Remplacement de l'écran actuel

```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => const QuranLoader(
      reading: 'warsh',
      initialPage: 42,
    ),
  ),
);
```

### Option 3: Écran initial de l'application

```dart
// Dans main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran App',
      home: const QuranLoader(), // Commence par le chargement
    );
  }
}
```

---

## 🎯 Paramètres

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `reading` | String | 'hafs' | Type de lecture ('hafs' ou 'warsh') |
| `initialPage` | int | 1 | Page à afficher après le chargement |

---

## 🔄 Flux de fonctionnement

```
1. QuranLoader démarre
   ↓
2. Vérifie si les images sont déjà téléchargées
   ↓
   Oui → Affiche directement QuranPageView
   Non → Continue
   ↓
3. Télécharge les images avec progression
   - Affiche le pourcentage (0-100%)
   - Montre la taille téléchargée
   ↓
4. Extraction des fichiers
   - Animation de rotation
   - Message "Extraction en cours..."
   ↓
5. Navigation automatique vers QuranPageView
```

---

## 🎨 Personnalisation

### Changer les couleurs

```dart
// Dans quran_loader.dart

// Couleur de fond
backgroundColor: const Color(0xFFFAF9F6), // Beige → Changez ici

// Couleur du progressIndicator
valueColor: const AlwaysStoppedAnimation<Color>(
  Color(0xFF2E7D32), // Vert → Changez ici
),

// Couleur du texte arabe
color: Color(0xFF1B5E20), // Vert foncé → Changez ici
```

### Changer le verset

```dart
// Ligne 236
const Text(
  '﴿إِنَّا سَنُلْقِي عَلَيْكَ قَوْلًا ثَقِيلًا﴾', // Changez le verset ici
  // ...
),
```

### Modifier la taille de police

```dart
// Ligne 242
fontSize: 28, // Arabe → Augmentez ou diminuez
fontSize: 16, // Français → Augmentez ou diminuez
```

---

## 🌟 Exemple complet d'intégration

```dart
import 'package:flutter/material.dart';
import 'package:quran/ui/screens/quran_loader.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou image
            const Icon(
              Icons.menu_book,
              size: 80,
              color: Color(0xFF2E7D32),
            ),
            
            const SizedBox(height: 32),
            
            // Titre
            const Text(
              'Le Saint Coran',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Bouton pour lire en Hafs
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuranLoader(
                      reading: 'hafs',
                      initialPage: 1,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lire (Hafs)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton pour lire en Warsh
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuranLoader(
                      reading: 'warsh',
                      initialPage: 1,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lire (Warsh)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔧 Dépannage

### Le verset arabe ne s'affiche pas correctement

**Solution**: Assurez-vous que la police ScheherazadeNew est bien ajoutée dans `pubspec.yaml`:

```yaml
fonts:
  - family: ScheherazadeNew
    fonts:
      - asset: assets/fonts/ScheherazadeNew-Regular.ttf
      - asset: assets/fonts/ScheherazadeNew-Bold.ttf
        weight: 700
```

Puis exécutez:
```bash
flutter pub get
```

### L'écran reste bloqué sur "Préparation..."

**Cause**: Le service de téléchargement n'arrive pas à se connecter

**Solutions**:
1. Vérifiez votre connexion Internet
2. Vérifiez l'URL dans `QuranImageService`
3. Regardez les logs: `flutter logs`

### Le pourcentage ne s'affiche pas

**Cause**: Le callback `onDownloadProgress` n'est pas appelé

**Vérification**: Dans `quran_image_service.dart`, assurez-vous que le callback est bien passé à `dio.download()`

---

## 📱 Screenshots

### État de téléchargement
- Cercle blanc avec ombre
- Indicateur vert avec pourcentage (ex: 65%)
- Verset arabe en grand
- Traduction française en italique
- Badge "Téléchargement en cours..."
- Taille: "52.0 MB / 80 MB"

### État d'extraction
- Indicateur or en rotation
- Badge "Extraction en cours..."
- Message "Cela peut prendre quelques minutes..."

### État d'erreur
- Icône rouge avec "خطأ" (Erreur)
- Message d'erreur
- Bouton "Réessayer" vert

---

## ✅ Avantages

1. **Spirituel**: Le verset rappelle la patience et la valeur des paroles d'Allah
2. **Informatif**: Progression claire avec pourcentage et taille
3. **Rassurant**: Note indiquant que c'est un téléchargement unique
4. **Élégant**: Design moderne avec couleurs islamiques traditionnelles
5. **Automatique**: Gère tout de A à Z, navigation automatique
6. **Robuste**: Gestion d'erreur avec possibilité de réessayer

---

## 🎉 Résultat final

Un écran de chargement **magnifique et spirituel** qui:
- ✅ Affiche le verset coranique avec belle calligraphie
- ✅ Montre la progression en temps réel (0-100%)
- ✅ Informe de la taille téléchargée
- ✅ Rassure l'utilisateur avec un message clair
- ✅ Navigue automatiquement vers le lecteur une fois prêt
- ✅ Gère les erreurs avec possibilité de réessayer

**L'utilisateur est spirituellement engagé pendant l'attente!** 🌙📖
