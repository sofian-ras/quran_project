import 'package:flutter/material.dart';
import '../services/reading_history_service.dart';
import 'reader_screen.dart';

class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ReadingHistoryService.instance.getHistory(limit: 50);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _openReading(Map<String, dynamic> it) {
    final int page = (it['page'] is int) ? it['page'] as int : int.tryParse('${it['page']}') ?? 1;
    final String reading = (it['reading']?.toString() ?? 'hafs');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialPage: page, reading: reading),
      ),
    );
  }
  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      Duration diff = now.difference(dt);

      // si timestamp futur (rare)
      if (diff.isNegative) diff = diff.abs();

      if (diff.inSeconds < 30) return "à l’instant";
      if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "il y a ${diff.inHours} h";
      if (diff.inDays < 7) return "il y a ${diff.inDays} j";

      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return "$d/$m/$y";
    } catch (_) {
      return "";
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ReadingHistoryService.instance.clearHistory();
              if (!mounted) return;
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Aucune lecture récente'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final String surahName = it['surahName']?.toString() ?? 'Sourate';
                    final int page = (it['page'] is int) ? it['page'] as int : int.tryParse('${it['page']}') ?? 1;
                    final String reading = it['reading']?.toString() ?? 'hafs';
                    final String ts = it['timestamp']?.toString() ?? '';
                    final String rel = ts.isNotEmpty ? _relativeTime(ts) : '';

                    return ListTile(
                      title: Text(surahName),
                      subtitle: Text('Page $page • ${reading.toUpperCase()}${rel.isNotEmpty ? ' • $rel' : ''}'),                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openReading(it),
                    );
                  },
                ),
    );
  }
}
