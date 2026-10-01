import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'captain_mark_attendance_screen.dart';

/// Main captain's "My Squad" screen.
/// Shows every user whose reportsToUid chain leads back to the captain,
/// plus the captain themselves.
/// Tapping "Mark Attendance" opens the captain's scoped marking screen.
class MySquadScreen extends StatefulWidget {
  const MySquadScreen({super.key});

  @override
  State<MySquadScreen> createState() => _MySquadScreenState();
}

class _MySquadScreenState extends State<MySquadScreen> {
  String? _myUid;
  String? _mySport;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _myUid = uid;
      _mySport = (data['sport'] ?? 'Athletics').toString();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Squad'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('sport', isEqualTo: _mySport)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!.docs
              .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .toList();

          final squad = _resolveSquad(all);

          if (squad.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No athletes in your squad yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      '${squad.length} in your squad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Includes you and everyone who reports to you.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: squad.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final u = squad[i];
                    final isMe = u['id'] == _myUid;
                    final isCaptain = u['isCaptain'] == true;
                    final level = u['captainLevel']?.toString();
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMe
                              ? const Color(0xFF667EEA)
                              : isCaptain
                                  ? const Color(0xFFF59E0B)
                                  : Colors.grey.shade400,
                          child: Icon(
                            isMe
                                ? Icons.person
                                : isCaptain
                                    ? Icons.star_rounded
                                    : Icons.person_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                (u['name'] ?? 'Athlete').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667EEA)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF667EEA),
                                  ),
                                ),
                              ),
                            ],
                            if (isCaptain && !isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  level == 'main' ? 'MAIN' : 'CAPTAIN',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          (u['events'] is List && (u['events'] as List).isNotEmpty)
                              ? (u['events'] as List).take(3).join(', ')
                              : '—',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CaptainMarkAttendanceScreen(
                              squad: squad,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Mark Squad Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Walk the `reportsToUid` chain and collect everyone under me,
  /// plus myself.
  List<Map<String, dynamic>> _resolveSquad(
      List<Map<String, dynamic>> all) {
    final result = <Map<String, dynamic>>[];
    final allById = {for (final u in all) u['id'] as String: u};

    for (final u in all) {
      final id = u['id'] as String;
      if (id == _myUid) {
        result.add(u);
        continue;
      }
      // Walk up the chain; if we hit myUid, include them
      var cursor = u['reportsToUid']?.toString();
      final visited = <String>{};
      while (cursor != null && cursor.isNotEmpty && !visited.contains(cursor)) {
        if (cursor == _myUid) {
          result.add(u);
          break;
        }
        visited.add(cursor);
        final parent = allById[cursor];
        if (parent == null) break;
        cursor = parent['reportsToUid']?.toString();
      }
    }
    result.sort((a, b) {
      final ca = a['isCaptain'] == true ? 1 : 0;
      final cb = b['isCaptain'] == true ? 1 : 0;
      if (ca != cb) return cb.compareTo(ca);
      return (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString());
    });
    return result;
  }
}