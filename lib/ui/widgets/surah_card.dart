import 'package:flutter/material.dart';

class SurahCard extends StatelessWidget {
  final int id;
  final String nameAr;
  final String nameFr;
  final int ayahCount;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleFavorite;

  const SurahCard({
    super.key,
    required this.id,
    required this.nameAr,
    required this.nameFr,
    this.ayahCount = 0,
    this.isFavorite = false,
    this.onTap,
    this.onPlay,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
  const gold = Color(0xFFC8A165);
  const darkGreen = Color(0xFF0B3D2E);

    return Card(
      color: darkGreen,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [darkGreen, Colors.green.shade700]),
                  border: Border.all(color: gold, width: 1.5),
                ),
                child: Center(child: Text('$id', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nameAr, style: const TextStyle(fontFamily: 'Amiri', fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(nameFr, style: const TextStyle(fontSize: 14, color: Color(0xFFC8A165))),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (ayahCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: Text('$ayahCount ayah', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_outline, color: Colors.white70),
                onPressed: onPlay,
              ),
              IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? gold : Colors.white70),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
