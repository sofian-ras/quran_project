import 'package:flutter/material.dart';
import '../../models/announcement.dart';
import '../../services/announcements_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Announcement>? _items;
  Set<String> _readIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items   = await AnnouncementsService.instance.getAll();
    final futures = items.map((a) => AnnouncementsService.instance.isRead(a.id));
    final reads   = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _items   = items;
      _readIds = {
        for (var i = 0; i < items.length; i++)
          if (reads[i]) items[i].id,
      };
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await AnnouncementsService.instance.markAllRead();
    if (!mounted) return;
    setState(() {
      _readIds = _items?.map((a) => a.id).toSet() ?? {};
    });
  }

  Future<void> _markRead(String id) async {
    await AnnouncementsService.instance.markRead(id);
    if (!mounted) return;
    setState(() => _readIds.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final t      = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final unread = _items?.where((a) => !_readIds.contains(a.id)).length ?? 0;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: t.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Notifications',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Tout lire',
                style: TextStyle(
                  color: isDark ? const Color(0xFFC8A165) : const Color(0xFF0E6B63),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items == null || _items!.isEmpty
              ? _EmptyState(isDark: isDark)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _items!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a      = _items![i];
                    final isRead = _readIds.contains(a.id);
                    return _AnnouncementCard(
                      item:    a,
                      isRead:  isRead,
                      isDark:  isDark,
                      onTap:   () => _markRead(a.id),
                    );
                  },
                ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Announcement item;
  final bool isRead;
  final bool isDark;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.item,
    required this.isRead,
    required this.isDark,
    required this.onTap,
  });

  static const _gold    = Color(0xFFC8A165);
  static const _teal    = Color(0xFF0E6B63);
  static const _orange  = Color(0xFFE87722);
  static const _red     = Color(0xFFE53935);

  Color _iconColor() {
    switch (item.type) {
      case AnnouncementType.newFeature: return _gold;
      case AnnouncementType.streak:     return _orange;
      case AnnouncementType.warning:    return _red;
      case AnnouncementType.tip:
      case AnnouncementType.info:
        return isDark ? _gold : _teal;
    }
  }

  IconData _icon() {
    switch (item.type) {
      case AnnouncementType.newFeature: return Icons.new_releases_rounded;
      case AnnouncementType.streak:     return Icons.local_fire_department_rounded;
      case AnnouncementType.warning:    return Icons.warning_amber_rounded;
      case AnnouncementType.tip:        return Icons.lightbulb_outline_rounded;
      case AnnouncementType.info:       return Icons.info_outline_rounded;
    }
  }

  String _relativeDate() {
    final diff = DateTime.now().difference(item.date);
    if (diff.inMinutes < 1)  return "À l'instant";
    if (diff.inHours < 1)    return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1)     return "Aujourd'hui";
    if (diff.inDays == 1)    return 'Hier';
    if (diff.inDays < 7)     return 'Il y a ${diff.inDays} jours';
    if (diff.inDays < 30)    return 'Il y a ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365)   return 'Il y a ${(diff.inDays / 30).floor()} mois';
    return 'Il y a ${(diff.inDays / 365).floor()} an(s)';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? (isRead
            ? const Color(0xFF0F172A)
            : const Color(0xFF1A2438))
        : (isRead
            ? const Color(0xFFF8F8F8)
            : Colors.white);

    final iconColor  = _iconColor();
    final borderColor = isRead
        ? Colors.transparent
        : iconColor.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: isRead ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                    color: iconColor.withValues(alpha: isDark ? 0.10 : 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(), color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.60)
                          : const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeDate(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFFADB5BD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Pas de notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.40)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Revenez plus tard',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }
}
