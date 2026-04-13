part of 'home_screen.dart';

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Text(
      'Ø§Ù„Ù‚Ø±Ø¢Ù† Ø§Ù„ÙƒØ±ÙŠÙ…',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DribbbleHomeHeader extends StatelessWidget {
  final bool pauseTicker;
  final Future<PrayerHeaderData> prayerFuture;
  final int Function(List<(String, String)>) activeIndexFromTimes;
  final VoidCallback? onLocationTap;
  final VoidCallback? onSearchTap;

  const _DribbbleHomeHeader({
    required this.prayerFuture,
    required this.activeIndexFromTimes,
    required this.pauseTicker,
    this.onLocationTap,
    this.onSearchTap,
  });

  static const _gold = Color(0xFFD4AF37);

  static IconData _iconFor(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':    return Icons.wb_twilight_rounded;
      case 'dhuhr':
      case 'dhohr':   return Icons.wb_sunny_outlined;
      case 'asr':     return Icons.wb_sunny;
      case 'maghrib': return Icons.nights_stay_rounded;
      case 'isha':    return Icons.nightlight_round;
      default:        return Icons.access_time_rounded;
    }
  }

  static Duration _remaining(String hhmm) {
    if (!hhmm.contains(':') || hhmm.contains('-')) return Duration.zero;
    final parts = hhmm.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hh, mm);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }

  static String _fmtRemaining(Duration d) {
    if (d <= Duration.zero) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return 'Dans ${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return 'Dans ${m}m ${s.toString().padLeft(2, '0')}s';
    return 'Dans ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;

    final Color accent = isDark ? _gold : const Color(0xFF0E6B63);
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textMuted = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : const Color(0xFF64748B);

    // Container.margin ne supporte pas les valeurs négatives.
    // LayoutBuilder + Transform.translate pour déborder du padding parent (hPad=14).
    return LayoutBuilder(
      builder: (context, constraints) => Transform.translate(
        offset: const Offset(-14, 0),
        child: SizedBox(
          width: constraints.maxWidth + 28,
          child: Container(
            decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF020617),
                  const Color(0xFF0B1025),
                  const Color(0x000B1025),
                ]
              : [
                  const Color(0xFFF2ECE5),
                  const Color(0xFFF2ECE5),
                  const Color(0x00F2ECE5),
                ],
          stops: const [0.0, 0.68, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 10, 12, 32),
        child: FutureBuilder<PrayerHeaderData>(
          future: prayerFuture,
          builder: (context, snap) {
            final data = snap.data;
            final hijriLine = data?.hijriLine ?? '';
            final location = data != null
                ? '${data.city}, ${data.country}'
                : 'Paris, France';

            final prayers5 = data != null && data.times.isNotEmpty
                ? <(String, String)>[
                    ('Fajr',    data.times['Fajr']    ?? '--:--'),
                    ('Dhuhr',   data.times['Dhohr']   ?? '--:--'),
                    ('Asr',     data.times['Asr']     ?? '--:--'),
                    ('Maghrib', data.times['Maghrib'] ?? '--:--'),
                    ('Isha',    data.times['Isha']    ?? '--:--'),
                  ]
                : null;

            return StreamBuilder<int>(
              stream: pauseTicker || prayers5 == null
                  ? const Stream.empty()
                  : Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) {
                String nextName = '--';
                String nextTime = '--:--';
                Duration rem = Duration.zero;

                if (prayers5 != null) {
                  final idx = activeIndexFromTimes(prayers5);
                  nextName = prayers5[idx].$1;
                  nextTime = prayers5[idx].$2;
                  rem = _remaining(nextTime);
                }

                final remLabel = _fmtRemaining(rem);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne 1 : date hijri + lieu + cloche ──────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hijriLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              GestureDetector(
                                onTap: onLocationTap,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place_rounded,
                                        size: 12, color: textMuted),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onSearchTap,
                          icon: Icon(Icons.search_rounded, color: isDark ? Colors.white : Colors.black.withValues(alpha: 0.78)),
                        ),
                        _RadioIconButton(
                          onTap: () => RadioBrowserScreen.show(context),
                        ),
                        _NotificationBellButton(
                          count: 3,
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifications bientôt')),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Ligne 2 : prochaine prière ────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icône dans un pill arrondi
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_iconFor(nextName), color: accent, size: 26),
                        ),
                        const SizedBox(width: 14),
                        // Nom + label
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Prochaine prière',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextName,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Heure + compte à rebours
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PrayersScreen())),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nextTime,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  remLabel,
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),          // closes FutureBuilder
      ),            // closes Padding
          ),        // closes Container
        ),          // closes SizedBox
      ),            // closes Transform.translate
    );              // closes LayoutBuilder
  }
}


