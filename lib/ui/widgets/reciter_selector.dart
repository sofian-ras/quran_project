import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ReciterSelectorSheet extends StatefulWidget {
  final Function(String name, String server) onSelected;
  const ReciterSelectorSheet({super.key, required this.onSelected});

  @override
  State<ReciterSelectorSheet> createState() => _ReciterSelectorSheetState();
}

class _ReciterSelectorSheetState extends State<ReciterSelectorSheet> {
  List allReciters = [];
  List filteredReciters = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchReciters();
  }

  void _fetchReciters() async {
    try {
      final res = await Dio().get("https://mp3quran.net/api/v3/reciters?language=eng");
      if (mounted) {
        // Trier pour mettre Abdul Rashid Sofy en premier
        final reciters = res.data['reciters'] as List;
        reciters.sort((a, b) {
          final nameA = a['name'] as String;
          final nameB = b['name'] as String;
          
          // Abdul Rashid Sofy en premier
          if (nameA.toLowerCase().contains('abdul rashid') || 
              nameA.toLowerCase().contains('sofy')) {
            return -1;
          }
          if (nameB.toLowerCase().contains('abdul rashid') || 
              nameB.toLowerCase().contains('sofy')) {
            return 1;
          }
          
          // Sinon ordre alphabétique
          return nameA.compareTo(nameB);
        });
        
        setState(() {
          allReciters = reciters;
          filteredReciters = allReciters;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A165);
    
    return SafeArea(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.black54.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Barre de recherche améliorée
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: gold.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Rechercher un récitant...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: gold, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7), size: 18),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  filteredReciters = allReciters;
                                });
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        fillColor: Colors.transparent,
                        filled: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                          filteredReciters = allReciters
                            .where((r) => r['name'].toLowerCase().contains(val.toLowerCase()))
                            .toList();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Compteur de résultats
                if (!loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${filteredReciters.length} récitant${filteredReciters.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Liste des récitants
                Expanded(
                  child: loading 
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: gold, strokeWidth: 3),
                            const SizedBox(height: 16),
                            Text(
                              'Chargement des récitants...',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      )
                    : filteredReciters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, color: Colors.white.withOpacity(0.4), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun récitant trouvé',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredReciters.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white.withOpacity(0.1),
                            height: 1,
                            thickness: 1,
                          ),
                          itemBuilder: (context, i) {
                            final r = filteredReciters[i];
                            if (r['moshaf'] == null || r['moshaf'].isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final moshaf = r['moshaf'][0];
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: gold.withOpacity(0.2),
                                backgroundImage: r['photo'] != null && r['photo'].toString().isNotEmpty
                                    ? NetworkImage(r['photo'])
                                    : null,
                                child: r['photo'] == null || r['photo'].toString().isEmpty
                                    ? Text(
                                        r['name'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: gold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                r['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  moshaf['name'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.play_circle_outline,
                                color: gold,
                                size: 28,
                              ),
                              onTap: () {
                                widget.onSelected(r['name'], moshaf['server']);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
