import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

String slug(String s) {
  final lower = s.toLowerCase().trim();
  final noAccents = lower
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');

  final cleaned = noAccents.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<void> main() async {
  final dio = Dio();

  // 1) Ton JSON local (name + asset)
  final inputFile = File('assets/data/reciters_mapping.json');
  final input = json.decode(await inputFile.readAsString()) as List;

  // 2) API mp3quran : name -> server (moshaf[0].server)
  final res = await dio.get('https://mp3quran.net/api/v3/reciters?language=fr');
  final apiReciters = (res.data['reciters'] as List?) ?? const [];

  final Map<String, String> serverBySlug = {};
  for (final it in apiReciters) {
    final r = it as Map<String, dynamic>;
    final name = (r['name'] ?? '').toString().trim();
    final moshaf = (r['moshaf'] as List?) ?? const [];
    if (name.isEmpty || moshaf.isEmpty) continue;

    final first = moshaf.first as Map<String, dynamic>;
    final server = (first['server'] ?? '').toString().trim();
    if (server.isEmpty) continue;

    serverBySlug[slug(name)] = server;
  }

  // 3) Fusion : ajoute server à chaque entrée
  final List<Map<String, dynamic>> out = [];
  final List<String> missing = [];

  for (final e in input) {
    final m = (e as Map).cast<String, dynamic>();
    final name = (m['name'] ?? '').toString().trim();
    final asset = (m['asset'] ?? '').toString().trim();

    final server = serverBySlug[slug(name)] ?? '';
    if (server.isEmpty) missing.add(name);

    out.add({
      'name': name,
      'asset': asset,
      'server': server, // <- clé importante
    });
  }

  // 4) Écrit le JSON final
  final outputFile = File('assets/data/reciters_home.json');
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(out));

  stdout.writeln('OK -> ${outputFile.path}');
  if (missing.isNotEmpty) {
    stdout.writeln('MISSING SERVER (${missing.length}):');
    for (final n in missing) {
      stdout.writeln('- $n');
    }
  }
}
