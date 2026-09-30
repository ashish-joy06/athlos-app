import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Coach view of all active injuries for athletes in their sport.
class TeamInjuriesScreen extends StatefulWidget {
  const TeamInjuriesScreen({super.key});

  @override
  State<TeamInjuriesScreen> createState() => _TeamInjuriesScreenState();
}

class _TeamInjuriesScreenState extends State<TeamInjuriesScreen> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Injuries'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text('Show all', style: TextStyle(fontSize: 13)),
              Switch(
                value: _showAll,
                onChanged: (v) => setState(() => _showAll = v),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_TeamInjuriesData>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null || data.injuries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _showAll
                      ? 'No injuries logged for your athletes.'
                      : 'No active injuries for your athletes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.injuries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final injury = data.injuries[i];
              final name = data.athleteNames[injury['uid']] ?? 'Athlete';
              return _buildCard(name, injury);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(String athleteName, Map<String, dynamic> injury) {
    final description = injury['description'] ?? '';
    final notes = injury['notes'] ?? '';
    final status = (injury['status'] ?? 'Active').toString();
    String dateStr = '';
    try {
      dateStr = DateFormat('MMM d, yyyy')
          .format(DateTime.parse(injury['date'] ?? ''));
    } catch (_) {
      dateStr = injury['date']?.toString() ?? '';
    }
    final isActive = status == 'Active';
    final color =
        isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.healing_rounded,
                  color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  athleteName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description.toString(),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: $dateStr',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (notes.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: $notes',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Future<_TeamInjuriesData> _loadData() async {
    final me = FirebaseAuth.instance.currentUser!;
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .get();
    final myRole = (myDoc.data()?['role'] ?? 'Coach').toString();
    final mySport = (myDoc.data()?['sport'] ?? 'Athletics').toString();

    // Load athletes in my sport (or all athletes if admin).
    Query athletesQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Athlete');
    if (myRole != 'Admin') {
      athletesQuery = athletesQuery.where('sport', isEqualTo: mySport);
    }
    final athleteDocs = await athletesQuery.get();

    final athleteNames = <String, String>{};
    for (final doc in athleteDocs.docs) {
      final d = doc.data() as Map<String, dynamic>;
      athleteNames[doc.id] = (d['name'] ?? 'Athlete').toString();
    }
    if (athleteNames.isEmpty) {
      return _TeamInjuriesData(injuries: const [], athleteNames: athleteNames);
    }

    // Fetch injuries for these athletes.
    final uids = athleteNames.keys.toList();
    // Firestore `whereIn` supports up to 30 ids per query — chunk if needed.
    final List<Map<String, dynamic>> injuries = [];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(
          i, (i + 30 > uids.length) ? uids.length : i + 30);
      final snap = await FirebaseFirestore.instance
          .collection('injuries')
          .where('uid', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .get();
      for (final doc in snap.docs) {
        injuries.add({'id': doc.id, ...doc.data()});
      }
    }

    // Filter active only when toggle is off.
    final filtered = _showAll
        ? injuries
        : injuries
            .where((i) => (i['status'] ?? 'Active').toString() == 'Active')
            .toList();

    // Sort by createdAt desc.
    filtered.sort((a, b) {
      final ta = a['createdAt'] as Timestamp?;
      final tb = b['createdAt'] as Timestamp?;
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });

    return _TeamInjuriesData(
      injuries: filtered,
      athleteNames: athleteNames,
    );
  }
}

class _TeamInjuriesData {
  final List<Map<String, dynamic>> injuries;
  final Map<String, String> athleteNames;
  _TeamInjuriesData({required this.injuries, required this.athleteNames});
}