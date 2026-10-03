import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Admin appeals manager — all appeals across every sport.
/// Tabs: Pending | Approved | Rejected | All
class AdminAppealsScreen extends StatefulWidget {
  const AdminAppealsScreen({super.key});

  @override
  State<AdminAppealsScreen> createState() => _AdminAppealsScreenState();
}

class _AdminAppealsScreenState extends State<AdminAppealsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const List<String> _tabs = ['Pending', 'Approved', 'Rejected', 'All'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Appeals'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF667EEA),
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _tabs.map((t) => _AppealsList(status: t)).toList(),
      ),
    );
  }
}

class _AppealsList extends StatelessWidget {
  final String status; // 'Pending' | 'Approved' | 'Rejected' | 'All'

  const _AppealsList({required this.status});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('absence_appeals')
        .orderBy('createdAt', descending: true);
    if (status != 'All') {
      q = q.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No $status appeals.',
                  style: const TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AppealCard(
            id: docs[i].id,
            data: docs[i].data() as Map<String, dynamic>,
          ),
        );
      },
    );
  }
}

class _AppealCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const _AppealCard({required this.id, required this.data});

  @override
  State<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends State<_AppealCard> {
  bool _busy = false;

  Future<void> _resolve(String resolution) async {
    setState(() => _busy = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('absence_appeals')
        .doc(widget.id)
        .update({
      'status': resolution,
      'resolvedAt': Timestamp.now(),
      'resolvedBy': uid,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked $resolution')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final s = (d['status'] ?? 'Pending').toString();
    final color = s == 'Approved'
        ? const Color(0xFF10B981)
        : s == 'Rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final created = (d['createdAt'] as Timestamp?)?.toDate();
    final start = (d['sessionStartTime'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
              Expanded(
                child: Text(
                  (d['athleteName'] ?? 'Athlete').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sport: ${d['athleteSport'] ?? '—'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            'Session: ${d['sessionTitle'] ?? ''}'
            '${start != null ? ' • ${DateFormat('MMM d, h:mm a').format(start)}' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Reason: ${d['reason'] ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (created != null) ...[
            const SizedBox(height: 6),
            Text(
              'Submitted ${DateFormat('MMM d, h:mm a').format(created)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          if (s == 'Pending') ...[
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
        ],
      ),
    );
  }
}