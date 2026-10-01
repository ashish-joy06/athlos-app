import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../coach/create_session_screen.dart' show kSessionColors;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  String? _mySport;

  @override
  void initState() {
    super.initState();
    _loadSport();
  }

  Future<void> _loadSport() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _mySport = (doc.data()?['sport'] ?? 'Athletics').toString();
    });
  }

  Color _colorFor(String? name) {
    for (final c in kSessionColors) {
      if (c['name'] == name) return c['color'] as Color;
    }
    return const Color(0xFF667EEA);
  }

  Future<void> _addActivity() async {
    final TextEditingController workController = TextEditingController();
    DateTime? startTime;
    DateTime? endTime;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Personal Activity"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: workController,
                decoration: const InputDecoration(labelText: "Work/Activity"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDay,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() {
                        startTime = DateTime(picked.year, picked.month,
                            picked.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                child: Text(startTime == null
                    ? "Select Start Time"
                    : "Start: $startTime"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDay,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (time != null) {
                      setState(() {
                        endTime = DateTime(picked.year, picked.month,
                            picked.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                child: Text(endTime == null
                    ? "Select End Time"
                    : "End: $endTime"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (workController.text.isNotEmpty &&
                  startTime != null &&
                  endTime != null) {
                await FirebaseFirestore.instance.collection('timetables').add({
                  'uid': uid,
                  'work': workController.text,
                  'startTime': Timestamp.fromDate(startTime!.toUtc()),
                  'endTime': Timestamp.fromDate(endTime!.toUtc()),
                  'createdAt': Timestamp.now(),
                  'notified': false,
                });
                if (!mounted) return;
                Navigator.of(ctx).pop();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Calendar")),
      body: Column(
        children: [
          // Calendar with event loader for team sessions
          _TeamSessionCalendar(
            mySport: _mySport,
            selectedDay: selectedDay,
            colorFor: _colorFor,
            onDaySelected: (day) {
              setState(() => selectedDay = day);
            },
          ),

          // Selected day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF667EEA), size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM d').format(selectedDay),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _DayDetail(
              uid: uid,
              mySport: _mySport,
              selectedDay: selectedDay,
              colorFor: _colorFor,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addActivity,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Wraps TableCalendar and paints colored dots for days that have sessions.
class _TeamSessionCalendar extends StatelessWidget {
  final String? mySport;
  final DateTime selectedDay;
  final Color Function(String?) colorFor;
  final void Function(DateTime) onDaySelected;

  const _TeamSessionCalendar({
    required this.mySport,
    required this.selectedDay,
    required this.colorFor,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (mySport == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_sessions')
          .where('sport', isEqualTo: mySport)
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
          focusedDay: selectedDay,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: (selected, _) => onDaySelected(selected),
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
                    final c = colorFor(data['color']?.toString());
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
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
}

/// Details for the currently selected day: team sessions + personal activities.
class _DayDetail extends StatelessWidget {
  final String uid;
  final String? mySport;
  final DateTime selectedDay;
  final Color Function(String?) colorFor;

  const _DayDetail({
    required this.uid,
    required this.mySport,
    required this.selectedDay,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (mySport != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('training_sessions')
                .where('sport', isEqualTo: mySport)
                .orderBy('startTime')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = (snapshot.data?.docs ?? []).where((d) {
                final data = d.data() as Map<String, dynamic>;
                final start = (data['startTime'] as Timestamp?)?.toDate();
                if (start == null) return false;
                return start.year == selectedDay.year &&
                    start.month == selectedDay.month &&
                    start.day == selectedDay.day;
              }).toList();

              if (docs.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Team Sessions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                  ),
                  ...docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final color = colorFor(data['color']?.toString());
                    final start =
                        (data['startTime'] as Timestamp?)?.toDate();
                    final end = (data['endTime'] as Timestamp?)?.toDate();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: color, width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (data['title'] ?? 'Session').toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (start != null)
                                      DateFormat('h:mm a').format(start),
                                    if (end != null)
                                      DateFormat('h:mm a').format(end),
                                  ].join(' – '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                if ((data['location'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    data['location'].toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),

        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            'My Activities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('timetables')
              .where('uid', isEqualTo: uid)
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.utc(selectedDay.year, selectedDay.month,
                      selectedDay.day),
                ),
              )
              .where(
                'startTime',
                isLessThan: Timestamp.fromDate(
                  DateTime.utc(selectedDay.year, selectedDay.month,
                      selectedDay.day + 1),
                ),
              )
              .orderBy('startTime')
              .snapshots(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "No personal activities for this day.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              );
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final start =
                    (data['startTime'] as Timestamp).toDate().toLocal();
                final end =
                    (data['endTime'] as Timestamp).toDate().toLocal();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['work'] ?? 'Activity').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('h:mm a').format(start)} – '
                        '${DateFormat('h:mm a').format(end)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}