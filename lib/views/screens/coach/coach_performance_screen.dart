import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/performance_entry.dart';
import 'athlete_performance_screen.dart';

/// Performance roster — one card per athlete in the coach's (or admin's) scope.
class CoachPerformanceScreen extends StatefulWidget {
  final bool adminMode;

  const CoachPerformanceScreen({super.key, this.adminMode = false});

  @override
  State<CoachPerformanceScreen> createState() =>
      _CoachPerformanceScreenState();
}

enum _SortMode { name, points, recent }

class _CoachPerformanceScreenState extends State<CoachPerformanceScreen> {
  String? _mySport;
  String? _sportFilter;
  List<String> _sports = const [];
  _SortMode _sort = _SortMode.name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final me = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = me.data() ?? {};
    final mySport = (data['sport'] ?? 'Athletics').toString();
    if (!mounted) return;
    setState(() {
      _mySport = mySport;
      _loading = false;
    });
    if (widget.adminMode) {
      await _loadSports();
    }
  }

  Future<void> _loadSports() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Athlete')
        .get();
    final set = <String>{};
    for (final d in snap.docs) {
      final s = (d.data()['sport'] ?? '').toString();
      if (s.isNotEmpty) set.add(s);
    }
    if (set.isEmpty) set.add('Athletics');
    if (!mounted) return;
    setState(() => _sports = set.toList()..sort());
  }

  String? get _effectiveSport =>
      widget.adminMode ? _sportFilter : _mySport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Performance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildControls(),
                Expanded(child: _buildAthleteList()),
              ],
            ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: Colors.white,
      child: Column(
        children: [
          if (widget.adminMode) ...[
            Row(
              children: [
                const Icon(Icons.filter_alt_rounded,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _sportFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18),
                        style: const TextStyle(
                          color: Color(0xFF1A202C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Sports'),
                          ),
                          ..._sports.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(s),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _sportFilter = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _chip('Name', _SortMode.name),
                const SizedBox(width: 6),
                _chip('Points', _SortMode.points),
                const SizedBox(width: 6),
                _chip('Recent', _SortMode.recent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _SortMode mode) {
    final active = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFEC4899).withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? const Color(0xFFEC4899) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? const Color(0xFFEC4899) : Colors.grey.shade700,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Athlete')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'DEBUG list: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sport = _effectiveSport;
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (sport == null) return true;
          return (data['sport'] ?? '').toString() == sport;
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No athletes in this scope.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            return _AthletePerformanceCard(
              uid: d.id,
              data: data,
              sortMode: _sort,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INDIVIDUAL ATHLETE CARD
// ─────────────────────────────────────────────────────────────

class _AthletePerformanceCard extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  final _SortMode sortMode;

  const _AthletePerformanceCard({
    required this.uid,
    required this.data,
    required this.sortMode,
  });

  @override
  State<_AthletePerformanceCard> createState() =>
      _AthletePerformanceCardState();
}

class _AthletePerformanceCardState
    extends State<_AthletePerformanceCard> {
  List<PerformanceEntry>? _entries;
  int _pointsThisMonth = 0;
  int _pointsAllTime = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fs = FirebaseFirestore.instance;

      final entriesSnap = await fs
          .collection('performance_entries')
          .where('athleteUid', isEqualTo: widget.uid)
          .get();

      final entries = entriesSnap.docs
          .map((d) => PerformanceEntry.fromDoc(d))
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      final attendanceSnap = await fs
          .collection('attendance')
          .where('athleteUid', isEqualTo: widget.uid)
          .get();

      int monthPoints = 0;
      int allPoints = 0;
      final now = DateTime.now();
      for (final doc in attendanceSnap.docs) {
        final data = doc.data();
        final pts =
            (data['points'] is num) ? (data['points'] as num).toInt() : 0;
        allPoints += pts;
        final ts = (data['sessionStartTime'] as Timestamp?)?.toDate();
        if (ts != null && ts.year == now.year && ts.month == now.month) {
          monthPoints += pts;
        }
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _pointsThisMonth = monthPoints;
        _pointsAllTime = allPoints;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['name'] ?? 'Athlete').toString();
    final sport = (widget.data['sport'] ?? '').toString();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AthletePerformanceScreen(
              athleteUid: widget.uid,
              athleteName: name,
              athleteSport: sport,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _loading
            ? const SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _error != null
                ? SizedBox(
                    height: 140,
                    child: SingleChildScrollView(
                      child: Text(
                        'DEBUG: $_error',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  )
                : _buildContent(name),
      ),
    );
  }

  Widget _buildContent(String name) {
    final entries = _entries ?? [];

    final numeric = entries.where((e) => e.metricType != 'note').toList();
    final byEvent = <String, List<PerformanceEntry>>{};
    for (final e in numeric) {
      byEvent.putIfAbsent(e.event, () => []).add(e);
    }
    final eventRecency = byEvent.entries.toList()
      ..sort((a, b) {
        final aDate = a.value.first.recordedAt;
        final bDate = b.value.first.recordedAt;
        return bDate.compareTo(aDate);
      });
    final shownEvents = eventRecency.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  const Color(0xFFEC4899).withValues(alpha: 0.12),
              child: const Icon(Icons.person,
                  color: Color(0xFFEC4899), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A202C),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 10),
        if (shownEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text(
              'No performance entries yet.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        else
          ...shownEvents.map((e) => _buildEventBlock(e.key, e.value)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded,
                  size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Points',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    Text(
                      '$_pointsThisMonth this month • '
                      '$_pointsAllTime all time',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventBlock(String event, List<PerformanceEntry> entries) {
    final sorted = [...entries]..sort((a, b) {
        final cmp = a.recordedAt.compareTo(b.recordedAt);
        if (cmp != 0) return cmp;
        return a.value.compareTo(b.value);
      });
    final metric = entries.first.metricType;
    final unit = entries.first.unit;

    final metricEntries =
        sorted.where((e) => e.metricType == metric).toList();
    if (metricEntries.isEmpty) return const SizedBox.shrink();

    final first = metricEntries.first.value;
    final last = metricEntries.last.value;
    final minV =
        metricEntries.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxV =
        metricEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final pb = metric == 'time' ? minV : maxV;
    final lowerIsBetter = metric == 'time';
    final diff = last - first;
    final improving = lowerIsBetter ? diff < 0 : diff > 0;

    final recent = entries.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 32,
                child: metricEntries.length >= 2
                    ? _buildSparkline(metricEntries)
                    : const Center(
                        child: Icon(Icons.show_chart,
                            size: 18, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PB: ${_fmtVal(pb, unit)}   •   '
                  'Last: ${_fmtVal(last, unit)}   •   '
                  'Δ: ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: improving
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...recent.map((e) {
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Text(
                      DateFormat('MMM d').format(e.recordedAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.displayValue(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSparkline(List<PerformanceEntry> entries) {
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }
    final minV = entries.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxV = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();
    final padding = range < 0.001 ? 1.0 : range * 0.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: minV - padding,
        maxY: maxV + padding,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFEC4899),
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFEC4899).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtVal(double v, String unit) {
    final numStr = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2);
    return unit.isNotEmpty ? '$numStr $unit' : numStr;
  }
}