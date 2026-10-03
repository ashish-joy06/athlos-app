import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/performance_entry.dart';
import 'add_performance_screen.dart';

/// Performance view for a single athlete.
/// - Coach/admin can add, edit, delete entries.
/// - Athlete (viewing own) sees read-only view.
/// - Captain sees their squad members, no delete unless author.
class AthletePerformanceScreen extends StatefulWidget {
  final String athleteUid;
  final String athleteName;
  final String athleteSport;
  final bool readOnly; // true for athlete viewing own

  const AthletePerformanceScreen({
    super.key,
    required this.athleteUid,
    required this.athleteName,
    required this.athleteSport,
    this.readOnly = false,
  });

  @override
  State<AthletePerformanceScreen> createState() =>
      _AthletePerformanceScreenState();
}

class _AthletePerformanceScreenState extends State<AthletePerformanceScreen> {
  String? _eventFilter; // null = all events
  String? _metricFilter; // null = all metrics

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.athleteName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!widget.readOnly)
            IconButton(
              tooltip: 'Add entry',
              icon: const Icon(Icons.add_rounded),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPerformanceScreen(
                      preselectedAthlete: {
                        'id': widget.athleteUid,
                        'name': widget.athleteName,
                        'sport': widget.athleteSport,
                      },
                    ),
                  ),
                );
                if (ok == true && mounted) setState(() {});
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('performance_entries')
            .where('athleteUid', isEqualTo: widget.athleteUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Text(
                    'DEBUG: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 10),
                  ),
                ),
              ),
            );
          }
          // Sort in Dart — avoids requiring a compound Firestore index.
          final all = (snapshot.data?.docs ?? [])
              .map((d) => PerformanceEntry.fromDoc(d))
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

          // Apply filters
          final entries = all.where((e) {
            if (_eventFilter != null && e.event != _eventFilter) return false;
            if (_metricFilter != null && e.metricType != _metricFilter) {
              return false;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChart(all),
                const SizedBox(height: 20),
                _buildFilters(all),
                const SizedBox(height: 16),
                _sectionTitle('Entries (${entries.length})'),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No entries yet.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...entries.map((e) => _buildEntryCard(e)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(List<PerformanceEntry> all) {
    // Choose the metric to chart — first available numeric metric
    final numeric = all.where((e) => e.metricType != 'note').toList();
    if (numeric.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Chart appears after at least 2 numeric entries.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    // Determine target metric + event — default to most recent
    final targetMetric = _metricFilter ?? numeric.first.metricType;
    final targetEvent = _eventFilter ?? numeric.first.event;
    final filtered = numeric
        .where((e) => e.metricType == targetMetric && e.event == targetEvent)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (filtered.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Not enough entries for this filter to chart.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < filtered.length; i++) {
      spots.add(FlSpot(i.toDouble(), filtered[i].value));
    }
    final minVal = filtered.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxVal = filtered.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final chartMin = minVal - (range * 0.15).clamp(0.5, 999);
    final chartMax = maxVal + (range * 0.15).clamp(0.5, 999);

    // Detect if lower is better (time)
    final lowerIsBetter = targetMetric == 'time';
    final first = filtered.first.value;
    final last = filtered.last.value;
    final diff = last - first;
    final improving = lowerIsBetter ? diff < 0 : diff > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  '$targetEvent • ${PerformanceEntry.labelFor(targetMetric)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (improving
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      improving
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: improving
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      diff.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: improving
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: chartMin,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= filtered.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('M/d')
                                .format(filtered[i].recordedAt),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFFEC4899),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFFEC4899),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<PerformanceEntry> all) {
    final events = all.map((e) => e.event).toSet().toList()..sort();
    final metrics = all.map((e) => e.metricType).toSet().toList()..sort();

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _eventFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All events')),
                  ...events.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e))),
                ],
                onChanged: (v) => setState(() => _eventFilter = v),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _metricFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All metrics')),
                  ...metrics.map((m) => DropdownMenuItem(
                      value: m, child: Text(PerformanceEntry.labelFor(m)))),
                ],
                onChanged: (v) => setState(() => _metricFilter = v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(PerformanceEntry e) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final canEdit = !widget.readOnly && (uid == e.enteredByUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded,
                color: Color(0xFFEC4899), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.event,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${PerformanceEntry.labelFor(e.metricType)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.displayValue(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEC4899),
                  ),
                ),
                if (e.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e.notes,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(e.recordedAt),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                if (v == 'edit') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EditEntryScreen(entry: e),
                    ),
                  );
                  if (mounted) setState(() {});
                } else if (v == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete entry?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance
                        .collection('performance_entries')
                        .doc(e.id)
                        .delete();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Simple edit form for a single entry.
class _EditEntryScreen extends StatefulWidget {
  final PerformanceEntry entry;
  const _EditEntryScreen({required this.entry});

  @override
  State<_EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<_EditEntryScreen> {
  late final TextEditingController _valueController;
  late final TextEditingController _notesController;
  late String _metricType;
  late DateTime _recordedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _valueController =
        TextEditingController(text: widget.entry.value.toString());
    _notesController = TextEditingController(text: widget.entry.notes);
    _metricType = widget.entry.metricType;
    _recordedAt = widget.entry.recordedAt;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final isNote = _metricType == 'note';
    final value = isNote ? 0.0 : (double.tryParse(_valueController.text) ?? 0);
    await FirebaseFirestore.instance
        .collection('performance_entries')
        .doc(widget.entry.id)
        .update({
      'metricType': _metricType,
      'value': value,
      'unit': PerformanceEntry.unitFor(_metricType),
      'notes': _notesController.text.trim(),
      'recordedAt': Timestamp.fromDate(_recordedAt),
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entry'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _metricType,
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              items: PerformanceEntry.metricTypes
                  .map((m) => DropdownMenuItem(
                      value: m['key'], child: Text(m['label']!)))
                  .toList(),
              onChanged: (v) => setState(() => _metricType = v ?? 'time'),
            ),
            const SizedBox(height: 16),
            if (_metricType != 'note')
              TextField(
                controller: _valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Value',
                  suffixText: PerformanceEntry.unitFor(_metricType),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}