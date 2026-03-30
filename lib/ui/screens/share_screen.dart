import 'package:flutter/material.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partage'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('Écran Partage (bientôt)'),
      ),
    );
  }
}
