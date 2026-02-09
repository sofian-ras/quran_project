import 'package:flutter/material.dart';

class PopularClip {
  final String title;
  final String? imageUrl;
  final IconData? icon;
  final VoidCallback? onTap;

  const PopularClip({
    required this.title,
    this.imageUrl,
    this.icon,
    this.onTap,
  });
}

class PopularClipsCarousel extends StatefulWidget {
  final List<PopularClip> clips;
  final double height;
  final double viewportFraction;
  final Color? activeDotColor;
  final Color? dotColor;

  const PopularClipsCarousel({
    super.key,
    required this.clips,
    this.height = 108,
    this.viewportFraction = 0.46,
    this.activeDotColor,
    this.dotColor,
  });

  @override
  State<PopularClipsCarousel> createState() => _PopularClipsCarouselState();
}

class _PopularClipsCarouselState extends State<PopularClipsCarousel> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _controller.page;
    if (p == null) return;
    if (!mounted) return;
    setState(() => _page = p);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clips = widget.clips;
    if (clips.isEmpty) return const SizedBox.shrink();

    final activeIndex = _page.round().clamp(0, clips.length - 1);

    final activeColor = widget.activeDotColor ?? const Color(0xFF1FA36A);
    final dotColor = widget.dotColor ?? Colors.black.withOpacity(0.20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: clips.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final distance = (_page - index).abs();
              final scale = (1 - (distance * 0.06)).clamp(0.92, 1.0);

              return Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _ClipCard(clip: clips[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _Dots(
          count: clips.length,
          activeIndex: activeIndex,
          activeColor: activeColor,
          color: dotColor,
        ),
      ],
    );
  }
}

class _ClipCard extends StatelessWidget {
  final PopularClip clip;
  const _ClipCard({required this.clip});

  @override
  Widget build(BuildContext context) {
    final onTap = clip.onTap;
    final borderRadius = BorderRadius.circular(14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ClipBackground(clip: clip),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    clip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipBackground extends StatelessWidget {
  final PopularClip clip;
  const _ClipBackground({required this.clip});

  @override
  Widget build(BuildContext context) {
    final url = clip.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackBackground(icon: clip.icon),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _FallbackBackground(icon: clip.icon);
        },
      );
    }
    return _FallbackBackground(icon: clip.icon);
  }
}

class _FallbackBackground extends StatelessWidget {
  final IconData? icon;
  const _FallbackBackground({this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1FA36A).withOpacity(0.85),
            const Color(0xFF0E6C7A).withOpacity(0.85),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon ?? Icons.play_circle_fill_rounded,
          size: 38,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final Color activeColor;
  final Color color;

  const _Dots({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: isActive ? 16 : 6,
          decoration: BoxDecoration(
            color: isActive ? activeColor : color,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
