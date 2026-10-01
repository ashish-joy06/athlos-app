import 'package:athletix/components/user_edit_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Coach's "My Athletes" screen.
/// Tabs:
///   - All in my sport — flat list with captain badges
///   - My hierarchy     — tree view (Main Captain → Sub → Athlete)
/// Tap a row → edit gender/events.
/// ⋮ menu → Promote / Demote / Reassign superior.
class CoachAthletesScreen extends StatefulWidget {
  const CoachAthletesScreen({super.key});

  @override
  State<CoachAthletesScreen> createState() => _CoachAthletesScreenState();
}

class _CoachAthletesScreenState extends State<CoachAthletesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String? _myUid;
  String? _mySport;
  String? _myRole;
  String? _myCaptainLevel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
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
      _myRole = (data['role'] ?? 'Coach').toString();
      _myCaptainLevel = data['captainLevel']?.toString();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
        title: const Text('My Athletes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF667EEA),
          tabs: const [
            Tab(text: 'All in my sport'),
            Tab(text: 'My hierarchy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AthleteList(
            myUid: _myUid!,
            mySport: _mySport!,
            myRole: _myRole!,
            myCaptainLevel: _myCaptainLevel,
          ),
          _HierarchyView(
            myUid: _myUid!,
            mySport: _mySport!,
            myRole: _myRole!,
            myCaptainLevel: _myCaptainLevel,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ALL IN MY SPORT — flat list
// ─────────────────────────────────────────────────────────────

class _AthleteList extends StatelessWidget {
  final String myUid;
  final String mySport;
  final String myRole;
  final String? myCaptainLevel;

  const _AthleteList({
    required this.myUid,
    required this.mySport,
    required this.myRole,
    required this.myCaptainLevel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Athlete')
          .where('sport', isEqualTo: mySport)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final ca = (da['isCaptain'] == true) ? 1 : 0;
          final cb = (db['isCaptain'] == true) ? 1 : 0;
          if (ca != cb) return cb.compareTo(ca);
          return (da['name'] ?? '').toString().compareTo(
                (db['name'] ?? '').toString(),
              );
        });

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No athletes in your sport yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _AthleteTile(
              uid: docs[i].id,
              data: data,
              myUid: myUid,
              myRole: myRole,
              myCaptainLevel: myCaptainLevel,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MY HIERARCHY — tree view
// ─────────────────────────────────────────────────────────────

class _HierarchyView extends StatelessWidget {
  final String myUid;
  final String mySport;
  final String myRole;
  final String? myCaptainLevel;

  const _HierarchyView({
    required this.myUid,
    required this.mySport,
    required this.myRole,
    required this.myCaptainLevel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('sport', isEqualTo: mySport)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = <String, Map<String, dynamic>>{};
        for (final d in snapshot.data!.docs) {
          users[d.id] = {'id': d.id, ...(d.data() as Map<String, dynamic>)};
        }

        // Determine top-level nodes based on the viewer's role:
        // - Coach/Admin: main captains under them, plus athletes reporting to coach
        // - Main captain: their direct reports
        final List<Map<String, dynamic>> roots = [];
        for (final u in users.values) {
          final isCaptain = u['isCaptain'] == true;
          final level = u['captainLevel']?.toString();
          final reportsTo = u['reportsToUid']?.toString();

          if (myRole == 'Coach' || myRole == 'Admin') {
            if (isCaptain && level == 'main' && reportsTo == myUid) {
              roots.add(u);
            } else if (!isCaptain && reportsTo == myUid) {
              roots.add(u);
            }
          } else if (myCaptainLevel == 'main') {
            if (reportsTo == myUid) roots.add(u);
          }
        }

        if (roots.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No athletes assigned to you yet.\n'
                'Use "All in my sport" to promote athletes to captain '
                'or assign them under you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final r in roots)
              _TreeNode(
                user: r,
                users: users,
                depth: 0,
                myUid: myUid,
                myRole: myRole,
                myCaptainLevel: myCaptainLevel,
              ),
          ],
        );
      },
    );
  }
}

class _TreeNode extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, Map<String, dynamic>> users;
  final int depth;
  final String myUid;
  final String myRole;
  final String? myCaptainLevel;

  const _TreeNode({
    required this.user,
    required this.users,
    required this.depth,
    required this.myUid,
    required this.myRole,
    required this.myCaptainLevel,
  });

  List<Map<String, dynamic>> _childrenOf(String uid) {
    return users.values
        .where((u) => u['reportsToUid']?.toString() == uid)
        .toList()
      ..sort((a, b) {
        final ca = a['isCaptain'] == true ? 1 : 0;
        final cb = b['isCaptain'] == true ? 1 : 0;
        if (ca != cb) return cb.compareTo(ca);
        return (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString());
      });
  }

  @override
  Widget build(BuildContext context) {
    final children = _childrenOf(user['id'] as String);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: _AthleteTile(
            uid: user['id'] as String,
            data: user,
            myUid: myUid,
            myRole: myRole,
            myCaptainLevel: myCaptainLevel,
          ),
        ),
        for (final c in children)
          _TreeNode(
            user: c,
            users: users,
            depth: depth + 1,
            myUid: myUid,
            myRole: myRole,
            myCaptainLevel: myCaptainLevel,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED TILE
// ─────────────────────────────────────────────────────────────

class _AthleteTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final String myUid;
  final String myRole;
  final String? myCaptainLevel;

  const _AthleteTile({
    required this.uid,
    required this.data,
    required this.myUid,
    required this.myRole,
    required this.myCaptainLevel,
  });

  bool get _isMainCaptain =>
      myRole == 'Athlete' && myCaptainLevel == 'main';
  bool get _isCoachOrAdmin => myRole == 'Coach' || myRole == 'Admin';

  /// Can this viewer promote/demote this row?
  bool get _canManage {
    if (_isCoachOrAdmin) return true;
    if (_isMainCaptain) {
      // Only direct reports that are not themselves main captains
      final reportsTo = data['reportsToUid']?.toString();
      final level = data['captainLevel']?.toString();
      final isCaptain = data['isCaptain'] == true;
      if (reportsTo != myUid) return false;
      // Can promote athlete → sub, or demote sub → athlete
      if (!isCaptain) return true;
      if (isCaptain && level == 'sub') return true;
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Athlete').toString();
    final isCaptain = data['isCaptain'] == true;
    final level = data['captainLevel']?.toString();
    final events = List<String>.from(data['events'] ?? const []);
    final gender = (data['gender'] ?? '').toString();

    final subtitleParts = <String>[
      if (gender.isNotEmpty) gender,
      if (events.isNotEmpty) events.take(3).join(', ') +
          (events.length > 3 ? ' +${events.length - 3}' : ''),
    ];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => showUserEditSheet(
          context,
          uid: uid,
          initialData: data,
        ),
        leading: CircleAvatar(
          backgroundColor:
              isCaptain ? const Color(0xFFF59E0B) : const Color(0xFF667EEA),
          child: Icon(
            isCaptain ? Icons.star_rounded : Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCaptain) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  level == 'main' ? 'MAIN CAPTAIN' : 'CAPTAIN',
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
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' • '),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
        trailing: _canManage
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) => _handle(context, v),
                itemBuilder: (_) => [
                  if (isCaptain && level == 'sub')
                    const PopupMenuItem(
                      value: 'demote',
                      child: Text('Demote to Athlete'),
                    )
                  else if (isCaptain && level == 'main' && _isCoachOrAdmin)
                    const PopupMenuItem(
                      value: 'demote',
                      child: Text('Demote Main Captain'),
                    )
                  else ...[
                    const PopupMenuItem(
                      value: 'promote_sub',
                      child: Text('Promote to Sub Captain'),
                    ),
                    if (_isCoachOrAdmin)
                      const PopupMenuItem(
                        value: 'promote_main',
                        child: Text('Promote to Main Captain'),
                      ),
                  ],
                  if (!isCaptain && _isCoachOrAdmin)
                    const PopupMenuItem(
                      value: 'assign_me',
                      child: Text('Assign to Me'),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _handle(BuildContext context, String action) async {
    switch (action) {
      case 'promote_sub':
        await _promote(context, 'sub');
        break;
      case 'promote_main':
        await _promote(context, 'main');
        break;
      case 'demote':
        await _demote(context);
        break;
      case 'assign_me':
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'reportsToUid': myUid});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assigned to you')),
          );
        }
        break;
    }
  }

  Future<void> _promote(BuildContext context, String level) async {
    // Decide supervisor:
    // - Coach/Admin promoting to sub → assign under themselves
    // - Coach/Admin promoting to main → assign under themselves (coach)
    // - Main captain promoting to sub → assign under themselves
    final reportsTo = myUid;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isCaptain': true,
      'captainLevel': level,
      'reportsToUid': reportsTo,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Promoted to ${level == 'main' ? 'Main Captain' : 'Sub Captain'}'),
        ),
      );
    }
  }

  Future<void> _demote(BuildContext context) async {
    // Count direct reports
    final reportsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('reportsToUid', isEqualTo: uid)
        .get();

    if (reportsSnap.docs.isNotEmpty) {
      // Show confirmation dialog explaining the cascade
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demote this captain?'),
          content: Text(
            '${reportsSnap.docs.length} user(s) report to ${data['name'] ?? 'them'}.\n\n'
            'They will be reassigned to you. You can then reassign them to a '
            'new captain from the hierarchy view.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Demote & reassign',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Cascade: move each direct report to the demoter (me)
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in reportsSnap.docs) {
        batch.update(doc.reference, {'reportsToUid': myUid});
      }
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'isCaptain': false,
          'captainLevel': null,
          'reportsToUid': myUid,
        },
      );
      await batch.commit();
    } else {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isCaptain': false,
        'captainLevel': null,
        'reportsToUid': myUid,
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demoted to Athlete')),
      );
    }
  }
}