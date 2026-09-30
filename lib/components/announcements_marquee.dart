import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// A scrolling marquee that shows the latest announcement.
/// Reads from the `announcements` collection (newest first).
/// Falls back to a placeholder if the collection is empty.
class AnnouncementsMarquee extends StatelessWidget {
  const AnnouncementsMarquee({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9B0), Color(0xFFFFD166)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                final text = _extractText(snapshot);
                return SizedBox(
                  height: 20,
                  child: Marquee(
                    text: text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3000),
                    ),
                    scrollAxis: Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    blankSpace: 60.0,
                    velocity: 40.0,
                    pauseAfterRound: const Duration(seconds: 1),
                    startPadding: 10.0,
                    accelerationDuration: const Duration(seconds: 1),
                    accelerationCurve: Curves.linear,
                    decelerationDuration: const Duration(milliseconds: 500),
                    decelerationCurve: Curves.easeOut,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _extractText(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return 'No announcements yet — stay tuned!';
    }
    final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
    return (data['message'] ?? data['title'] ?? 'Announcement').toString();
  }
}