import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

// Utilitaire pour matcher les récitateurs locaux avec l'API mp3quran.net
// Usage: dart run lib/tool/match_reciters.dart

void main() async {
  try {
    print('🔍 Chargement des récitateurs locaux...');
    
    // Lire le fichier JSON local
    final localFile = File('assets/data/reciters_mapping.old.json');
    final localJsonStr = await localFile.readAsString();
    final localReciters = jsonDecode(localJsonStr) as List;
    
    print('✅ ${localReciters.length} récitateurs locaux chargés\n');
    
    print('🌐 Récupération des récitateurs depuis l\'API mp3quran.net...');
    final dio = Dio();
    final response = await dio.get('https://mp3quran.net/api/v3/reciters?language=eng');
    final apiReciters = response.data['reciters'] as List;
    
    print('✅ ${apiReciters.length} récitateurs API chargés\n');
    
    print('=' * 80);
    print('RÉSULTATS DU MATCHING');
    print('=' * 80);
    
    final enrichedReciters = [];
    
    for (final local in localReciters) {
      final localName = (local['name'] ?? '').toString();
      final localAsset = (local['asset'] ?? '').toString();
      
      // Fuzzy matching
      final match = _findBestMatch(localName, apiReciters);
      
      if (match != null) {
        final reciterId = match['id'];
        final apiName = match['name'];
        final moshafList = (match['moshaf'] as List?) ?? [];
        
        print('\n✓ MATCH TROUVÉ:');
        print('  Local: "$localName"');
        print('  API:   "$apiName" (ID: $reciterId)');
        print('  Moshaf disponibles (${moshafList.length}):');
        
        for (int i = 0; i < moshafList.length; i++) {
          final m = moshafList[i];
          final moshafId = m['id'];
          final moshafName = m['name'];
          final server = m['server'];
          final surahTotal = m['surah_total'];
          print('    [$i] ID: $moshafId | "$moshafName" | Sourates: $surahTotal');
          print('        Server: $server');
        }
        
        // Prendre le premier moshaf par défaut
        final defaultMoshafId = moshafList.isNotEmpty ? moshafList[0]['id'] : null;
        
        enrichedReciters.add({
          'name': localName,
          'reciterId': reciterId,
          'moshafId': defaultMoshafId,
          'asset': localAsset,
        });
        
        print('  → Ajouté avec reciterId=$reciterId, moshafId=$defaultMoshafId (défaut)');
      } else {
        print('\n✗ PAS DE MATCH:');
        print('  Local: "$localName"');
        print('  → Récitateur introuvable dans l\'API');
        
        enrichedReciters.add({
          'name': localName,
          'reciterId': null,
          'moshafId': null,
          'asset': localAsset,
        });
      }
    }
    
    print('\n' + '=' * 80);
    print('📝 Génération du nouveau JSON...');
    
    final outputFile = File('assets/data/reciters_mapping_enriched.json');
    const encoder = JsonEncoder.withIndent('  ');
    await outputFile.writeAsString(encoder.convert(enrichedReciters));
    
    print('✅ Fichier généré: ${outputFile.path}');
    print('\n📋 Statistiques:');
    
    final matched = enrichedReciters.where((r) => r['reciterId'] != null).length;
    final unmatched = enrichedReciters.length - matched;
    
    print('  • Matchés: $matched');
    print('  • Non-matchés: $unmatched');
    print('  • Total: ${enrichedReciters.length}');
    
    print('\n💡 Prochaines étapes:');
    print('  1. Vérifier reciters_mapping_enriched.json');
    print('  2. Ajuster manuellement les moshafId si nécessaire');
    print('  3. Renommer vers reciters_mapping.json');
    
  } catch (e, stack) {
    print('❌ ERREUR: $e');
    print(stack);
    exit(1);
  }
}

// Fuzzy matching basé sur similarité de chaînes
Map<String, dynamic>? _findBestMatch(String localName, List apiReciters) {
  final normalized = _normalize(localName);
  
  // Essayer d'abord un match exact
  for (final reciter in apiReciters) {
    final apiName = (reciter['name'] ?? '').toString();
    if (_normalize(apiName) == normalized) {
      return reciter as Map<String, dynamic>;
    }
  }
  
  // Ensuite chercher une correspondance partielle
  final tokens = normalized.split(' ');
  Map<String, dynamic>? bestMatch;
  int bestScore = 0;
  
  for (final reciter in apiReciters) {
    final apiName = _normalize((reciter['name'] ?? '').toString());
    int score = 0;
    
    for (final token in tokens) {
      if (token.length < 3) continue; // Ignorer les mots courts
      if (apiName.contains(token)) {
        score += token.length;
      }
    }
    
    // Correspondance dans l'autre sens
    final apiTokens = apiName.split(' ');
    for (final token in apiTokens) {
      if (token.length < 3) continue;
      if (normalized.contains(token)) {
        score += token.length;
      }
    }
    
    if (score > bestScore) {
      bestScore = score;
      bestMatch = reciter as Map<String, dynamic>;
    }
  }
  
  // Retourner seulement si le score est significatif
  return bestScore >= 5 ? bestMatch : null;
}

String _normalize(String s) {
  return s.toLowerCase()
      .replaceAll(RegExp(r'[àáâäãåā]'), 'a')
      .replaceAll(RegExp(r'[èéêëē]'), 'e')
      .replaceAll(RegExp(r'[ìíîïī]'), 'i')
      .replaceAll(RegExp(r'[òóôöõøō]'), 'o')
      .replaceAll(RegExp(r'[ùúûüū]'), 'u')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
