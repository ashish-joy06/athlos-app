import 'package:flutter/material.dart';

/// Placeholder. The real appeal form (with the 6-hour cutoff and
/// session picker) is built in Batch 2C.
class AbsenceAppealScreen extends StatelessWidget {
  const AbsenceAppealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeal Absence'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Appeal form coming soon.\n\nYou will be able to select an upcoming training session and submit a reason for absence up to 6 hours before the session begins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
        ),
      ),
    );
  }
}