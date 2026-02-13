import 'package:flutter/material.dart';
import 'mini_audio_player.dart';

class GlobalMiniPlayerOverlay extends StatelessWidget {
  final Widget child;
  const GlobalMiniPlayerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: MiniAudioPlayer(),
          ),
        ),
      ],
    );
  }
}