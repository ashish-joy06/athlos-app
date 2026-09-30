import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Full-screen attendance history.
/// Reads from the `attendance` collection for the current athlete.
/// Status values supported:
///   Present  (green)   — attended
///   Absent   (red)     — missed, an approved appeal exists
///   Injury   (orange)  — injured / medically excused
///   Other Camp (blue)  — away at another camp
///   Uninformed (yellow) — Absent with NO prior appeal (auto-derived)
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  static const Map<String, _StatusStyle> _styles = {
    'Present': _StatusStyle(
      color: Color(0xFF10B981),
      icon: Icons.check_circle_rounded,
      label: 'Present',
    ),
    'Absent': _StatusStyle(
      color: Color(0xFFEF4444),
      icon: Icons.cancel_rounded,
      label: 'Absent',
    ),
    'Injury': _StatusStyle(
      color: Color(0xFFF97316),
      icon: Icons.healing_rounded,
      label: 'Injury',
    ),
    'Other Camp': _StatusStyle(
      color: Color(0xFF3B82F6),
      icon: Icons.campaign_rounded,
      label: 'Other Camp',
    ),
    'Uninformed': _StatusStyle(
      color: Color(0xFFFACC15),
      icon: Icons.warning_amber_rounded,
      label: 'Uninformed',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('athleteUid', isEqualTo: uid)
            .orderBy('sessionStartTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No attendance records yet.\nYour history will appear here after your first session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final rawStatus = (data['status'] ?? 'Absent').toString();
              // If the status is Absent but there is NO appeal, label it
              // "Uninformed". We detect this via a stored flag on the doc:
              //   data['hasAppeal'] == true  →  Absent (with appeal)
              //   data['hasAppeal'] == false →  Uninformed
              // If the flag is absent, we fall back to the raw status.
              String displayStatus = rawStatus;
              if (rawStatus == 'Absent') {
                final hasAppeal = data['hasAppeal'];
                if (hasAppeal == false || hasAppeal == null) {
                  displayStatus = 'Uninformed';
                }
              }

              final style =
                  _styles[displayStatus] ?? _styles['Uninformed']!;
              final title = data['sessionTitle'] ?? 'Training Session';
              final date = _fmtDate(data['sessionStartTime']);
              final location = data['location'] ?? '';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: style.color.withOpacity(0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          if (location.toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              location.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: style.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }
    return '';
  }
}

class _StatusStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}