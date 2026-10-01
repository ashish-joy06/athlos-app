import 'package:athletix/models/athletics_events.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that lets an admin or coach edit a user's gender and events.
/// Opens via `showUserEditSheet(context, uid, initialData)`.
Future<void> showUserEditSheet(
  BuildContext context, {
  required String uid,
  required Map<String, dynamic> initialData,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UserEditSheet(uid: uid, initialData: initialData),
  );
}

class _UserEditSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> initialData;
  const _UserEditSheet({required this.uid, required this.initialData});

  @override
  State<_UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<_UserEditSheet> {
  late String? _gender;
  late List<String> _events;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialData['gender'];
    _events = List<String>.from(widget.initialData['events'] ?? const []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .update({
      'gender': _gender ?? '',
      'events': _events,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.initialData['name'] ?? 'User';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Edit: $name",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
              ),
              items: AthleticsEvents.genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 20),

            Text(
              "Events (max ${AthleticsEvents.maxSelection})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...AthleticsEvents.grouped.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((event) {
                        final selected = _events.contains(event);
                        return FilterChip(
                          label: Text(event,
                              style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              if (selected) {
                                _events.remove(event);
                              } else if (_events.length <
                                  AthleticsEvents.maxSelection) {
                                _events.add(event);
                              }
                            });
                          },
                          selectedColor:
                              const Color(0xFF667EEA).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF667EEA),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}