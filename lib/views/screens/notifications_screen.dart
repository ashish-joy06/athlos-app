import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'athlete/attendance_history_screen.dart';

/// Lists every notification addressed to the current user, newest first.
/// Unread rows have a colored left border; read rows are muted.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Map<String, _NotifStyle> _styles = {
    'session': _NotifStyle(
      icon: Icons.event_available_rounded,
      color: Color(0xFF667EEA),
    ),
    'announcement': _NotifStyle(
      icon: Icons.campaign_rounded,
      color: Color(0xFFF59E0B),
    ),
    'attendance': _NotifStyle(
      icon: Icons.how_to_reg_rounded,
      color: Color(0xFF10B981),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _markAllRead(uid),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Mark all read'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF667EEA),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notifications yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 1),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _NotifTile(doc: doc, data: data);
            },
          );
        },
      ),
    );
  }

  static Future<void> _markAllRead(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}

class _NotifTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  const _NotifTile({required this.doc, required this.data});

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] ?? 'announcement').toString();
    final style = NotificationsScreen._styles[type] ??
        const _NotifStyle(
          icon: Icons.notifications_rounded,
          color: Color(0xFF667EEA),
        );
    final isUnread = data['read'] != true;
    final title = (data['title'] ?? 'Notification').toString();
    final body = (data['body'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final rel = _relativeTime(createdAt);

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFEF4444),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        await doc.reference.delete();
      },
      child: InkWell(
        onTap: () async {
  if (isUnread) {
    await doc.reference.update({'read': true});
  }
  if (!context.mounted) return;
  _handleDeepLink(context, type, data);
},
        child: Container(
          color: isUnread ? Colors.white : Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left border for unread
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnread ? style.color : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
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
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isUnread
                                  ? const Color(0xFF1A202C)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (rel.isNotEmpty)
                          Text(
                            rel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread
                            ? Colors.black87
                            : Colors.grey.shade600,
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

  static void _handleDeepLink(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case 'attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AttendanceHistoryScreen(),
          ),
        );
        break;
      case 'session':
        // Future: open the calendar to the session's date.
        // For now, just pop back to the dashboard.
        Navigator.pop(context);
        break;
      default:
        // Announcements and unknown types: just mark as read.
        break;
    }
  }

  static String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  const _NotifStyle({required this.icon, required this.color});
}