import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import '../models/reciter.dart';

class ReciterDetailScreen extends StatelessWidget {
  final Reciter reciter;
  const ReciterDetailScreen({super.key, required this.reciter});

  Future<Map<String, dynamic>?> _loadBioEntry() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/reciters_bio.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;

      // Cherche par reciterId si présent, sinon par nom
      for (final item in list) {
        final map = item as Map<String, dynamic>;

        if (reciter.reciterId != null && map['reciterId'] != null) {
          if (map['reciterId'].toString() == reciter.reciterId.toString()) return map;
        }

        if ((map['name'] ?? '').toString().toLowerCase() == reciter.name.toLowerCase()) return map;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadBioEntry(),
        builder: (context, snap) {
          // Etat chargement
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final bioEntry = snap.data;

          final height = MediaQuery.of(context).size.height;
          final imageHeight = height * 0.48;

          final imageAsset = (bioEntry?['imageAsset'] ?? '').toString().trim();
          final imageIsAsset = imageAsset.isNotEmpty;

          // IMPORTANT: on évite Image.network(reciter.baseUrl) car baseUrl chez toi est souvent un serveur mp3.
          final imageWidget = Container(
            color: Colors.black,
            child: imageIsAsset
                ? Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                  )
                : Container(color: Colors.grey[300]),
          );

          final bioText =
              (bioEntry != null && ((bioEntry['bioFrLong'] ?? '') != '' || (bioEntry['bioFr'] ?? '') != ''))
                  ? (bioEntry['bioFrLong'] ?? bioEntry['bioFr']).toString()
                  : 'Aucune biographie disponible pour ce récitant.';

          return Stack(
            children: [
              // Image en haut
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: imageWidget,
                ),
              ),

              // Dégradé beige léger sur la partie basse de l'image
              Positioned(
                top: imageHeight - 100,
                left: 0,
                right: 0,
                height: 180,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00F5EBDA), Color(0x80F5EBDD)],
                    ),
                  ),
                ),
              ),

              // Contenu bas
              Positioned(
                left: 0,
                right: 0,
                top: imageHeight - 40,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBDD),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, -6)),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  reciter.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (reciter.reciterId != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF5EBDD),
                                      foregroundColor: Colors.black87,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        side: BorderSide(color: Colors.black.withOpacity(0.08)),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text('Écouter'),
                                    onPressed: () async {
                                      final audio = AudioService.instance;

                                      final serverFromBio = (bioEntry?['server'] ?? '').toString().trim();

                                      // Priorité: server du JSON -> reciter.server (évite baseUrl ici)
                                      final server = serverFromBio.isNotEmpty
                                          ? serverFromBio
                                          : reciter.server;

                                      audio.setReciter(reciter.name, server);
                                      await audio.loadPlaylistAndPlay(1);
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Nom arabe
                          if ((bioEntry?['arabicName'] ?? '').toString().trim().isNotEmpty)
                            Text(
                              bioEntry!['arabicName'].toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                          // Pays
                          if ((bioEntry?['country'] ?? '').toString().trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Text(
                                    bioEntry!['country'].toString(),
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Tags / chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (reciter.letter.isNotEmpty) Chip(label: Text('Code: ${reciter.letter}')),
                              if (reciter.server.isNotEmpty) Chip(label: Text('Serveur: ${reciter.server}')),

                              if (bioEntry != null && bioEntry['roles'] is List && (bioEntry['roles'] as List).isNotEmpty)
                                for (final rname in (bioEntry['roles'] as List))
                                  Chip(label: Text(rname.toString())),

                              if (bioEntry != null &&
                                  bioEntry['styleTags'] is List &&
                                  (bioEntry['styleTags'] as List).isNotEmpty)
                                for (final tag in (bioEntry['styleTags'] as List))
                                  Chip(label: Text(tag.toString())),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const Text('Biographie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(bioText, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 12),

                          // Liens (on ignore wikipedia comme tu faisais)
                          if (bioEntry != null && bioEntry['links'] is Map<String, dynamic>)
                            Row(
                              children: [
                                for (final entry in (bioEntry['links'] as Map<String, dynamic>).entries)
                                  if (entry.value != null &&
                                      entry.value.toString().trim().isNotEmpty &&
                                      entry.key.toString().toLowerCase() != 'wikipedia')
                                    IconButton(
                                      tooltip: _friendlyLinkLabel(entry.key),
                                      icon: _linkIcon(entry.key),
                                      onPressed: () async {
                                        final url = entry.value.toString().trim();
                                        try {
                                          final uri = Uri.parse(url);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _friendlyLinkLabel(String key) {
  switch (key.toLowerCase()) {
    case 'x':
      return 'X';
    case 'instagram':
      return 'Instagram';
    case 'youtube':
      return 'YouTube';
    case 'facebook':
      return 'Facebook';
    case 'officialwebsite':
    case 'website':
    case 'official_website':
      return 'Site web';
    default:
      return key.isEmpty ? 'Lien' : key[0].toUpperCase() + key.substring(1);
  }
}

Widget _linkIcon(String key) {
  switch (key.toLowerCase()) {
    case 'youtube':
      return const FaIcon(FontAwesomeIcons.youtube, color: Color(0xFFFF0000));
    case 'x':
      return const FaIcon(FontAwesomeIcons.x, color: Colors.black);
    case 'instagram':
      return const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFC13584));
    case 'facebook':
      return const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2));
    case 'officialwebsite':
    case 'website':
    case 'official_website':
      return const FaIcon(FontAwesomeIcons.globe, color: Colors.green);
    default:
      return const FaIcon(FontAwesomeIcons.link);
  }
}
