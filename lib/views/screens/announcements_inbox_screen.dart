import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lists every announcement visible to the current user (sport-scoped),
/// newest first. Coaches in the same sport and admins can delete.
class AnnouncementsInboxScreen extends StatefulWidget {
  const AnnouncementsInboxScreen({super.key});

  @override
  State<AnnouncementsInboxScreen> createState() =>
      _AnnouncementsInboxScreenState();
}

class _AnnouncementsInboxScreenState extends State<AnnouncementsInboxScreen> {
  String? _myUid;
  String? _mySport;
  String? _myRole;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _myUid = uid;
      _mySport = (data['sport'] ?? 'Athletics').toString();
      _myRole = (data['role'] ?? 'Athlete').toString();
      _loading = false;
    });
  }

  bool _canDelete(Map<String, dynamic> data) {
    if (_myRole == 'Admin') return true;
    if (_myRole == 'Coach') {
      final annSport = data['sport'];
      // Coach can delete if same sport OR if they were the author
      if (data['authorUid'] == _myUid) return true;
      if (annSport != null && annSport == _mySport) return true;
    }
    // Authors (even athletes, if allowed to post) can delete their own
    return data['authorUid'] == _myUid;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
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

          // Filter by visibility (sport scoping)
          final visible = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final annSport = data['sport'];
            // Admin announcements (sport == null) are visible to all
            if (annSport == null) return true;
            return annSport == _mySport;
          }).toList();

          if (visible.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No announcements yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final doc = visible[i];
              final data = doc.data() as Map<String, dynamic>;
              return _AnnouncementCard(
                doc: doc,
                data: data,
                canDelete: _canDelete(data),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final bool canDelete;

  const _AnnouncementCard({
    required this.doc,
    required this.data,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
    final message = (data['message'] ?? '').toString();
    final authorName = (data['authorName'] ?? 'Unknown').toString();
    final authorRole = (data['authorRole'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final timeStr = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt)
        : '';

    return Dismissible(
      key: ValueKey(doc.id),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        color: const Color(0xFFEF4444),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (!canDelete) return false;
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete announcement?'),
                content: Text(
                    'Delete "${title.isNotEmpty ? title : 'this announcement'}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await doc.reference.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement deleted')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: const Color(0xFFF59E0B), width: 5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : 'Announcement',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ),
                if (canDelete)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete announcement?'),
                            content: const Text(
                                'This will remove it for all users.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await doc.reference.delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Announcement deleted')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$authorName${authorRole.isNotEmpty ? ' • $authorRole' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Spacer(),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}