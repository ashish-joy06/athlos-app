import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/athletics_events.dart';
import '../../../models/performance_entry.dart';

/// Coach / captain / admin adds a performance entry for an athlete.
/// If [preselectedAthlete] is provided, the athlete picker is skipped.
/// If [lockToSquad] is true, the athlete picker is limited to the given list.
class AddPerformanceScreen extends StatefulWidget {
  final Map<String, dynamic>? preselectedAthlete;
  final List<Map<String, dynamic>>? lockToSquad;

  const AddPerformanceScreen({
    super.key,
    this.preselectedAthlete,
    this.lockToSquad,
  });

  @override
  State<AddPerformanceScreen> createState() => _AddPerformanceScreenState();
}

class _AddPerformanceScreenState extends State<AddPerformanceScreen> {
  Map<String, dynamic>? _athlete;
  String? _event;
  String _metricType = 'time';
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;

  List<Map<String, dynamic>> _athleteList = const [];
  bool _loadingAthletes = true;

  @override
  void initState() {
    super.initState();
    _athlete = widget.preselectedAthlete;
    if (widget.lockToSquad != null) {
      _athleteList = widget.lockToSquad!;
      _loadingAthletes = false;
    } else if (_athlete == null) {
      _loadAthletes();
    } else {
      _loadingAthletes = false;
    }

    // Default event from athlete's events array
    final ev = (_athlete?['events'] as List?)?.firstOrNull;
    if (ev != null) _event = ev.toString();
  }

  Future<void> _loadAthletes() async {
    final me = FirebaseAuth.instance.currentUser!;
    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .get();
    final myRole = (meDoc.data()?['role'] ?? '').toString();
    final mySport = (meDoc.data()?['sport'] ?? 'Athletics').toString();

    Query q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Athlete');
    if (myRole != 'Admin') {
      q = q.where('sport', isEqualTo: mySport);
    }
    final snap = await q.get();
    if (!mounted) return;
    setState(() {
      _athleteList = snap.docs
          .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
          .toList()
        ..sort((a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()));
      _loadingAthletes = false;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _recordedAt = d);
  }

  Future<void> _save() async {
    if (_athlete == null) {
      _snack('Pick an athlete');
      return;
    }
    if (_event == null || _event!.isEmpty) {
      _snack('Pick an event');
      return;
    }
    final valueText = _valueController.text.trim();
    final isNote = _metricType == 'note';
    double value = 0;
    if (!isNote) {
      value = double.tryParse(valueText) ?? -1;
      if (value < 0) {
        _snack('Enter a valid number');
        return;
      }
    }

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final myRole = (meDoc.data()?['role'] ?? 'Coach').toString();

    final entry = PerformanceEntry(
      id: '',
      athleteUid: _athlete!['id'] as String,
      athleteName: (_athlete!['name'] ?? 'Athlete').toString(),
      athleteSport: (_athlete!['sport'] ?? 'Athletics').toString(),
      event: _event!,
      metricType: _metricType,
      value: value,
      unit: PerformanceEntry.unitFor(_metricType),
      notes: _notesController.text.trim(),
      recordedAt: _recordedAt,
      enteredByUid: user.uid,
      enteredByRole: myRole,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('performance_entries')
        .add(entry.toMap());

    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Performance entry saved');
    Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final athleteEvents = ((_athlete?['events'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Performance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loadingAthletes
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Athlete picker
                  if (widget.preselectedAthlete == null) ...[
                    const Text(
                      'Athlete',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _athlete?['id'] as String?,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select athlete',
                      ),
                      items: _athleteList.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'] as String,
                          child: Text((a['name'] ?? 'Athlete').toString()),
                        );
                      }).toList(),
                      onChanged: (id) {
                        final picked = _athleteList
                            .firstWhere((a) => a['id'] == id);
                        setState(() {
                          _athlete = picked;
                          final first = (picked['events'] as List?)?.firstOrNull;
                          if (first != null) _event = first.toString();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person,
                              color: Color(0xFF667EEA)),
                          const SizedBox(width: 8),
                          Text(
                            (_athlete!['name'] ?? 'Athlete').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667EEA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Event picker
                  const Text(
                    'Event',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (athleteEvents.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: athleteEvents.contains(_event) ? _event : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select event',
                      ),
                      items: athleteEvents
                          .map((e) =>
                              DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _event = v),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _event,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select event',
                      ),
                      items: AthleticsEvents.all
                          .map((e) =>
                              DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _event = v),
                    ),
                  const SizedBox(height: 16),

                  // Metric type
                  const Text(
                    'Metric',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _metricType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: PerformanceEntry.metricTypes
                        .map((m) => DropdownMenuItem<String>(
                              value: m['key'],
                              child: Text(m['label']!),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _metricType = v ?? 'time'),
                  ),
                  const SizedBox(height: 16),

                  // Value (hidden for note-only)
                  if (_metricType != 'note') ...[
                    const Text(
                      'Value',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _valueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: _metricType == 'rpe'
                            ? '1–10'
                            : 'e.g. 11.42',
                        suffixText: PerformanceEntry.unitFor(_metricType),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recorded date
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Color(0xFF667EEA), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMM d, yyyy').format(_recordedAt),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  const Text(
                    'Notes (optional)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Felt strong on the drive phase',
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
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
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Entry',
                            style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}