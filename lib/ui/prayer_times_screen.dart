import 'package:flutter/material.dart';

import 'widgets/prayer_times_card.dart';

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: SizedBox.expand(
        child: PrayerTimesCard(topInset: kToolbarHeight),
      ),
    );
  }
}
