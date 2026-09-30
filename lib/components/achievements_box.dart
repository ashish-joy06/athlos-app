import 'package:flutter/material.dart';

/// Small rectangular "Achievements" card, positioned bottom-right in the
/// dashboard. Contents are TBD — see TODO below.
class AchievementsBox extends StatelessWidget {
  const AchievementsBox({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO (revisit): populate this card with actual achievements.
    // Possible sources:
    //   a) Hardcoded list per user (simplest, for a demo)
    //   b) Firestore `achievements` collection, awarded by coaches/admins
    //   c) Auto-computed from attendance %, personal bests, session streaks
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 230,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4D6), Color(0xFFFFE0A3)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFB45309),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C2D12),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'View all',
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.black.withOpacity(0.4),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}