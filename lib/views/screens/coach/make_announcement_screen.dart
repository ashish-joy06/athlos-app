import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/notification_dispatcher.dart';

/// Screen used by coaches and admins to post an announcement.
/// - Admin announcements have `sport: null` → visible to everyone
/// - Coach announcements have `sport: <their sport>` → visible only to
///   athletes in that sport.
class MakeAnnouncementScreen extends StatefulWidget {
  const MakeAnnouncementScreen({super.key});

  @override
  State<MakeAnnouncementScreen> createState() => _MakeAnnouncementScreenState();
}

class _MakeAnnouncementScreenState extends State<MakeAnnouncementScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required')),
      );
      return;
    }
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final role = (data['role'] ?? 'Coach').toString();
    final name = (data['name'] ?? 'User').toString();
    final sport = role == 'Admin' ? null : (data['sport'] ?? 'Athletics').toString();

    final docRef =
    await FirebaseFirestore.instance.collection('announcements').add({
  'title': title,
  'message': message,
  'authorUid': user.uid,
  'authorName': name,
  'authorRole': role,
  'sport': sport,
  'createdAt': Timestamp.now(),
});

// Notify the audience.
await NotificationDispatcher.onAnnouncementPosted(
  message: message,
  sport: sport,
  announcementId: docRef.id,
);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement posted')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make Announcement'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Practice Cancelled',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message *',
                hintText: 'Enter the announcement text',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
              minLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post Announcement',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}