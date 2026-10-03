import 'package:athletix/views/screens/coach/edit_session_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Admin view of all training sessions across every sport.
/// Filter by sport. Edit or delete any session.
class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  String? _sportFilter; // null = All Sports
  List<String> _sports = const ['Athletics'];

  static const Map<String, _Color> _colorMap = {
    'purple': _Color(Color(0xFF667EEA)),
    'green': _Color(Color(0xFF10B981)),
    'red': _Color(Color(0xFFEF4444)),
    'blue': _Color(Color(0xFF3B82F6)),
    'orange': _Color(Color(0xFFF59E0B)),
    'grey': _Color(Color(0xFF94A3B8)),
  };

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    final snap = await FirebaseFirestore.instance
        .collection('training_sessions')
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

  Color _colorFor(String? name) {
    return _colorMap[name]?.color ?? const Color(0xFF667EEA);
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete "$title"? This cannot be undone.'),
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
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('training_sessions')
          .doc(id)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('All Sessions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Sport filter
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
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
                        onChanged: (v) =>
                            setState(() => _sportFilter = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('training_sessions')
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                final all = snapshot.data?.docs ?? [];
                final docs = _sportFilter == null
                    ? all
                    : all
                        .where((d) =>
                            (d.data() as Map)['sport'] == _sportFilter)
                        .toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No sessions found.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final color = _colorFor(data['color']?.toString());
                    final start =
                        (data['startTime'] as Timestamp?)?.toDate();
                    final end = (data['endTime'] as Timestamp?)?.toDate();
                    final sport = (data['sport'] ?? '').toString();
                    final title = (data['title'] ?? 'Session').toString();
                    final location = (data['location'] ?? '').toString();
                    final coach = (data['coachName'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(color: color, width: 5),
                        ),
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
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditSessionScreen(
                                          sessionId: docs[i].id,
                                          initialData: data,
                                        ),
                                      ),
                                    );
                                  } else if (v == 'delete') {
                                    await _delete(docs[i].id, title);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (start != null)
                            Text(
                              '${DateFormat('MMM d, yyyy').format(start)} • '
                              '${DateFormat('h:mm a').format(start)}'
                              '${end != null ? ' – ${DateFormat('h:mm a').format(end)}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  sport.isEmpty ? '—' : sport,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (coach.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'by $coach',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Color {
  final Color color;
  const _Color(this.color);
}