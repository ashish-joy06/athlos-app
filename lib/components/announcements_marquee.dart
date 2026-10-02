import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../views/screens/announcements_inbox_screen.dart';

/// Scrolling marquee that shows the latest announcement visible to the user.
/// Tapping the card (or the history icon on the right) opens the full inbox.
class AnnouncementsMarquee extends StatefulWidget {
  const AnnouncementsMarquee({super.key});

  @override
  State<AnnouncementsMarquee> createState() => _AnnouncementsMarqueeState();
}

class _AnnouncementsMarqueeState extends State<AnnouncementsMarquee> {
  String? _mySport;

  @override
  void initState() {
    super.initState();
    _loadSport();
  }

  Future<void> _loadSport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _mySport = (doc.data()?['sport'] ?? 'Athletics').toString();
    });
  }

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnnouncementsInboxScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openInbox,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9B0), Color(0xFFFFD166)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  final text = _pickText(snapshot);
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
            const SizedBox(width: 8),
            // History icon — tapping the card also opens the inbox,
            // but this gives an explicit affordance.
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 16,
                color: Color(0xFF8A5A00),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pickText(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return 'No announcements yet — stay tuned!';
    }
    for (final doc in snapshot.data!.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final annSport = data['sport'];
      final visible = annSport == null ||
          _mySport == null ||
          annSport == _mySport;
      if (visible) {
        final msg = (data['message'] ?? '').toString();
        final title = (data['title'] ?? '').toString();
        if (title.isNotEmpty && msg.isNotEmpty) return '$title — $msg';
        return msg.isNotEmpty ? msg : title;
      }
    }
    return 'No announcements for your sport yet.';
  }
}