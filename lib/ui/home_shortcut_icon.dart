import 'package:flutter/material.dart';

class HomeShortcutIcon extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const HomeShortcutIcon({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              asset,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}