import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Coach inbox of pending absence appeals.
class CoachAppealsScreen extends StatelessWidget {
  const CoachAppealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeals Inbox'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('absence_appeals')
            .where('status', isEqualTo: 'Pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
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
  if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pending appeals.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final start =
                  (data['sessionStartTime'] as Timestamp?)?.toDate();
              return _AppealCard(
                id: docs[i].id,
                data: data,
                start: start,
                coachUid: uid,
              );
            },
          );
        },
      ),
    );
  }
}

class _AppealCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final DateTime? start;
  final String coachUid;
  const _AppealCard({
    required this.id,
    required this.data,
    required this.start,
    required this.coachUid,
  });

  @override
  State<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends State<_AppealCard> {
  bool _busy = false;

  Future<void> _resolve(String status) async {
    setState(() => _busy = true);
    await FirebaseFirestore.instance
        .collection('absence_appeals')
        .doc(widget.id)
        .update({
      'status': status,
      'resolvedAt': Timestamp.now(),
      'resolvedBy': widget.coachUid,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked $status')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
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
              const Icon(Icons.person_rounded,
                  color: Color(0xFF667EEA), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (data['athleteName'] ?? 'Athlete').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Session: ${data['sessionTitle'] ?? ''}'
            '${widget.start != null ? ' • ${DateFormat('MMM d, h:mm a').format(widget.start!)}' : ''}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Reason: ${data['reason'] ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _resolve('Rejected'),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  label: const Text(
                    'Reject',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _resolve('Approved'),
                  icon: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18),
                  label: const Text(
                    'Approve',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}