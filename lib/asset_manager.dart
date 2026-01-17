import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;

/// URL de ton ZIP hébergé sur Google Drive public
const String zipUrl = 'https://drive.google.com//file/d/1FDBfeza5AXF3yPZKk0Uyri8YcZn-LBuT/view?usp=drive_link';
const String zipFileName = 'quran_pages.zip';

/// Télécharge et décompresse le ZIP
Future<void> downloadAndExtractZip({Function(double)? onProgress}) async {
  final dir = await getApplicationDocumentsDirectory();
  final zipFile = File(p.join(dir.path, zipFileName));

  if (!await zipFile.exists()) {
    print('Téléchargement du ZIP...');
    final request = await http.Client().send(http.Request('GET', Uri.parse(zipUrl)));

    final contentLength = request.contentLength ?? 0;
    List<int> bytes = [];
    int received = 0;

    await request.stream.listen((chunk) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (onProgress != null && contentLength > 0) {
        onProgress(received / contentLength); // valeur entre 0 et 1
      }
    }).asFuture();

    await zipFile.writeAsBytes(bytes);
    print('ZIP téléchargé !');
  } else {
    print('ZIP déjà présent, pas besoin de retélécharger.');
  }

  // Décompression
  final bytes = await zipFile.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final file in archive) {
    final filePath = p.join(dir.path, file.name);
    if (file.isFile) {
      final outFile = File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }
  }

  print('ZIP décompressé !');
}
