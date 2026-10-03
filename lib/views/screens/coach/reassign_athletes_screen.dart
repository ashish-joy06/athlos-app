import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Bulk hierarchy manager.
/// Pick a coach or captain on the left, then multi-select athletes on the right
/// and assign them.
class ReassignAthletesScreen extends StatefulWidget {
  const ReassignAthletesScreen({super.key});

  @override
  State<ReassignAthletesScreen> createState() =>
      _ReassignAthletesScreenState();
}

class _ReassignAthletesScreenState extends State<ReassignAthletesScreen> {
  String? _mySport;
  String? _myUid;
  String? _selectedSuperiorUid;
  Map<String, dynamic>? _selectedSuperior;
  final Set<String> _selectedAthletes = {};
  bool _saving = false;
  bool _loading = true;

  List<Map<String, dynamic>> _athletes = const [];
  List<Map<String, dynamic>> _superiors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = FirebaseAuth.instance.currentUser!;
    _myUid = me.uid;
    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .get();
    final mySport = (meDoc.data()?['sport'] ?? 'Athletics').toString();
    _mySport = mySport;

    final athletesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Athlete')
        .where('sport', isEqualTo: mySport)
        .get();

    final superiorsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('sport', isEqualTo: mySport)
        .get();

    if (!mounted) return;

    final athletes = athletesSnap.docs
        .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
        .toList()
      ..sort((a, b) => (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString()));

    // Superiors: coaches (same sport) + main captains (isCaptain + main)
    final superiors = superiorsSnap.docs
        .where((d) {
          final data = d.data();
          final role = (data['role'] ?? '').toString();
          final isCap = data['isCaptain'] == true;
          final level = (data['captainLevel'] ?? '').toString();
          return role == 'Coach' || (isCap && level == 'main');
        })
        .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
        .toList()
      ..sort((a, b) => (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString()));

    setState(() {
      _athletes = athletes;
      _superiors = superiors;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_selectedSuperiorUid == null) return;
    if (_selectedAthletes.isEmpty) {
      _snack('Select at least one athlete');
      return;
    }
    setState(() => _saving = true);

    final batch = FirebaseFirestore.instance.batch();
    for (final uid in _selectedAthletes) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'reportsToUid': _selectedSuperiorUid},
      );
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _saving = false;
      _selectedAthletes.clear();
    });
    _snack('Assigned ${_selectedAthletes.length} athlete(s)');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignment updated')),
    );
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Reassign Athletes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Superior picker
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign selected athletes to:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSuperiorUid,
                      isExpanded: true,
                      hint: const Text('Pick a coach or captain'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18),
                      items: _superiors.map((s) {
                        final role = (s['role'] ?? '').toString();
                        final level = (s['captainLevel'] ?? '').toString();
                        final tag = role == 'Coach'
                            ? 'Coach'
                            : (level == 'main' ? 'Main Captain' : 'Captain');
                        return DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text('${s['name']} • $tag'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _selectedSuperiorUid = v;
                        _selectedSuperior = _superiors
                            .firstWhere((s) => s['id'] == v);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Athlete list with multi-select
          Expanded(
            child: _athletes.isEmpty
                ? const Center(
                    child: Text('No athletes in your sport.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _athletes.length,
                    itemBuilder: (_, i) {
                      final a = _athletes[i];
                      final id = a['id'] as String;
                      final selected = _selectedAthletes.contains(id);
                      final currentSuperior = (a['reportsToUid'] ?? '')
                          .toString();
                      final superiorName = _superiors
                          .firstWhere(
                            (s) => s['id'] == currentSuperior,
                            orElse: () => const {},
                          )['name'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF667EEA)
                                : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedAthletes.add(id);
                              } else {
                                _selectedAthletes.remove(id);
                              }
                            });
                          },
                          title: Text((a['name'] ?? 'Athlete').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            superiorName == null
                                ? 'Currently unassigned'
                                : 'Currently under: $superiorName',
                            style: const TextStyle(fontSize: 12),
                          ),
                          activeColor: const Color(0xFF667EEA),
                        ),
                      );
                    },
                  ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || _selectedAthletes.isEmpty
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
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
                      : Text(
                          'Assign ${_selectedAthletes.length} athlete(s)',
                          style: const TextStyle(fontSize: 15),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}