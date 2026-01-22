import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/audio_service.dart';

class ReciterSelectorSheet extends StatefulWidget {
  final Function(String name, String server) onReciterSelected;

  const ReciterSelectorSheet({
    required this.onReciterSelected,
    super.key,
  });

  @override
  State<ReciterSelectorSheet> createState() => _ReciterSelectorSheetState();
}

class _ReciterSelectorSheetState extends State<ReciterSelectorSheet> {
  List reciters = [];
  List filtered = [];
  bool loading = true;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReciters();
  }

  Future<void> _fetchReciters() async {
    try {
      final res = await Dio().get(
        "https://api.quranicaudio.com/api/v1/reciters",
      );

      setState(() {
        reciters = res.data['data']; // tous les récitateurs
        filtered = reciters;
        loading = false;
      });
    } catch (e) {
      debugPrint("Erreur API reciters: $e");
      setState(() => loading = false);
    }
  }

  void _onSearchChanged(String q) {
    final t = q.trim().toLowerCase();
    setState(() {
      filtered = t.isEmpty
          ? List.from(reciters)
          : reciters.where((r) {
              final name = (r['name'] ?? '').toString().toLowerCase();
              return name.contains(t);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "Choisir un récitant",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: "Rechercher un récitant",
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFC8A165),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final r = filtered[i];
                      final name = r['name'] ?? "Récitant";
                      final server = r['server'] ?? "";
                      return ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          server,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () {
                          widget.onReciterSelected(name, server);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
