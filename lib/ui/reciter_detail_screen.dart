import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import 'full_player_screen.dart';
import '../models/reciter.dart';

class ReciterDetailScreen extends StatelessWidget {
  final Reciter reciter;
  const ReciterDetailScreen({super.key, required this.reciter});

  String _resolveServer(Map<String, dynamic>? bioEntry) {
    String? candidate;
    if (bioEntry != null && (bioEntry['server'] ?? '').toString().isNotEmpty) {
      candidate = bioEntry['server'].toString();
    } else if (reciter.baseUrl != null && reciter.baseUrl!.isNotEmpty) {
      candidate = reciter.baseUrl!;
    } else if (reciter.server.isNotEmpty) {
      candidate = reciter.server;
    }

    if (candidate == null || candidate.trim().isEmpty) {
      return AudioService.instance.currentServer;
    }

    candidate = candidate.trim();
    // If it looks like a relative path (starts with /), it's invalid -> fallback
    if (candidate.startsWith('/')) return AudioService.instance.currentServer;

    if (!candidate.startsWith('http')) {
      candidate = 'https://$candidate';
    }

    // remove trailing spaces
    return candidate;
  }

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
          final bioEntry = snap.data;
          final imageIsAsset = bioEntry != null && (bioEntry['imageAsset'] ?? '').toString().isNotEmpty;
          final imageWidget = Container(
            color: Colors.black,
            child: imageIsAsset
                ? Image.asset(
                    bioEntry!['imageAsset'],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                  )
                : (reciter.baseUrl != null && reciter.baseUrl!.isNotEmpty
                    ? Image.network(
                        reciter.baseUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                      )
                    : Container(color: Colors.grey[300])),
          );

          final bioText = bioEntry != null && (bioEntry['bioFr'] ?? '').toString().isNotEmpty
              ? bioEntry['bioFr'].toString()
              : 'Aucune biographie disponible pour ce récitant.';

          final height = MediaQuery.of(context).size.height;
          final imageHeight = height * 0.48;

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

              // Contenu dans un fond beige en bas (arrondi + ombre pour transition douce)
              Positioned(
                left: 0,
                right: 0,
                top: imageHeight - 40,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBDD),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, -6))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reciter.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              if (reciter.letter.isNotEmpty) Chip(label: Text('Code: ${reciter.letter}')),
                              if (reciter.server.isNotEmpty) Chip(label: Text('Serveur: ${reciter.server}')),
                              if (reciter.reciterId != null)
                                ElevatedButton.icon(
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
                                    final scaffold = ScaffoldMessenger.of(context);
                                    final audio = AudioService.instance;
                                    final server = _resolveServer(bioEntry);

                                    try {
                                      scaffold.showSnackBar(const SnackBar(content: Text('Chargement de la lecture...')));
                                      audio.setReciter(reciter.name, server);
                                      await audio.loadPlaylistAndPlay(1);
                                      scaffold.hideCurrentSnackBar();
                                      scaffold.showSnackBar(const SnackBar(content: Text('Lecture démarrée')));
                                    } catch (e) {
                                      scaffold.hideCurrentSnackBar();
                                      scaffold.showSnackBar(SnackBar(content: Text('Erreur lecture: $e')));
                                    }
                                    // Do not open full player here; starting playback will show the mini player overlay
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text('Biographie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          
                          
                          
                          const SizedBox(height: 8),
                          Text(bioText, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 12),
                          if (bioEntry != null && bioEntry['links'] != null)
                            Row(
                              children: [
                                for (final entry in (bioEntry['links'] as Map<String, dynamic>).entries)
                                  if (entry.value != null && entry.value.toString().isNotEmpty && entry.key.toString().toLowerCase() != 'wikipedia')
                                    IconButton(
                                      tooltip: _friendlyLinkLabel(entry.key),
                                      icon: _linkIcon(entry.key),
                                      color: Colors.blueAccent,
                                      onPressed: () async {
                                        final url = entry.value.toString();
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
    case 'website':
      return 'Site web';
    default:
      return key[0].toUpperCase() + key.substring(1);
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
    case 'website':
      return const FaIcon(FontAwesomeIcons.globe, color: Colors.green);
    default:
      return const FaIcon(FontAwesomeIcons.link);
  }
}