class _NotificationBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black.withValues(alpha: 0.78);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(Icons.notifications_none_rounded, color: iconColor),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RadioIconButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RadioIconButton({required this.onTap});

  @override
  State<_RadioIconButton> createState() => _RadioIconButtonState();
}

class _RadioIconButtonState extends State<_RadioIconButton>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>    _shake;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Séquence de rotation : -15° → +15° × 3 → revient à 0
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.26), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.26), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.26, end: -0.26), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.26), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.26, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _scheduleNext();
  }

  void _scheduleNext() {
    // Danse toutes les 8–14 secondes (intervalle variable)
    final delay = 8 + (DateTime.now().millisecond % 7); // 8 à 14 s
    _idleTimer = Timer(Duration(seconds: delay), () {
      if (mounted) {
        _ctrl.forward(from: 0).then((_) {
          if (mounted) _scheduleNext();
        });
      }
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black.withValues(alpha: 0.78);
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.instance.isRadioModeNotifier,
      builder: (_, isRadio, __) => AnimatedBuilder(
        animation: _shake,
        builder: (_, child) => Transform.rotate(
          angle: _shake.value,
          child: child,
        ),
        child: IconButton(
          onPressed: widget.onTap,
          tooltip: 'Radio',
          icon: Icon(
            isRadio ? Icons.radio : Icons.radio_outlined,
            color: isRadio ? const Color(0xFF38C172) : iconColor,
          ),
        ),
      ),
    );
  }
}

class _HeaderWithEngagement extends StatelessWidget {
  final bool pausePrayerTicker;
  final VoidCallback onContinue;
  final Future<PrayerHeaderData> prayerFuture;
  final int Function(List<(String, String)>) activeIndexFromTimes;
  final List<Reciter> reciters;
  final bool recitersLoading;
  final void Function(Reciter) onReciterTap;
  final String Function(String name) getReciterAsset;
  final AudioService audio;
  final VoidCallback? onLocationTap;
  final VoidCallback? onSearchTap;



  const _HeaderWithEngagement({
    required this.audio,
    required this.onContinue,
    required this.prayerFuture,
    required this.activeIndexFromTimes,
    required this.reciters,
    required this.recitersLoading,
    required this.onReciterTap,
    required this.getReciterAsset,
    required this.pausePrayerTicker,
    this.onLocationTap,
    this.onSearchTap,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header prières
        _DribbbleHomeHeader(
          prayerFuture: prayerFuture,
          activeIndexFromTimes: activeIndexFromTimes,
          pauseTicker: pausePrayerTicker,
          onLocationTap: onLocationTap,
          onSearchTap: onSearchTap,
        ),

        const SizedBox(height: 12),

        // Continuer / Reprendre lecture
        const ContinueReadingCard(),

        const SizedBox(height: 12),

        // Reciters
        _HomeCardShell(
          child: _RecitersSection(
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const ReciterPickerScreen(),
                ),
              );
            },
            reciters: reciters,
            onReciterTap: onReciterTap,
            getAssetByName: getReciterAsset,
            isLoading: recitersLoading,
          ),
        ),
      ],
    );
  }
}


class _RecitersSection extends StatefulWidget {
  final VoidCallback onSeeAll;
  final List<Reciter> reciters;
  final void Function(Reciter) onReciterTap;
  final String Function(String name) getAssetByName;
  final bool isLoading;

  const _RecitersSection({
    required this.onSeeAll,
    required this.reciters,
    required this.onReciterTap,
    required this.getAssetByName,
    this.isLoading = false,
  });

  @override
  State<_RecitersSection> createState() => _RecitersSectionState();
}

class _RecitersSectionState extends State<_RecitersSection> {
  late final ScrollController _hCtrl;

