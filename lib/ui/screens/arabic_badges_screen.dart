import 'package:flutter/material.dart';
import '../../data/arabic_curriculum.dart';
import '../../models/arabic_models.dart';

// ─── Palette ──────────────────────────────────────────────────────────────

const _kGold = Color(0xFFC8A97E);
const _kSepia = Color(0xFF4A3F30);

class ArabicBadgesScreen extends StatelessWidget {
  final ArabicStats stats;
  const ArabicBadgesScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1223) : const Color(0xFFF0EDE6);
    final textColor = isDark ? const Color(0xFFD4C5A3) : _kSepia;
    final unlockedIds = stats.unlockedBadgeIds;
    final unlockedCount = kArabicBadges.where((b) => unlockedIds.contains(b.id)).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B6C35),
        foregroundColor: Colors.white,
        title: const Text('Mes Badges', style: TextStyle(color: Color(0xFFEDE0C0))),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGold.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / ${kArabicBadges.length} badges débloqués',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: kArabicBadges.isEmpty
                              ? 0
                              : unlockedCount / kArabicBadges.length,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? const Color(0xFF2A3A4A)
                              : const Color(0xFFD5C9BB),
                          valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Badge grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: kArabicBadges.length,
              itemBuilder: (_, i) {
                final badge = kArabicBadges[i];
                final unlocked = unlockedIds.contains(badge.id);
                return _BadgeCard(
                  badge: badge,
                  unlocked: unlocked,
                  isDark: isDark,
                  textColor: textColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final ArabicBadge badge;
  final bool unlocked, isDark;
  final Color textColor;

  const _BadgeCard({
    required this.badge,
    required this.unlocked,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    final borderColor = unlocked ? _kGold : Colors.grey.withAlpha(80);
    final emojiOpacity = unlocked ? 1.0 : 0.3;
    final titleColor = unlocked ? textColor : Colors.grey;
    final descColor = unlocked
        ? textColor.withAlpha(180)
        : Colors.grey.withAlpha(120);

    return GestureDetector(
      onTap: () => _showBadgeSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked ? cardBg : cardBg.withAlpha(180),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: unlocked
              ? [BoxShadow(color: _kGold.withAlpha(30), blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: emojiOpacity,
              child: Text(badge.emoji, style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 10),
            Text(
              badge.titleFr,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            if (!unlocked)
              Text(
                '???',
                style: TextStyle(color: descColor, fontSize: 11),
              )
            else
              Text(
                badge.description,
                style: TextStyle(color: descColor, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _kGold.withAlpha(80)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: _kGold.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 20),
            Opacity(
              opacity: unlocked ? 1.0 : 0.35,
              child: Text(badge.emoji, style: const TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 12),
            Text(
              badge.titleFr,
              style: TextStyle(
                color: isDark ? const Color(0xFFD4C5A3) : _kSepia,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: unlocked ? _kGold.withAlpha(30) : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unlocked ? '✓ Débloqué' : '🔒 Verrouillé',
                style: TextStyle(
                  color: unlocked ? _kGold : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              unlocked ? badge.description : 'Condition : ${badge.condition}',
              style: TextStyle(
                color: (isDark ? const Color(0xFFD4C5A3) : _kSepia).withAlpha(180),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
