import 'package:cloud_firestore/cloud_firestore.dart';

/// A single performance metric recorded for an athlete.
/// Metric types are free-form strings — the app defaults to:
///   time | distance | rpe | reps | weight | note
class PerformanceEntry {
  final String id;
  final String athleteUid;
  final String athleteName;
  final String athleteSport;
  final String event;
  final String metricType;
  final double value;
  final String unit;
  final String notes;
  final DateTime recordedAt;
  final String enteredByUid;
  final String enteredByRole;
  final DateTime createdAt;

  PerformanceEntry({
    required this.id,
    required this.athleteUid,
    required this.athleteName,
    required this.athleteSport,
    required this.event,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.notes,
    required this.recordedAt,
    required this.enteredByUid,
    required this.enteredByRole,
    required this.createdAt,
  });

  factory PerformanceEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PerformanceEntry(
      id: doc.id,
      athleteUid: (d['athleteUid'] ?? '').toString(),
      athleteName: (d['athleteName'] ?? '').toString(),
      athleteSport: (d['athleteSport'] ?? '').toString(),
      event: (d['event'] ?? '').toString(),
      metricType: (d['metricType'] ?? 'note').toString(),
      value: (d['value'] is num) ? (d['value'] as num).toDouble() : 0,
      unit: (d['unit'] ?? '').toString(),
      notes: (d['notes'] ?? '').toString(),
      recordedAt: (d['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      enteredByUid: (d['enteredByUid'] ?? '').toString(),
      enteredByRole: (d['enteredByRole'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'athleteUid': athleteUid,
        'athleteName': athleteName,
        'athleteSport': athleteSport,
        'event': event,
        'metricType': metricType,
        'value': value,
        'unit': unit,
        'notes': notes,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'enteredByUid': enteredByUid,
        'enteredByRole': enteredByRole,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static const List<Map<String, String>> metricTypes = [
    {'key': 'time', 'label': 'Time', 'unit': 's'},
    {'key': 'distance', 'label': 'Distance', 'unit': 'm'},
    {'key': 'rpe', 'label': 'RPE (1-10)', 'unit': ''},
    {'key': 'reps', 'label': 'Reps', 'unit': ''},
    {'key': 'weight', 'label': 'Weight', 'unit': 'kg'},
    {'key': 'note', 'label': 'Note only', 'unit': ''},
  ];

  static String unitFor(String metricKey) {
    for (final m in metricTypes) {
      if (m['key'] == metricKey) return m['unit'] ?? '';
    }
    return '';
  }

  static String labelFor(String metricKey) {
    for (final m in metricTypes) {
      if (m['key'] == metricKey) return m['label'] ?? metricKey;
    }
    return metricKey;
  }

  String displayValue() {
    if (metricType == 'note') return '(note)';
    if (metricType == 'rpe') return '${value.toStringAsFixed(0)}/10';
    final numStr = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return unit.isNotEmpty ? '$numStr $unit' : numStr;
  }
}