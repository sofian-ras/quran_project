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
    const green = Color(0xFF1F8F4A);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? const Color(0xFF0B3D1F).withOpacity(0.92)
        : const Color(0xFF0B3D1F).withOpacity(0.65);

    final border = isDark ? green.withOpacity(0.45) : green.withOpacity(0.7);

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
                color: green.withOpacity(isDark ? 0.30 : 0.35),
                blurRadius: 14,
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
                  color: green.withOpacity(isDark ? 0.25 : 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: green, size: 20),
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
                            color: const Color(0xFFD4AF37),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$surahCount sourates',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB88A2B),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? green.withOpacity(0.8) : const Color(0xFF0B5A2A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
