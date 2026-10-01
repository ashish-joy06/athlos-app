import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Athlete screen to file an absence appeal for an upcoming training session.
/// Sessions starting less than 6 hours from now cannot be appealed.
class AbsenceAppealScreen extends StatefulWidget {
  const AbsenceAppealScreen({super.key});

  @override
  State<AbsenceAppealScreen> createState() => _AbsenceAppealScreenState();
}

class _AbsenceAppealScreenState extends State<AbsenceAppealScreen> {
  static const Duration _cutoff = Duration(hours: 6);

  String? _selectedSessionId;
  Map<String, dynamic>? _selectedSession;
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool _isWithinCutoff(DateTime start) {
    return DateTime.now().isAfter(start.subtract(_cutoff));
  }

  Future<void> _submit() async {
    if (_selectedSessionId == null || _selectedSession == null) {
      _snack('Please select a session first');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _snack('Please enter a reason');
      return;
    }

    final session = _selectedSession!;
    final startTs = session['startTime'] as Timestamp?;
    if (startTs == null) {
      _snack('Session has no start time');
      return;
    }
    if (_isWithinCutoff(startTs.toDate())) {
      _snack('Too late — appeals close 6 hours before start');
      return;
    }

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final myName = (data['name'] ?? 'Athlete').toString();
    final mySport = (data['sport'] ?? 'Athletics').toString();
    final coachUid = (data['coachUid'] ?? '').toString();

    await FirebaseFirestore.instance.collection('absence_appeals').add({
      'athleteUid': user.uid,
      'athleteName': myName,
      'athleteSport': mySport,
      'coachUid': coachUid,
      'sessionId': _selectedSessionId,
      'sessionTitle': (session['title'] ?? 'Session').toString(),
      'sessionStartTime': startTs,
      'reason': reason,
      'status': 'Pending',
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() {
      _saving = false;
      _reasonController.clear();
      _selectedSessionId = null;
      _selectedSession = null;
    });
    _snack('Appeal submitted');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeal Absence'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upcoming sessions picker
            const Text(
              'Upcoming Sessions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            _buildSessionPicker(),
            const SizedBox(height: 24),

            if (_selectedSession != null) ...[
              _buildSelectedInfo(),
              const SizedBox(height: 16),
              const Text(
                'Reason for absence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Medical appointment / Family emergency / Injury',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
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
                    : const Text('Submit Appeal',
                        style: TextStyle(fontSize: 16)),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB45309)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select an upcoming session to file an appeal. '
                        'Sessions starting in less than 6 hours can no longer be appealed.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C2D12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Text(
              'My Appeals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            _buildAppealsHistory(),
          ],
        ),
      ),
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
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No upcoming sessions.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final start = (data['startTime'] as Timestamp?)?.toDate();
            if (start == null) return const SizedBox.shrink();
            final locked = _isWithinCutoff(start);
            final selected = _selectedSessionId == doc.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: locked
                    ? () => _snack(
                        'Appeals close 6 hours before the session starts')
                    : () {
                        setState(() {
                          _selectedSessionId = doc.id;
                          _selectedSession = data;
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF667EEA).withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF667EEA)
                          : Colors.grey.shade200,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_clock
                            : Icons.event_available_rounded,
                        color: locked
                            ? Colors.grey
                            : const Color(0xFF667EEA),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data['title'] ?? 'Session').toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: locked ? Colors.grey : Colors.black87,
                              ),
                            ),
                            Text(
                              '${DateFormat('MMM d').format(start)} • '
                              '${DateFormat('h:mm a').format(start)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (locked)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Appeal window closed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
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
          }).toList(),
        );
      },
    );
  }

  Widget _buildSelectedInfo() {
    final session = _selectedSession!;
    final start = (session['startTime'] as Timestamp?)?.toDate();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: Color(0xFF667EEA), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${session['title'] ?? ''} • '
              '${start != null ? DateFormat('MMM d, h:mm a').format(start) : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667EEA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealsHistory() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absence_appeals')
          .where('athleteUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No appeals submitted yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'Pending').toString();
            final color = status == 'Approved'
                ? const Color(0xFF10B981)
                : status == 'Rejected'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (data['sessionTitle'] ?? 'Session').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reason: ${data['reason'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}