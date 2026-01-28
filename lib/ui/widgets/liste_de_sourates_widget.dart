import 'package:flutter/material.dart';

class ListeDeSouratesWidget extends StatelessWidget {
  final int surahCount;
  final VoidCallback onTap;

  const ListeDeSouratesWidget({
    super.key,
    required this.surahCount,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F5A2A);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? const Color(0xFF0B3D1F).withOpacity(0.9)
        : const Color(0xFF0F5A2A);

    final border = Colors.black.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B3D1F).withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liste des sourates',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$surahCount sourates',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
