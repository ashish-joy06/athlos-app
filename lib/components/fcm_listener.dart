import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

/// Wraps the app and:
///  - saves/refreshes the FCM token for the current user (existing behavior)
///  - listens to the `notifications` collection for docs addressed to me
///    and shows a local notification for each new one
class FcmListener extends StatefulWidget {
  final Widget child;
  const FcmListener({super.key, required this.child});

  @override
  State<FcmListener> createState() => _FcmListenerState();
}

class _FcmListenerState extends State<FcmListener> {
  StreamSubscription<QuerySnapshot>? _sub;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await NotificationService.instance.init();
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Only unread, addressed to me, newest first.
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        if (_seenIds.contains(doc.id)) continue;
        _seenIds.add(doc.id);

        final data = doc.data() ?? {};
        final title = (data['title'] ?? 'Athlos').toString();
        final body = (data['body'] ?? '').toString();

        await NotificationService.instance.show(
          title: title,
          body: body,
          payload: doc.id,
        );

        // Mark as read so it won't fire again on re-login.
        try {
          await doc.reference.update({'read': true});
        } catch (_) {
          // If rules deny it, silently ignore.
        }
      }
    }, onError: (e) {
      debugPrint('Notification stream error: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}