import 'package:flutter/material.dart';
import '../../surah_name.dart';

class SurahSelectorSheet extends StatefulWidget {
  final Function(int) onSelected;
  const SurahSelectorSheet({super.key, required this.onSelected});

  @override
  State<SurahSelectorSheet> createState() => _SurahSelectorSheetState();
}

class _SurahSelectorSheetState extends State<SurahSelectorSheet> {
  List<Map<String, dynamic>> surahs = [];

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  void _loadSurahs() {
    setState(() {
      surahs = List.generate(114, (index) {
        final id = index + 1;
        return {
          'id': id,
          'nameAr': 'سورة ${surahFr[id] ?? 'Sourate $id'}',
          'nameFr': surahFr[id] ?? 'Sourate $id',
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Choisir une sourate",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      surah['nameAr'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      surah['nameFr'],
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.play_circle_outline,
                      color: Color(0xFFC8A165),
                    ),
                    onTap: () => widget.onSelected(surah['id']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