  @override
  void initState() {
    super.initState();
    // Empêche la restauration d’un offset horizontal “fantôme”
    _hCtrl = ScrollController(keepScrollOffset: false);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    const linkColor = Color(0xFF2C6CB5);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C3E50),
                  Color(0xFF1A252F),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFEF5E7),
                  Color(0xFFFAE5D3),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reciters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: linkColor,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          SizedBox(
            height: 64,
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
              controller: _hCtrl,
              scrollDirection: Axis.horizontal,
              // Réduit les conflits “scroll vertical” vs “horizontal”
              dragStartBehavior: DragStartBehavior.start,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.reciters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = widget.reciters[i];
                final asset = widget.getAssetByName(r.name);

                return InkWell(
                  onTap: () => widget.onReciterTap(r),
                  borderRadius: BorderRadius.circular(999),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : const Color(0xFF2C6CB5).withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color.fromARGB(255, 255, 251, 243),
                          backgroundImage: asset.isEmpty ? null : AssetImage(asset),
                          onBackgroundImageError: (_, __) {},
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            r.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: titleColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



class _FeatureChipData {
  final String label;
  final String imagePath;

  const _FeatureChipData({required this.label, required this.imagePath});
}

class _ExploreFeaturesSection extends StatelessWidget {
  final List<_FeatureChipData> features;
  final void Function(_FeatureChipData) onTap;

  const _ExploreFeaturesSection({
    required this.features,
    required this.onTap,
  });



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore features',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SizedBox(
            height: 112,
            child: ClipRect(
              child: ShaderMask(
                shaderCallback: (Rect rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.08, 0.92, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  dragStartBehavior: DragStartBehavior.start,
                  scrollDirection: Axis.horizontal,
                  itemCount: features.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = features[i];

                    final pastel = <Color>[
                      const Color(0xFFFFF4CC),
                      const Color(0xFFDFF7E9),
                      const Color(0xFFE3F0FF),
                      const Color(0xFFFFE3E6),
                      const Color(0xFFEDE7FF),
                      const Color(0xFFE7FFF7),
                    ];

                    return SizedBox(
                      width: 180,
                      height: 112,
                      child: _FeatureSquareItem(
                        label: f.label,
                        imagePath: f.imagePath,
                        onTap: () => onTap(f),
                        isDark: isDark,
                        bgColor: pastel[i % pastel.length],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _FeatureChip extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;

  final VoidCallback onTap;

  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF2F6FF);
    final fg = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF111827);
    const accent = Color(0xFF2C6CB5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 18,
              color: accent,
              duotoneSecondaryOpacity: 0.28,
            ),

            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCardData {
  final String title;
  final String subtitle;
  final String imageAsset;

  const _ContentCardData({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
  });
}

class _ContentCardsSection extends StatelessWidget {
  final List<_ContentCardData> items;
  final void Function(_ContentCardData) onTap;

  const _ContentCardsSection({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Programs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(items.length, (i) {
            final item = items[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: _ContentCard(
                item: item,
                onTap: () => onTap(item),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final _ContentCardData item;
  final VoidCallback onTap;

  const _ContentCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    // Bande et texte lisibles en dark/light
    final Color bannerColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.55);

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 10, // ressemble plus au style "tuile" que 16/9
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                item.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black12),
              ),

              // Léger voile (tu peux le supprimer si tu veux l'image plus "crue")
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.03 : 0.06),
                          Colors.transparent,
                          Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bande diagonale translucide
              Align(
                alignment: Alignment.bottomLeft,
                child: ClipPath(
                  clipper: _DiagonalBannerClipper(),
                  child: SizedBox(
                    width: double.infinity,
                    height: 170, // ajuste si tu veux plus/moins
                    child: ColoredBox(color: bannerColor),
                  ),
                ),
              ),

              // Textes (en bas à gauche)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: subTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagonalBannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(0, size.height);
    p.lineTo(0, size.height * 0.55);

    p.quadraticBezierTo(
      size.width * 0.22,
      size.height * 0.62,
      size.width * 0.56,
      size.height * 0.80,
    );

    p.lineTo(size.width, size.height * 0.60);
    p.lineTo(size.width, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _VerseOfTheDayCard extends StatefulWidget {
  const _VerseOfTheDayCard();

  @override
  State<_VerseOfTheDayCard> createState() => _VerseOfTheDayCardState();
}

class _VerseOfTheDayCardState extends State<_VerseOfTheDayCard> {
  String _arabicText = '';
  String _translationText = '';
  int _surahNumber = 1;
  int _verseNumber = 1;
  bool _isLoading = true;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadRandomVerse();
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _loadRandomVerse() async {
    try {
      // Générer un verset aléatoire basé sur la date du jour
      final today = DateTime.now();
      final seed = today.year * 10000 + today.month * 100 + today.day;
      final random = math.Random(seed);
      
      // Sourate aléatoire (1-114)
      _surahNumber = 1 + random.nextInt(114);
      
      // Essayer d'abord avec le pack offline français
      final isReady = await QuranTranslationPackService.isPackReady(AppLang.fr);
      if (isReady) {
        final dbPath = await QuranTranslationPackService.getDbPath(AppLang.fr);
        final db = await openDatabase(dbPath, readOnly: true);
        
        try {
          // Compter les versets de cette sourate
          final countResult = await db.rawQuery(
            'SELECT COUNT(*) as cnt FROM verses WHERE sura = ?',
            [_surahNumber],
          );
          final versesInSurah = (countResult.first['cnt'] as int?) ?? 0;
          
          if (versesInSurah > 0) {
            _verseNumber = 1 + random.nextInt(versesInSurah);
            
            // Récupérer le verset
            final rows = await db.rawQuery(
              'SELECT ar, fr FROM verses WHERE sura = ? AND aya = ?',
              [_surahNumber, _verseNumber],
            );
            
            if (rows.isNotEmpty) {
              final row = rows.first;
              _arabicText = ((row['ar'] as String?) ?? '')
                  .replaceAll('\u200C', '')
                  .replaceAll('\u200D', '')
                  .replaceAll('\u200B', '')
                  .replaceAll('\u200F', '')
                  .replaceAll('\u200E', '')
                  .trim();
              _translationText = (row['fr'] as String?) ?? '';
              if (!mounted) return;
              setState(() => _isLoading = false);
              return;
            }
          }
        } finally {
          await db.close();
        }
      }
      
      // Fallback: utiliser l'API en ligne si le pack offline n'est pas disponible
      final arRes = await _dio.get('https://api.alquran.cloud/v1/surah/$_surahNumber/quran-uthmani');
      final frRes = await _dio.get('https://quranenc.com/api/v1/translation/sura/french_hameedullah/$_surahNumber');
      
      final arAyahs = (arRes.data?['data']?['ayahs'] as List?) ?? [];
      final frData = (frRes.data?['result'] as List?) ?? [];

      if (arAyahs.isNotEmpty && frData.isNotEmpty) {
        _verseNumber = 1 + random.nextInt(arAyahs.length);

        final arText = arAyahs[_verseNumber - 1]['text']?.toString() ?? '';
        final frIdx = (_verseNumber - 1).clamp(0, frData.length - 1);
        final frText = frData[frIdx]['translation']?.toString() ?? '';
        
        _arabicText = arText
            .replaceAll('\u200C', '')
            .replaceAll('\u200D', '')
            .replaceAll('\u200B', '')
            .replaceAll('\u200F', '')
            .replaceAll('\u200E', '')
            .trim();
        _translationText = frText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      // Fallback sur un verset par défaut
      _surahNumber = 2;
      _verseNumber = 286;
      _arabicText = 'لَا يُكَلِّفُ ٱللَّهُ نَفۡسًا إِلَّا وُسۡعَهَاۚ';
      _translationText = 'Allah n\'impose à aucune âme une charge supérieure à sa capacité.';
      
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return SizedBox(
        height: 190,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFEF5E7), Color(0xFFFAE5D3)],
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.orange.shade200).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );

    }

    final surahName = surahFr[_surahNumber] ?? 'Sourate $_surahNumber';
    final arabicColor = isDark ? const Color(0xFFF6E9D7) : const Color(0xFF3D2817);
    final translationColor = isDark ? const Color(0xFFD4C5B0) : const Color(0xFF6B5744);
    const goldColor = Color(0xFFA67C52);

    return SizedBox(
      height: 190,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2C3E50),
                    Color(0xFF1A252F),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFEF5E7),
                    Color(0xFFFAE5D3),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _arabicText,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: 18,
                letterSpacing: 0.0,
                color: arabicColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _translationText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: translationColor,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$surahName $_surahNumber:$_verseNumber',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: goldColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCardShell extends StatelessWidget {
  final Widget child;
  const _HomeCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF0F1734) : Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}


class _FeatureSquareItem extends StatelessWidget {
  final String label;
  final String imagePath;
  final VoidCallback onTap;
  final bool isDark;
  final Color bgColor;

  const _FeatureSquareItem({
    required this.label,
    required this.imagePath,
    required this.onTap,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color labelColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF374151);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black12,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: labelColor,
                      ),
                    );
                  },
                ),
              ),
              // Voile léger comme Programs
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.03 : 0.06),
                          Colors.transparent,
                          Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bande diagonale translucide en bas à gauche (collée en bas)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: _DiagonalBannerClipper(),
                  child: Container(
                    height: 70, // bande encore plus large
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
              // Titre bien en bas à gauche sur la bande
              Positioned(
                left: 14,
                bottom: 4,
                right: 16,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


// Model local à home_screen (différent de _HomeMoshafServer dans reciter_picker_screen)
class _HomeMoshafServer {
  final int id;
  final String name;
  final String server;
  final int surahTotal;

  const _HomeMoshafServer({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
  });
}
