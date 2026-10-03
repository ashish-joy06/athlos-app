import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Line chart showing attendance rate over time.
/// Each point = one day (or monthly bucket for "All Time").
class AdminAttendanceChart extends StatelessWidget {
  final String? sportFilter;
  final Duration? timeWindow;
  final DateTime? timeStart;

  const AdminAttendanceChart({
    super.key,
    required this.sportFilter,
    required this.timeWindow,
    required this.timeStart,
  });

  Future<List<_Point>> _load() async {
    final fs = FirebaseFirestore.instance;

    Query q = fs.collection('attendance');
    if (timeStart != null) {
      q = q.where('sessionStartTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart!));
    }
    final snap = await q.get();

    // If sport filter is set, restrict to athletes in that sport.
    Set<String>? allowedUids;
    if (sportFilter != null) {
      final athletes = await fs
          .collection('users')
          .where('role', isEqualTo: 'Athlete')
          .where('sport', isEqualTo: sportFilter)
          .get();
      allowedUids = athletes.docs.map((d) => d.id).toSet();
    }

    // Bucket by day.
    final Map<String, List<int>> buckets = {}; // key -> [present, total]
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (allowedUids != null &&
          !allowedUids.contains(data['athleteUid'] as String? ?? '')) {
        continue;
      }
      final ts = data['sessionStartTime'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final key = DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
      buckets.putIfAbsent(key, () => [0, 0]);
      buckets[key]![1] += 1;
      if (data['status'] == 'Present') buckets[key]![0] += 1;
    }

    // Sort keys ascending.
    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((k) {
      final parts = buckets[k]!;
      final rate = parts[1] == 0 ? 0.0 : (parts[0] / parts[1]) * 100;
      return _Point(date: DateTime.parse(k), rate: rate);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Point>>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No attendance data for this range.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          );
        }

        final spots = <FlSpot>[];
        for (var i = 0; i < data.length; i++) {
          spots.add(FlSpot(i.toDouble(), data[i].rate));
        }

        return Container(
          padding: const EdgeInsets.all(12),
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
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
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
                      reservedSize: 30,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('M/d').format(data[idx].date),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
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
                    color: const Color(0xFF667EEA),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF667EEA),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF667EEA).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Point {
  final DateTime date;
  final double rate;
  _Point({required this.date, required this.rate});
}