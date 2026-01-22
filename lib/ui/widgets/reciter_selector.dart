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

  @override
  void initState() {
    super.initState();
    _fetchReciters();
  }

  void _fetchReciters() async {
    try {
      final res = await Dio().get("https://mp3quran.net/api/v3/reciters?language=fr");
      if (mounted) {
        setState(() {
          allReciters = res.data['reciters'];
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
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Choisir un récitant", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Chercher un récitant...",
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() {
                filteredReciters = allReciters.where((r) => r['name'].toLowerCase().contains(val.toLowerCase())).toList();
              });
            },
          ),
          const SizedBox(height: 15),
          Expanded(
            child: loading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8A165)))
              : ListView.builder(
                  itemCount: filteredReciters.length,
                  itemBuilder: (context, i) {
                    final r = filteredReciters[i];
                    // API peut retourner des moshaf vides, on vérifie
                    if (r['moshaf'] == null || r['moshaf'].isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final moshaf = r['moshaf'][0];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: Text(r['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(moshaf['name'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFC8A165)),
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
    )
    );
  }
}
