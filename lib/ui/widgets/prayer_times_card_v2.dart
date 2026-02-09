import 'dart:math' as math;
import 'package:flutter/material.dart';

class PrayerTimesCardV2 extends StatelessWidget {
  final String nextPrayerName;
  final String nextPrayerTime;
  final Duration remaining;
  final List<(String, String)> prayers; // ex: [(Fajr, 05:28), ...]
  final int activeIndex;
  final String? location;
  final VoidCallback? onLocationTap;
  final VoidCallback? onExpandTap;

  const PrayerTimesCardV2({
    super.key,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.remaining,
    required this.prayers,
    required this.activeIndex,
    this.location,
    this.onLocationTap,
    this.onExpandTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cardH = (w * 0.56).clamp(196.0, 245.0);

        final titleSize = (w * 0.048).clamp(13.0, 16.0);
        final timeSize = (w * 0.16).clamp(30.0, 56.0);
        final subSize = (w * 0.042).clamp(11.0, 14.0);
        final itemLabelSize = (w * 0.033).clamp(9.0, 12.0);
        final itemTimeSize = (w * 0.038).clamp(10.0, 13.5);

        return SizedBox(
          height: cardH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // fond
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0E6B63),
                            const Color(0xFF0B4F4A),
                            const Color(0xFF083B37),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // étoiles discrètes
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _StarfieldPainter(),
                      ),
                    ),
                  ),

                  // halo "soleil" au centre
                  Positioned(
                    left: 0,
                    right: 0,
                    top: cardH * 0.18,
                    child: Center(
                      child: Container(
                        width: w * 0.42,
                        height: w * 0.42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFFFFD37A),
                              Color(0x88FFD37A),
                              Color(0x00FFD37A),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // silhouette mosquée (si l'asset existe)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: 0.28,
                          child: Image.asset(
                            'assets/images/prieres/mosquee.png',
                            fit: BoxFit.contain,
                            width: w * 0.82,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // contenu
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _iconFor(nextPrayerName),
                              size: 17,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Prochaine prière: $nextPrayerName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: titleSize,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onExpandTap,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),

                        if ((location ?? '').isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: onLocationTap,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 6, right: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.place_rounded,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      location!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                        fontSize: (w * 0.035).clamp(10.0, 12.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        const Spacer(),

                        Text(
                          nextPrayerTime,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: timeSize,
                            height: 0.95,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _remainingLabel(remaining),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: subSize,
                          ),
                        ),

                        const Spacer(),

                        // barre du bas
                        _BottomTimesBar(
                          prayers: prayers,
                          activeIndex: activeIndex,
                          labelSize: itemLabelSize,
                          timeSize: itemTimeSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _remainingLabel(Duration d) {
    if (d.isNegative) return 'La prière a commencé';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return 'Dans ${h}h ${m}m';
    return 'Dans ${m}m';
  }

  static IconData _iconFor(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_rounded;
      case 'dhuhr':
      case 'dhohr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.wb_sunny;
      case 'maghrib':
        return Icons.nights_stay_rounded;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }
}

class _BottomTimesBar extends StatelessWidget {
  final List<(String, String)> prayers;
  final int activeIndex;
  final double labelSize;
  final double timeSize;

  const _BottomTimesBar({
    required this.prayers,
    required this.activeIndex,
    required this.labelSize,
    required this.timeSize,
  });

  String _label(String raw) {
    final n = raw.toLowerCase();
    if (n == 'dhohr') return 'Dhuhr';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Row(
        children: List.generate(prayers.length, (i) {
          final p = prayers[i];
          final isActive = i == activeIndex;

          return Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isActive
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFD37A),
                                Color(0xFFB07D2A),
                              ],
                            )
                          : null,
                      color: isActive ? null : Colors.transparent,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _label(p.$1),
                            style: TextStyle(
                              color: isActive ? const Color(0xFF163B38) : Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: labelSize,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.$2,
                            style: TextStyle(
                              color: isActive ? const Color(0xFF163B38) : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: timeSize,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (isActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(18, 9),
                        painter: _TrianglePainter(const Color(0xFFFFD37A)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.07);

    // pseudo-random stable (pas de Random() pour éviter des rebuilds différents)
    final int count = (size.width * size.height / 4500).clamp(30, 110).toInt();
    for (int i = 0; i < count; i++) {
      final x = _hash01(i * 13.1) * size.width;
      final y = _hash01(i * 9.7 + 4.2) * (size.height * 0.72);
      final r = _hash01(i * 3.3 + 1.1) * 1.4 + 0.2;
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  double _hash01(double v) {
    return (math.sin(v) * 43758.5453).abs() % 1.0;
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}
