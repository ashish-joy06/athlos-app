import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/notification_dispatcher.dart';

/// Coach selects a training session, then marks each athlete assigned
/// to their sport. Saves to the `attendance` collection with composite ID
/// `{sessionId}_{athleteUid}` so re-marks overwrite cleanly.
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key, this.sessionId});

  /// Optional preselected session id.
  final String? sessionId;

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedSessionId;
  Map<String, dynamic>? _selectedSession;
  bool _saving = false;

  static const List<String> _statuses = [
    'Present',
    'Absent',
    'Injury',
    'Other Camp',
  ];

  @override
void initState() {
  super.initState();
  _selectedSessionId = widget.sessionId;
  if (_selectedSessionId != null) {
    _loadPreselectedSession();
  }
}

Future<void> _loadPreselectedSession() async {
  final doc = await FirebaseFirestore.instance
      .collection('training_sessions')
      .doc(_selectedSessionId)
      .get();
  if (!mounted) return;
  if (doc.exists) {
    setState(() => _selectedSession = doc.data());
  }
}

  Future<void> _saveAll(Map<String, String> marks) async {
    if (_selectedSessionId == null || _selectedSession == null) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final session = _selectedSession!;
    final startTs = session['startTime'] as Timestamp?;
    final sessionTitle = (session['title'] ?? 'Training Session').toString();
    final location = (session['location'] ?? '').toString();

    final batch = FirebaseFirestore.instance.batch();
    for (final entry in marks.entries) {
      final athleteUid = entry.key;
      final status = entry.value;

      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc('${_selectedSessionId}_$athleteUid');

      final appealQuery = await FirebaseFirestore.instance
          .collection('absence_appeals')
          .where('athleteUid', isEqualTo: athleteUid)
          .where('sessionId', isEqualTo: _selectedSessionId)
          .limit(1)
          .get();
      final hasAppeal = appealQuery.docs.isNotEmpty;

      batch.set(docRef, {
        'sessionId': _selectedSessionId,
        'athleteUid': athleteUid,
        'sessionTitle': sessionTitle,
        'sessionStartTime': startTs,
        'location': location,
        'status': status,
        'hasAppeal': hasAppeal,
        'markedBy': user.uid,
        'markedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

await NotificationDispatcher.onAttendanceMarked(
  marksByUid: marks,
  sessionTitle: sessionTitle,
  sessionId: _selectedSessionId!,
);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved')),
    );
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
      body: _selectedSessionId == null
          ? _buildSessionPicker()
          : _buildAttendanceList(),
    );
  }

  Widget _buildSessionPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_sessions')
          .orderBy('startTime', descending: true)
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
                'No training sessions yet.\nCreate one from the Coach dashboard first.',
                textAlign: TextAlign.center,
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
            final start = data['startTime'] as Timestamp?;
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              title: Text((data['title'] ?? 'Session').toString()),
              subtitle: Text(_fmt(start)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _selectedSessionId = docs[i].id;
                _selectedSession = data;
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedSessionId = null;
                  _selectedSession = null;
                }),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Athlete')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No athletes found'));
              }
              return _AttendanceList(
                athletes: docs,
                statuses: _statuses,
                sessionId: _selectedSessionId!,
                onSave: _saveAll,
                saving: _saving,
              );
            },
          ),
        ),
      ],
    );
  }

  static String _fmt(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day} • $h:$m';
  }
}

/// Stateful list of athletes with per-row status pickers.
class _AttendanceList extends StatefulWidget {
  final List<QueryDocumentSnapshot> athletes;
  final List<String> statuses;
  final String sessionId;
  final Future<void> Function(Map<String, String> marks) onSave;
  final bool saving;

  const _AttendanceList({
    required this.athletes,
    required this.statuses,
    required this.sessionId,
    required this.onSave,
    required this.saving,
  });

  @override
  State<_AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends State<_AttendanceList> {
  final Map<String, String> _marks = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.athletes.length,
            itemBuilder: (_, i) {
              final doc = widget.athletes[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? 'Athlete').toString();
              final current = _marks[doc.id] ?? 'Present';
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
                          setState(() => _marks[doc.id] = v);
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
                        for (final doc in widget.athletes) {
                          _marks.putIfAbsent(doc.id, () => 'Present');
                        }
                        widget.onSave(_marks);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
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
                    : const Text('Save Attendance',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}