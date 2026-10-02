import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/notification_dispatcher.dart';

/// Session color presets. `name` is stored in Firestore; `color` is used
/// for the UI dot and the calendar highlight.
const List<Map<String, dynamic>> kSessionColors = [
  {'name': 'purple', 'label': 'Training',   'color': Color(0xFF667EEA)},
  {'name': 'green',  'label': 'Practice',   'color': Color(0xFF10B981)},
  {'name': 'red',    'label': 'Important',  'color': Color(0xFFEF4444)},
  {'name': 'blue',   'label': 'Camp',       'color': Color(0xFF3B82F6)},
  {'name': 'orange', 'label': 'Meet',       'color': Color(0xFFF59E0B)},
  {'name': 'grey',   'label': 'Optional',   'color': Color(0xFF94A3B8)},
];

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _eventController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  String _selectedColor = 'purple';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? DateTime.now())
        : (_endTime ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    if (title.isEmpty || _startTime == null || _endTime == null) {
      _snack('Please fill title and times');
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      _snack('End time must be after start time');
      return;
    }
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final coachName = (data['name'] ?? 'Coach').toString();
    final sport = (data['sport'] ?? 'Athletics').toString();

    final docRef =
    await FirebaseFirestore.instance.collection('training_sessions').add({
  'title': title,
  'coachUid': user.uid,
  'coachName': coachName,
  'event': _eventController.text.trim(),
  'sport': sport,
  'startTime': Timestamp.fromDate(_startTime!),
  'endTime': Timestamp.fromDate(_endTime!),
  'location': location,
  'color': _selectedColor,
  'createdAt': Timestamp.now(),
});

// Fire notifications to athletes in this sport.
await NotificationDispatcher.onSessionCreated(
  sessionTitle: title,
  sport: sport,
  startTime: _startTime!,
  sessionId: docRef.id,
);

    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Session created');
    Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _fmt(DateTime? dt) {
    if (dt == null) return 'Select';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Training Session'),
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
                labelText: 'Session Title',
                hintText: 'e.g. Morning Track — Sprints',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventController,
              decoration: const InputDecoration(
                labelText: 'Event (optional)',
                hintText: 'e.g. Sprints, Throws, Jumps',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Main Stadium',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildDateTimeTile(
              label: 'Start Time',
              value: _fmt(_startTime),
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _buildDateTimeTile(
              label: 'End Time',
              value: _fmt(_endTime),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 24),

            // Color picker
            const Text(
              'Label color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kSessionColors.map((preset) {
                final name = preset['name'] as String;
                final label = preset['label'] as String;
                final color = preset['color'] as Color;
                final selected = _selectedColor == name;

                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : color.withValues(alpha: 0.3),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.w500,
                            color: color,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check, size: 14, color: color),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
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
                  : const Text('Create Session',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF667EEA)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}