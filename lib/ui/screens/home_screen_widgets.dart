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

class _DribbbleHomeHeader extends StatefulWidget {
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

  @override
  State<_DribbbleHomeHeader> createState() => _DribbbleHomeHeaderState();
}

class _DribbbleHomeHeaderState extends State<_DribbbleHomeHeader> {
  bool _showSalam = false;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _cycleTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() => _showSalam = !_showSalam);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

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
          future: widget.prayerFuture,
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
              stream: widget.pauseTicker || prayers5 == null
                  ? const Stream.empty()
                  : Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) {
                String nextName = '--';
                String nextTime = '--:--';
                Duration rem = Duration.zero;

                if (prayers5 != null) {
                  final idx = widget.activeIndexFromTimes(prayers5);
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
                          child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 1200),
                            transitionBuilder: (child, animation) {
                              final isIncoming =
                                  (child.key == const ValueKey('salam')) == _showSalam;

                              final offsetAnim = animation.drive(
                                Tween<double>(
                                  begin: isIncoming ? 18.0 : 0.0,
                                  end:   isIncoming ? 0.0  : -18.0,
                                ).chain(CurveTween(
                                  curve: isIncoming
                                      ? Curves.easeOutCubic
                                      : Curves.easeInCubic,
                                )),
                              );

                              return FadeTransition(
                                opacity: animation,
                                child: AnimatedBuilder(
                                  animation: offsetAnim,
                                  builder: (_, ch) => Transform.translate(
                                    offset: Offset(0, offsetAnim.value),
                                    child: ch,
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: _showSalam
                                ? Align(
                                    key: const ValueKey('salam'),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Salam Alaykoum',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  )
                                : Column(
                                    key: const ValueKey('info'),
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
                                        onTap: widget.onLocationTap,
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
                          ),   // ClipRect
                        ),     // Expanded
                        _SearchIconButton(onTap: widget.onSearchTap),
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


class _SearchIconButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _SearchIconButton({this.onTap});

  @override
  State<_SearchIconButton> createState() => _SearchIconButtonState();
}

class _SearchIconButtonState extends State<_SearchIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.72), weight: 1),
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 0.5),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward(from: 0).then((_) => widget.onTap?.call());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black.withValues(alpha: 0.78);
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: IconButton(
        onPressed: _onTap,
        icon: Icon(Icons.search_rounded, color: iconColor),
      ),
    );
  }
}

