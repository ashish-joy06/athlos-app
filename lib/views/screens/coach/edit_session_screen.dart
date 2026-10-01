import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'create_session_screen.dart' show kSessionColors;

/// Edit an existing training session. Only reaches this screen if the coach
/// owns the sport — enforced by Firestore rules and the caller.
class EditSessionScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> initialData;

  const EditSessionScreen({
    super.key,
    required this.sessionId,
    required this.initialData,
  });

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _eventController;

  DateTime? _startTime;
  DateTime? _endTime;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _titleController =
        TextEditingController(text: (d['title'] ?? '').toString());
    _locationController =
        TextEditingController(text: (d['location'] ?? '').toString());
    _eventController =
        TextEditingController(text: (d['event'] ?? '').toString());
    _startTime = (d['startTime'] as Timestamp?)?.toDate();
    _endTime = (d['endTime'] as Timestamp?)?.toDate();
    _selectedColor = (d['color'] ?? 'purple').toString();
  }

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
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    if (title.isEmpty || _startTime == null || _endTime == null) {
      _snack('Please fill title and times');
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      _snack('End time must be after start time');
      return;
    }
    setState(() => _saving = true);

    await FirebaseFirestore.instance
        .collection('training_sessions')
        .doc(widget.sessionId)
        .update({
      'title': title,
      'event': _eventController.text.trim(),
      'location': _locationController.text.trim(),
      'startTime': Timestamp.fromDate(_startTime!),
      'endTime': Timestamp.fromDate(_endTime!),
      'color': _selectedColor,
      'updatedAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Session updated');
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
        title: const Text('Edit Session'),
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventController,
              decoration: const InputDecoration(
                labelText: 'Event (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
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
                        color:
                            selected ? color : color.withValues(alpha: 0.3),
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
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
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
                  : const Text('Save Changes',
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