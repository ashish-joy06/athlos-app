import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_stat_card.dart';

/// Snapshot of the system, driven by the selected sport + time range.
/// Six cards:
///   1. Athletes     — count in selected sport
///   2. Coaches      — count in selected sport
///   3. Pending      — pending absence appeals
///   4. Sessions     — sessions in selected time window
///   5. Active Inj.  — active injuries in selected sport
///   6. Attendance % — attend rate in selected time window
class AdminSnapshotGrid extends StatelessWidget {
  final String? sportFilter;       // null = all sports
  final Duration? timeWindow;      // null = all time
  final DateTime? timeStart;

  const AdminSnapshotGrid({
    super.key,
    required this.sportFilter,
    required this.timeWindow,
    required this.timeStart,
  });

  Future<_SnapshotData> _load() async {
    final fs = FirebaseFirestore.instance;

    // ---- Athletes count ----
    Query athleteQ = fs.collection('users').where('role', isEqualTo: 'Athlete');
    if (sportFilter != null) {
      athleteQ = athleteQ.where('sport', isEqualTo: sportFilter);
    }
    final athletesSnap = await athleteQ.get();

    // ---- Coaches count ----
    Query coachQ = fs.collection('users').where('role', isEqualTo: 'Coach');
    if (sportFilter != null) {
      coachQ = coachQ.where('sport', isEqualTo: sportFilter);
    }
    final coachesSnap = await coachQ.get();

    // ---- Pending appeals ----
    Query appealsQ =
        fs.collection('absence_appeals').where('status', isEqualTo: 'Pending');
    if (sportFilter != null) {
      appealsQ = appealsQ.where('athleteSport', isEqualTo: sportFilter);
    }
    if (timeStart != null) {
      appealsQ =
          appealsQ.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart!));
    }
    final appealsSnap = await appealsQ.get();

    // ---- Sessions ----
    Query sessionsQ = fs.collection('training_sessions');
    if (sportFilter != null) {
      sessionsQ = sessionsQ.where('sport', isEqualTo: sportFilter);
    }
    if (timeStart != null) {
      sessionsQ = sessionsQ.where('startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart!));
    }
    final sessionsSnap = await sessionsQ.get();

    // ---- Active injuries ----
    Query injuriesQ =
        fs.collection('injuries').where('status', isEqualTo: 'Active');
    if (timeStart != null) {
      injuriesQ = injuriesQ.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart!));
    }
    final injuriesAll = await injuriesQ.get();

    // Injuries don't store sport directly, so if a sport filter is active,
    // only count injuries of athletes in that sport.
    int activeInjuries = injuriesAll.docs.length;
    if (sportFilter != null) {
      final athleteUids = athletesSnap.docs.map((d) => d.id).toSet();
      activeInjuries = injuriesAll.docs
          .where((d) => athleteUids.contains((d.data() as Map)['uid']))
          .length;
    }

    // ---- Attendance rate ----
    Query attendanceQ = fs.collection('attendance');
    if (timeStart != null) {
      attendanceQ = attendanceQ.where('sessionStartTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart!));
    }
    final attendanceSnap = await attendanceQ.get();
    int totalMarks = attendanceSnap.docs.length;
    int presentMarks = attendanceSnap.docs
        .where((d) => (d.data() as Map)['status'] == 'Present')
        .length;

    // If sport filter is active, filter attendance by marked athletes' sport.
    if (sportFilter != null) {
      final athleteUids = athletesSnap.docs.map((d) => d.id).toSet();
      final filtered = attendanceSnap.docs
          .where((d) => athleteUids.contains((d.data() as Map)['athleteUid']))
          .toList();
      totalMarks = filtered.length;
      presentMarks = filtered
          .where((d) => (d.data() as Map)['status'] == 'Present')
          .length;
    }

    final attendanceRate = totalMarks == 0
        ? 0
        : ((presentMarks / totalMarks) * 100).round();

    return _SnapshotData(
      athletes: athletesSnap.docs.length,
      coaches: coachesSnap.docs.length,
      pendingAppeals: appealsSnap.docs.length,
      sessions: sessionsSnap.docs.length,
      activeInjuries: activeInjuries,
      attendanceRate: attendanceRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SnapshotData>(
      future: _load(),
      builder: (context, snapshot) {
        final d = snapshot.data;
        final isLoading = !snapshot.hasData;

        String v(int? n) => isLoading ? '—' : (n ?? 0).toString();
        String p(int? n) => isLoading ? '—' : '${n ?? 0}%';

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            AdminStatCard(
              icon: Icons.people_alt_rounded,
              label: 'Athletes',
              value: v(d?.athletes),
              color: const Color(0xFF667EEA),
            ),
            AdminStatCard(
              icon: Icons.sports_rounded,
              label: 'Coaches',
              value: v(d?.coaches),
              color: const Color(0xFF10B981),
            ),
            AdminStatCard(
              icon: Icons.inbox_rounded,
              label: 'Pending',
              value: v(d?.pendingAppeals),
              color: const Color(0xFFF59E0B),
            ),
            AdminStatCard(
              icon: Icons.event_available_rounded,
              label: 'Sessions',
              value: v(d?.sessions),
              color: const Color(0xFF3B82F6),
            ),
            AdminStatCard(
              icon: Icons.healing_rounded,
              label: 'Active Inj.',
              value: v(d?.activeInjuries),
              color: const Color(0xFFEF4444),
            ),
            AdminStatCard(
              icon: Icons.percent_rounded,
              label: 'Attend.',
              value: p(d?.attendanceRate),
              color: const Color(0xFF14B8A6),
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotData {
  final int athletes;
  final int coaches;
  final int pendingAppeals;
  final int sessions;
  final int activeInjuries;
  final int attendanceRate;

  _SnapshotData({
    required this.athletes,
    required this.coaches,
    required this.pendingAppeals,
    required this.sessions,
    required this.activeInjuries,
    required this.attendanceRate,
  });
}