class _NotificationBellButton extends StatefulWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.count,
    required this.onTap,
  });

  @override
  State<_NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _swing;
  late final Animation<double> _badgeScale;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Cloche qui se balance : pivot en haut → gauche → droite → retour, amorti
    _swing = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.22), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.10), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: 0.10, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Badge qui pulse en sync (grossit légèrement au milieu du swing)
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 3),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.count > 0) _scheduleNext();
  }

  void _scheduleNext() {
    final delay = 6 + (DateTime.now().millisecond % 6); // 6–11 s
    _idleTimer = Timer(Duration(seconds: delay), () {
      if (mounted) {
        _ctrl.forward(from: 0).then((_) {
          if (mounted) _scheduleNext();
        });
      }
    });
  }

  @override
  void didUpdateWidget(_NotificationBellButton old) {
    super.didUpdateWidget(old);
    if (widget.count > 0 && old.count == 0) {
      _idleTimer?.cancel();
      _scheduleNext();
    } else if (widget.count == 0) {
      _idleTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black.withValues(alpha: 0.78);

    return AnimatedBuilder(
      animation: _swing,
      builder: (_, child) => Transform.rotate(
        angle: _swing.value,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: widget.onTap,
            icon: Icon(Icons.notifications_none_rounded, color: iconColor),
          ),
          if (widget.count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedBuilder(
                animation: _badgeScale,
                builder: (_, child) => Transform.scale(
                  scale: _badgeScale.value,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

        const SizedBox(height: 12),

        // Radio en vedette
        const _RadioFeaturedSection(),
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



// ─────────────────────────────────────────────────────────────────────────────
// RADIO FEATURED SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _RadioFeaturedSection extends StatefulWidget {
  const _RadioFeaturedSection();

  @override
  State<_RadioFeaturedSection> createState() => _RadioFeaturedSectionState();
}

class _RadioFeaturedSectionState extends State<_RadioFeaturedSection> {
  late final Future<List<RadioStation>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _loadStations();
  }

  Future<List<RadioStation>> _loadStations() async {
    var popular = await RadioService.instance.getPopular(limit: 4);
    if (popular.isEmpty) {
      final all = await RadioService.instance.getStations();
      popular = all.take(4).toList();
    }
    return popular;
  }

  Future<void> _playStation(RadioStation s) async {
    RadioService.instance.currentStationNotifier.value = s;
    await AudioService.instance.playRadio(s);
    await RadioService.instance.trackPlay(s);
  }

  Future<void> _stopStation() async {
    await AudioService.instance.stopRadio();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Radio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => RadioBrowserScreen.show(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2C6CB5),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Tout voir',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<RadioStation>>(
            future: _stationsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 110,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final stations = snap.data ?? [];
              if (stations.isEmpty) return const SizedBox.shrink();

              final featured = stations[0];
              final chips =
                  stations.length > 1 ? stations.sublist(1) : <RadioStation>[];

              return ValueListenableBuilder<RadioStation?>(
                valueListenable: RadioService.instance.currentStationNotifier,
                builder: (_, current, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeaturedStationCard(
                        station: featured,
                        isPlaying: current?.id == featured.id,
                        isDark: isDark,
                        onPlay: () => _playStation(featured),
                        onStop: _stopStation,
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: chips.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _StationChip(
                                  station: s,
                                  isPlaying: current?.id == s.id,
                                  isDark: isDark,
                                  onTap: current?.id == s.id
                                      ? _stopStation
                                      : () => _playStation(s),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturedStationCard extends StatelessWidget {
  final RadioStation station;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const _FeaturedStationCard({
    required this.station,
    required this.isPlaying,
    required this.isDark,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categorizeStation(station);
    final grad = radioCategoryGradient(cat);
    final catLabel =
        cat.contains(' ') ? cat.substring(cat.indexOf(' ') + 1) : cat;

    return GestureDetector(
      onTap: () => RadioBrowserScreen.show(context),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              grad[0].withValues(alpha: isDark ? 0.85 : 1.0),
              grad[1],
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            StationThumbnail(station: station, size: 50, circular: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _RadioTitleMarquee(
                          text: station.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _LiveBadge(isActive: isPlaying),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    catLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isPlaying) const _WaveformBars(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isPlaying ? onStop : onPlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  final RadioStation station;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;

  const _StationChip({
    required this.station,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF4A2E06), Color(0xFF6B4510)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFE8D5B3), Color(0xFFCFAF7E)],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF38C172)
                : const Color(0xFFC8A97E),
            width: isPlaying ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isPlaying
                    ? const Color(0xFF38C172)
                    : const Color(0xFFE74C3C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              station.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE8D5B0)
                    : const Color(0xFF4A3F30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformBars extends StatefulWidget {
  const _WaveformBars();

  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  static const _maxHeights = [16.0, 22.0, 10.0, 20.0];
  static const _durations = [480, 600, 520, 560];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _durations[i]),
      )..repeat(reverse: true);
    });
    _anims = List.generate(4, (i) {
      return Tween<double>(begin: 4, end: _maxHeights[i]).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(4, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i < 3 ? 3.0 : 0),
            child: AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) => Container(
                width: 3,
                height: _anims[i].value,
                decoration: BoxDecoration(
                  color: const Color(0xFF38C172),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final bool isActive;
  const _LiveBadge({required this.isActive});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.isActive
            ? const Color(0xFFE74C3C)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: widget.isActive ? _opacity.value : 1.0,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'EN DIRECT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Marquee scrolling text for long station names
class _RadioTitleMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _RadioTitleMarquee({required this.text, required this.style});

  @override
  State<_RadioTitleMarquee> createState() => _RadioTitleMarqueeState();
}

class _RadioTitleMarqueeState extends State<_RadioTitleMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _startTimer = Timer(const Duration(milliseconds: 1800), _startIfMounted);
  }

  void _startIfMounted() {
    if (mounted) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_RadioTitleMarquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _ctrl.reset();
      _startTimer?.cancel();
      _startTimer = Timer(const Duration(milliseconds: 1800), _startIfMounted);
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);

      final textW = tp.width;
      final boxW  = constraints.maxWidth;

      if (textW <= boxW) {
        return Text(widget.text, style: widget.style, maxLines: 1);
      }

      final overflow = textW - boxW;

      return ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            // 0…0.12  pause at start
            // 0.12…0.80  scroll left
            // 0.80…0.92  pause at end
            // 0.92…1.0  snap back
            final double offset;
            if (t < 0.12) {
              offset = 0;
            } else if (t < 0.80) {
              offset = overflow * (t - 0.12) / 0.68;
            } else if (t < 0.92) {
              offset = overflow;
            } else {
              offset = 0;
            }
            return SizedBox(
              width: boxW,
              child: Transform.translate(
                offset: Offset(-offset, 0),
                child: SizedBox(
                  width: textW,
                  child: Text(
                    widget.text,
                    style: widget.style,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
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
            child: Stack(
              children: [
                ListView.separated(
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
              ],
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
