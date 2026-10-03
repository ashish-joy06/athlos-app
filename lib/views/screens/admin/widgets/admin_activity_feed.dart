import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Recent activity feed — merges the newest docs from 5 collections.
class AdminActivityFeed extends StatelessWidget {
  final String? sportFilter;
  final int limit;

  const AdminActivityFeed({
    super.key,
    required this.sportFilter,
    this.limit = 20,
  });

  Future<List<_Activity>> _load() async {
    final fs = FirebaseFirestore.instance;
    final results = <_Activity>[];

    Future<void> pull({
      required String collection,
      required IconData icon,
      required Color color,
      required String Function(Map<String, dynamic>) describe,
      String? sportField,
    }) async {
      Query q = fs.collection(collection);
      if (sportFilter != null && sportField != null) {
        q = q.where(sportField, isEqualTo: sportFilter);
      }
      try {
        final snap = await q
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        for (final d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          final ts = (data['createdAt'] as Timestamp?)?.toDate();
          if (ts == null) continue;
          results.add(_Activity(
            icon: icon,
            color: color,
            text: describe(data),
            when: ts,
          ));
        }
      } catch (_) {
        // Ignore per-collection failures (missing field, no docs, etc.)
      }
    }

    await Future.wait([
      pull(
        collection: 'announcements',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFF59E0B),
        describe: (d) {
          final author = d['authorName'] ?? 'Someone';
          final title = d['title'] ?? '';
          return '$author posted ${title.isNotEmpty ? '"$title"' : 'an announcement'}';
        },
        sportField: 'sport',
      ),
      pull(
        collection: 'absence_appeals',
        icon: Icons.inbox_rounded,
        color: const Color(0xFF667EEA),
        describe: (d) {
          final name = d['athleteName'] ?? 'An athlete';
          return '$name filed an appeal';
        },
        sportField: 'athleteSport',
      ),
      pull(
        collection: 'injuries',
        icon: Icons.healing_rounded,
        color: const Color(0xFFEF4444),
        describe: (d) {
          final desc = d['description'] ?? 'an injury';
          return 'Injury logged: $desc';
        },
      ),
      pull(
        collection: 'training_sessions',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF3B82F6),
        describe: (d) {
          final coach = d['coachName'] ?? 'A coach';
          final title = d['title'] ?? 'a session';
          return '$coach created "$title"';
        },
        sportField: 'sport',
      ),
      pull(
        collection: 'attendance',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF10B981),
        describe: (d) {
          final title = d['sessionTitle'] ?? 'a session';
          return 'Attendance marked for "$title"';
        },
      ),
    ]);

    // If sport filter is active for attendance/injuries, further narrow by athlete.
    
    results.sort((a, b) => b.when.compareTo(a.when));
    return results.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Activity>>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No recent activity.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          );
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
          child: Column(
            children: items.map((a) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(a.icon, size: 16, color: a.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.text,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _rel(a.when),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static String _rel(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _Activity {
  final IconData icon;
  final Color color;
  final String text;
  final DateTime when;
  _Activity({
    required this.icon,
    required this.color,
    required this.text,
    required this.when,
  });
}