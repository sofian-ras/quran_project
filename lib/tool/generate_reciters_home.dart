import 'dart:convert';
import 'dart:io';

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _assetKey(String assetPath) {
  // assets/images/reciters/abdurashid_ali_sufi_assabile.webp
  final file = assetPath.split('/').last;
  return _norm(file.replaceAll(RegExp(r'\.(png|jpg|jpeg|webp)$'), ''));
}

double _score(String a, String b) {
  final na = _norm(a);
  final nb = _norm(b);
  if (na.isEmpty || nb.isEmpty) return 0;

  if (na == nb) return 1000;
  double score = 0;

  if (na.contains(nb) || nb.contains(na)) score += 120;

  final sa = na.split(' ').where((t) => t.length >= 3).toSet();
  final sb = nb.split(' ').where((t) => t.length >= 3).toSet();
  if (sa.isEmpty || sb.isEmpty) return score;

  final inter = sa.intersection(sb).length;
  final uni = sa.union(sb).length;
  score += (inter / uni) * 100;

  return score;
}

Future<Map<String, dynamic>> _fetch(String url) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set('accept', 'application/json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: $body");
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

String _pickServer(Map<String, dynamic> r) {
  final moshaf = ((r['moshaf'] as List?) ?? const []).cast<dynamic>();
  if (moshaf.isEmpty) return '';
  final first = (moshaf.first as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  return (first['server'] ?? '').toString().trim();
}

String _serverSlug(String server) {
  // ex: https://server16.mp3quran.net/a_alqrafi/Rewayat-Hafs-A-n-Assem/
  final u = server.toLowerCase();
  if (u.isEmpty) return '';
  // On prend le segment juste après le domaine: /a_alqrafi/...
  final parts = Uri.tryParse(server)?.pathSegments ?? const [];
  if (parts.isEmpty) return '';
  return _norm(parts.first);
}

Future<void> main() async {
  final mappingFile = File('assets/data/reciters_mapping.json');
  if (!await mappingFile.exists()) {
    stderr.writeln('❌ Introuvable: assets/data/reciters_mapping.json');
    exit(1);
  }

  final mappingRaw = jsonDecode(await mappingFile.readAsString()) as List<dynamic>;
  final mapping = mappingRaw
      .map((e) => e as Map<String, dynamic>)
      .where((m) => (m['asset'] ?? '').toString().trim().isNotEmpty)
      .toList();

  stdout.writeln('📦 mapping: ${mapping.length}');

  // IMPORTANT: on récupère aussi en anglais (noms latins)
  stdout.writeln('🌐 Fetch mp3quran reciters (ENG)...');
  final apiEng = await _fetch("https://mp3quran.net/api/v3/reciters?language=eng");
  final recitersEng = ((apiEng['reciters'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();

  stdout.writeln('✅ mp3quran ENG: ${recitersEng.length}');

  // Prépare une liste de candidats avec plusieurs champs de matching
  final candidates = recitersEng.map((r) {
    final name = (r['name'] ?? '').toString();
    final id = (r['id'] ?? '').toString();
    final server = _pickServer(r);
    final slug = _serverSlug(server);

    return {
      "id": id,
      "name": name,
      "server": server,
      "slug": slug,
      "raw": r,
    };
  }).toList();

  final List<Map<String, dynamic>> out = [];
  final List<String> warnings = [];

  for (final m in mapping) {
    final originalName = (m['name'] ?? '').toString().trim();
    final asset = (m['asset'] ?? '').toString().trim();
    final key = _assetKey(asset); // clé dérivée du nom de fichier

    int best = -1;
    double bestScore = -1;
    double secondBest = -1;

    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final cName = (c['name'] ?? '').toString();
      final cSlug = (c['slug'] ?? '').toString();
      final cServer = (c['server'] ?? '').toString();

      // on score sur 3 choses:
      // 1) mapping.name vs api.name
      // 2) asset filename key vs api.name
      // 3) asset filename key vs server slug
      final s1 = _score(originalName, cName);
      final s2 = _score(key, cName);
      final s3 = _score(key, cSlug);

      // bonus si le server contient un morceau du key (souvent vrai)
      double bonus = 0;
      final nk = _norm(key);
      final ns = _norm(cServer);
      if (nk.isNotEmpty && ns.contains(nk)) bonus += 80;

      final s = s1 + s2 + (s3 * 1.2) + bonus;

      if (s > bestScore) {
        secondBest = bestScore;
        bestScore = s;
        best = i;
      } else if (s > secondBest) {
        secondBest = s;
      }
    }

    // garde-fou: il faut un score “suffisant” et un écart avec le 2e
    final confident = bestScore >= 140 && (bestScore - secondBest) >= 20;

    if (best == -1 || !confident) {
      warnings.add('⚠️ Match faible: "$originalName" (assetKey="$key") score=$bestScore');
      out.add({
        "id": "",
        "name": originalName.isNotEmpty ? originalName : key,
        "server": "",
        "suras": "",
        "asset": asset,
      });
      continue;
    }

    final chosen = candidates[best];
    final chosenId = (chosen['id'] ?? '').toString();
    final chosenName = (chosen['name'] ?? '').toString();
    final chosenServer = (chosen['server'] ?? '').toString();

    out.add({
      "id": chosenId,
      "name": chosenName,       // nom mp3quran (anglais)
      "server": chosenServer,   // ✅ server direct
      "suras": "",              // optionnel
      "asset": asset,           // ✅ ton portrait
    });
  }

  final outFile = File('assets/data/reciters_home.json');
  const encoder = JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(out) + '\n');

  stdout.writeln('✅ Généré: assets/data/reciters_home.json (${out.length})');

  if (warnings.isNotEmpty) {
    stdout.writeln('\n--- WARNINGS (à corriger manuellement si besoin) ---');
    for (final w in warnings.take(60)) {
      stdout.writeln(w);
    }
    if (warnings.length > 60) {
      stdout.writeln('... (+${warnings.length - 60} autres)');
    }
  }
}
