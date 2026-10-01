import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Captain-facing attendance screen.
/// Flow:
///   1. Pick an upcoming session (same list coaches see, but read-only)
///   2. Mark each squad member Present / Absent / Injury / Other Camp
///   3. Save to `attendance/{sessionId}_{athleteUid}`
///
/// Only marks athletes in the passed-in `squad` list.
class CaptainMarkAttendanceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> squad;
  const CaptainMarkAttendanceScreen({super.key, required this.squad});

  @override
  State<CaptainMarkAttendanceScreen> createState() =>
      _CaptainMarkAttendanceScreenState();
}

class _CaptainMarkAttendanceScreenState
    extends State<CaptainMarkAttendanceScreen> {
  static const List<String> _statuses = [
    'Present',
    'Absent',
    'Injury',
    'Other Camp',
  ];

  Map<String, dynamic>? _selectedSession;
  bool _saving = false;

  Future<void> _saveAll(Map<String, String> marks) async {
    if (_selectedSession == null) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final session = _selectedSession!;
    final startTs = session['startTime'] as Timestamp?;
    final sessionTitle =
        (session['title'] ?? 'Training Session').toString();
    final location = (session['location'] ?? '').toString();

    final batch = FirebaseFirestore.instance.batch();
    for (final entry in marks.entries) {
      final athleteUid = entry.key;
      final status = entry.value;
      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc('${session['id']}_$athleteUid');

      // Check for existing appeal
      final appeal = await FirebaseFirestore.instance
          .collection('absence_appeals')
          .where('athleteUid', isEqualTo: athleteUid)
          .where('sessionId', isEqualTo: session['id'])
          .limit(1)
          .get();

      batch.set(docRef, {
        'sessionId': session['id'],
        'athleteUid': athleteUid,
        'sessionTitle': sessionTitle,
        'sessionStartTime': startTs,
        'location': location,
        'status': status,
        'hasAppeal': appeal.docs.isNotEmpty,
        'markedBy': user.uid,
        'markedByRole': 'Captain',
        'markedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _selectedSession == null
          ? _buildSessionPicker()
          : _buildRoster(),
    );
  }

  Widget _buildSessionPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_sessions')
          .where('startTime',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('startTime')
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No upcoming sessions to mark.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final start = (data['startTime'] as Timestamp?)?.toDate();
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              title: Text((data['title'] ?? 'Session').toString()),
              subtitle: Text(start != null
                  ? DateFormat('MMM d, h:mm a').format(start)
                  : ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _selectedSession = {'id': docs[i].id, ...data};
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildRoster() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedSession = null),
              ),
              Expanded(
                child: Text(
                  (_selectedSession?['title'] ?? 'Session').toString(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _RosterList(
            squad: widget.squad,
            statuses: _statuses,
            onSave: _saveAll,
            saving: _saving,
          ),
        ),
      ],
    );
  }
}

class _RosterList extends StatefulWidget {
  final List<Map<String, dynamic>> squad;
  final List<String> statuses;
  final Future<void> Function(Map<String, String> marks) onSave;
  final bool saving;

  const _RosterList({
    required this.squad,
    required this.statuses,
    required this.onSave,
    required this.saving,
  });

  @override
  State<_RosterList> createState() => _RosterListState();
}

class _RosterListState extends State<_RosterList> {
  final Map<String, String> _marks = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.squad.length,
            itemBuilder: (_, i) {
              final u = widget.squad[i];
              final uid = u['id'] as String;
              final name = (u['name'] ?? 'Athlete').toString();
              final current = _marks[uid] ?? 'Present';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      DropdownButton<String>(
                        value: current,
                        underline: const SizedBox.shrink(),
                        items: widget.statuses
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _marks[uid] = v);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.saving
                    ? null
                    : () {
                        for (final u in widget.squad) {
                          _marks.putIfAbsent(
                              u['id'] as String, () => 'Present');
                        }
                        widget.onSave(_marks);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: widget.saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Squad Attendance',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}