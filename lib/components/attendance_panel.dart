import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../views/screens/athlete/attendance_history_screen.dart';

/// Combined summary + sliding row of recent attendance.
/// Status values: Present / Absent / Injury / Other Camp.
/// Derived status "Uninformed" is applied when status == Absent AND
/// no absence appeal exists for that session.
class AttendancePanel extends StatelessWidget {
  const AttendancePanel({super.key});

  static const Map<String, _StatusStyle> _styles = {
    'Present': _StatusStyle(
      color: Color(0xFF10B981),
      icon: Icons.check_rounded,
      label: 'Present',
    ),
    'Absent': _StatusStyle(
      color: Color(0xFFEF4444),
      icon: Icons.close_rounded,
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
      label: 'Camp',
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('athleteUid', isEqualTo: uid)
          .orderBy('sessionStartTime', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final present = docs
            .where((d) => (d.data() as Map)['status'] == 'Present')
            .length;
        final total = docs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Color(0xFF667EEA)),
                  const SizedBox(width: 8),
                  const Text(
                    'Attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AttendanceHistoryScreen(),
      ),
    );
  },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See All'),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                total == 0
                    ? 'No sessions recorded yet'
                    : '$present of $total attended recently',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 14),

              // Sliding row of last 5 sessions
              SizedBox(
                height: 84,
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'Attendance will appear here after your first session.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length.clamp(0, 5),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final status =
                              (data['status'] ?? 'Absent').toString();
                          final style =
                              _styles[status] ?? _styles['Absent']!;
                          final date = _fmtDate(data['sessionStartTime']);
                          return Container(
                            width: 72,
                            decoration: BoxDecoration(
                              color: style.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: style.color.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(style.icon,
                                    color: style.color, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: style.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
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
      },
    );
  }

  static String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
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
