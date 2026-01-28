import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/audio_service.dart';
import 'reciter_selector.dart';

// Widget RÃ©citateur
class ReciterWidget extends StatelessWidget {
  const ReciterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AudioService audio = AudioService.instance;
    final Color accentText = Colors.white;
    final Color accentGlow = const Color(0xFF38C172);
    final List<Shadow> reliefShadows = const [
      Shadow(color: Colors.black45, offset: Offset(0.6, 0.6), blurRadius: 1.5),
    ];

    return Stack(
      children: [
        // Container principal avec dÃ©corations
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0B3D1F),
                Color(0xFF0F5A2A),
                Color(0xFF137A3B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.black.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B3D1F).withOpacity(0.45),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image et nom du rÃ©citateur
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: audio.currentReciterNotifier,
                  builder: (context, reciterName, _) {
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ReciterSelectorSheet(
                            onSelected: (name, server) {
                              audio.setReciter(name, server);
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          // Avatar du rÃ©citateur
                          Icon(
                            Icons.person,
                            color: accentText,
                            size: 20,
                            shadows: reliefShadows,
                          ),
                          const SizedBox(width: 8),

                          // Nom du rÃ©citateur
                          Expanded(
                            child: Align(
                              alignment: const Alignment(-0.5, -0.2),
                              child: Text(
                                reciterName,
                                style: TextStyle(
                                  color: accentText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: reliefShadows,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Bouton Play
              StreamBuilder<PlayerState>(
                stream: audio.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;

                  return InkWell(
                    onTap: () {
                      if (isPlaying) {
                        audio.pause();
                      } else {
                        // Si rien n'est en cours, lancer la premiÃ¨re sourate
                        if (audio.currentSurahId == null) {
                          audio.loadPlaylistAndPlay(1);
                        } else {
                          audio.play();
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.12),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F5A2A).withOpacity(0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Traits dorÃ©s dÃ©coratifs au milieu du widget
        // CÃ´tÃ© gauche/centre
        Positioned(
          top: 15,
          left: 25,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                    const Color(0xFFFFFFFF).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          top: 28,
          left: 32,
          child: Transform.rotate(
            angle: -0.3,
            child: Container(
              width: 30,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                    const Color(0xFFFFFFFF).withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 35,
          left: 60,
          child: Transform.rotate(
            angle: 0.4,
            child: Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.7),
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // CÃ´tÃ© bas/centre
        Positioned(
          bottom: 15,
          left: 25,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                    const Color(0xFFFFFFFF).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 28,
          left: 30,
          child: Transform.rotate(
            angle: 0.3,
            child: Container(
              width: 35,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                    const Color(0xFFFFFFFF).withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 35,
          left: 55,
          child: Transform.rotate(
            angle: -0.5,
            child: Container(
              width: 45,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.8),
                    const Color(0xFFFFFFFF).withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // Points et ornements dorÃ©s au centre
        Positioned(
          top: 25,
          left: 20,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFFFF).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 50,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 25,
          left: 22,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFFFF).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 65,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 80,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 45,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
