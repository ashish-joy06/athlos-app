import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'create_session_screen.dart';
import 'edit_session_screen.dart';
import 'mark_attendance_screen.dart';
import 'create_session_screen.dart' show kSessionColors;

/// Coach calendar:
/// - Views all training sessions (every sport)
/// - Can edit/delete only sessions matching the coach's own sport
/// - Day detail lists sessions sorted by startTime, then sport (A→Z)
/// - Shows a per-athlete attendance roster for own-sport sessions
class CoachCalendarScreen extends StatefulWidget {
  const CoachCalendarScreen({super.key});

  @override
  State<CoachCalendarScreen> createState() => _CoachCalendarScreenState();
}

class _CoachCalendarScreenState extends State<CoachCalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  String? _mySport;

  @override
  void initState() {
    super.initState();
    _loadMySport();
  }

  Future<void> _loadMySport() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() => _mySport = (doc.data()?['sport'] ?? 'Athletics').toString());
  }

  Color _colorFor(String? name) {
    for (final c in kSessionColors) {
      if (c['name'] == name) return c['color'] as Color;
    }
    return const Color(0xFF667EEA);
  }

  List<Map<String, dynamic>> _sortedDocs(List<QueryDocumentSnapshot> docs) {
    final list = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {'id': d.id, ...data};
    }).toList();

    list.sort((a, b) {
      final ta = a['startTime'] as Timestamp?;
      final tb = b['startTime'] as Timestamp?;
      if (ta == null || tb == null) return 0;
      final cmp = ta.compareTo(tb);
      if (cmp != 0) return cmp;
      final sa = (a['sport'] ?? '').toString();
      final sb = (b['sport'] ?? '').toString();
      return sa.compareTo(sb);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Table'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCalendar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF667EEA), size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDay),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildDayDetail()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateSessionScreen(),
            ),
          );
          if (ok == true && mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCalendar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_sessions')
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        final sessionsByDay = <DateTime, List<Map<String, dynamic>>>{};
        if (snapshot.hasData) {
          for (final d in snapshot.data!.docs) {
            final data = d.data() as Map<String, dynamic>;
            final start = (data['startTime'] as Timestamp?)?.toDate();
            if (start == null) continue;
            final key = DateTime(start.year, start.month, start.day);
            sessionsByDay.putIfAbsent(key, () => []).add(data);
          }
        }

        return TableCalendar(
          focusedDay: _selectedDay,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, _) =>
              setState(() => _selectedDay = selected),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return sessionsByDay[key] ?? const [];
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(4).map((e) {
                    final data = e as Map<String, dynamic>;
                    final c = _colorFor(data['color']?.toString());
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDayDetail() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_sessions')
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = _sortedDocs(snapshot.data!.docs);
        final forDay = all.where((s) {
          final start = s['startTime'] as Timestamp?;
          if (start == null) return false;
          final d = start.toDate();
          return d.year == _selectedDay.year &&
              d.month == _selectedDay.month &&
              d.day == _selectedDay.day;
        }).toList();

        if (forDay.isEmpty) {
          return const Center(
            child: Text(
              'No sessions on this day.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: forDay.length,
          itemBuilder: (_, i) => _SessionDayCard(
            session: forDay[i],
            mySport: _mySport,
            colorFor: _colorFor,
            onChanged: () => setState(() {}),
          ),
        );
      },
    );
  }
}

class _SessionDayCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String? mySport;
  final Color Function(String?) colorFor;
  final VoidCallback onChanged;

  const _SessionDayCard({
    required this.session,
    required this.mySport,
    required this.colorFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorFor(session['color']?.toString());
    final start = (session['startTime'] as Timestamp?)?.toDate();
    final end = (session['endTime'] as Timestamp?)?.toDate();
    final sessionSport = (session['sport'] ?? '').toString();
    final isMine = mySport != null && sessionSport == mySport;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 5)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (session['title'] ?? 'Session').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (start != null)
                            DateFormat('h:mm a').format(start),
                          if (end != null) DateFormat('h:mm a').format(end),
                        ].join(' – '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if ((session['location'] ?? '').toString().isNotEmpty)
                        Text(
                          session['location'].toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sessionSport.isEmpty ? '—' : sessionSport,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditSessionScreen(
                              sessionId: session['id'] as String,
                              initialData: session,
                            ),
                          ),
                        );
                        if (ok == true) onChanged();
                      } else if (v == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete session?'),
                            content: Text(
                                'Delete "${session['title']}"? This cannot be undone.'),
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
                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('training_sessions')
                              .doc(session['id'])
                              .delete();
                          onChanged();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: 'Read-only (different sport)',
                      child: Icon(Icons.lock_outline,
                          size: 18, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _RosterList(sessionId: session['id'] as String),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                      label: const Text('Mark Attendance'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarkAttendanceScreen(
                              sessionId: session['id'] as String,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF667EEA)),
                        foregroundColor: const Color(0xFF667EEA),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Streams the attendance records for a single session, showing each athlete's
/// status (Present / Absent / Injury / Other Camp / Uninformed).
class _RosterList extends StatelessWidget {
  final String sessionId;
  const _RosterList({required this.sessionId});

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No athletes marked yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final rawStatus = (data['status'] ?? 'Absent').toString();
            String display = rawStatus;
            if (rawStatus == 'Absent') {
              final hasAppeal = data['hasAppeal'];
              if (hasAppeal == false || hasAppeal == null) {
                display = 'Uninformed';
              }
            }
            final style = _styles[display] ?? _styles['Uninformed']!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(style.icon, size: 16, color: style.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (data['athleteName'] ?? data['athleteUid'] ?? 'Athlete')
                          .toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: style.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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