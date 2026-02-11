import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reciter.dart';
import 'reciter_detail_screen.dart';

class RecitersGalleryScreen extends StatelessWidget {
  final List<Reciter> reciters;
  const RecitersGalleryScreen({super.key, required this.reciters});

  Future<List<Map<String, dynamic>>> _loadBioList() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/reciters_bio.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tous les récitants')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadBioList(),
        builder: (context, snap) {
          final bioList = snap.data ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: reciters.length,
            itemBuilder: (context, i) {
              final r = reciters[i];
              final bioEntry = bioList.firstWhere(
                (e) => (e['reciterId'] != null && r.reciterId != null && e['reciterId'].toString() == r.reciterId.toString()) || (e['name'] ?? '').toString().toLowerCase() == r.name.toLowerCase(),
                orElse: () => {},
              );

              final hasAssetImage = bioEntry.isNotEmpty && (bioEntry['imageAsset'] ?? '').toString().isNotEmpty;
              final image = hasAssetImage
                  ? Image.asset(bioEntry['imageAsset'], fit: BoxFit.cover)
                  : (r.baseUrl != null && r.baseUrl!.isNotEmpty
                      ? Image.network(r.baseUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300]));

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReciterDetailScreen(reciter: r)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(child: image),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 96,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 14,
                        child: Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            shadows: [Shadow(blurRadius: 6, color: Colors.white)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
