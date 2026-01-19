import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Clé privée ImageKit pour l’API
const String imageKitApiKey = "YOUR_PRIVATE_API_KEY";
const String warshFolder = "/warsh/";

class AssetManager {
  /// Vérifie si le pack Warsh est déjà téléchargé
  static Future<bool> warshPackExists() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/warsh');
    final testFile = File(p.join(dir.path, '1.jpg')); // On teste le premier fichier
    return await testFile.exists();
  }

  /// Récupère tous les liens Warsh depuis ImageKit
  static Future<List<String>> fetchWarshUrls() async {
    final url = "https://api.imagekit.io/v1/files/?path=$warshFolder&limit=1000";
    final headers = {
      'Authorization': 'Basic ${base64Encode(utf8.encode("$imageKitApiKey:"))}',
    };
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) throw Exception('Erreur ImageKit: ${response.statusCode}');
    final data = json.decode(response.body);
    return (data['response'] as List).map((f) => f['url'] as String).toList();
  }

  /// Télécharge le pack Warsh uniquement si nécessaire
  static Future<void> downloadWarshPack({int batchSize = 50, Function(double)? onProgress}) async {
    if (await warshPackExists()) {
      print("Pack Warsh déjà téléchargé.");
      onProgress?.call(1.0);
      return;
    }

    final urls = await fetchWarshUrls();
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/warsh');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    int total = urls.length;
    int downloaded = 0;

    for (int i = 0; i < total; i += batchSize) {
      final batch = urls.sublist(i, (i + batchSize).clamp(0, total));
      await Future.wait(batch.map((url) async {
        final ext = url.split('.').last.split('?')[0];
        final file = File('${dir.path}/${urls.indexOf(url) + 1}.$ext');
        if (!file.existsSync()) {
          final r = await http.get(Uri.parse(url));
          await file.writeAsBytes(r.bodyBytes);
        }
        downloaded++;
        onProgress?.call(downloaded / total);
      }));
    }

    print("Pack Warsh téléchargé avec succès !");
  }

  /// Récupère le fichier local (Hafs ou Warsh)
  static Future<File> getPageFile(String reading, String fileName) async {
    if (reading == "hafs") {
      // Hafs est dans les assets de l'app
      return File('assets/hafs/$fileName');
    } else {
      // Warsh est dans applicationDocumentsDirectory
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/warsh');
      return File('${dir.path}/$fileName');
    }
  }
}