import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'notification_service.dart';

/// Helper functions to dispatch notifications for each event type.
/// All of these run client-side while the acting user has the app open
/// (Spark plan workaround — no Cloud Functions).
class NotificationDispatcher {
  NotificationDispatcher._();

  /// Notify all athletes in a sport that a new session was created.
  static Future<void> onSessionCreated({
    required String sessionTitle,
    required String sport,
    required DateTime startTime,
    required String sessionId,
  }) async {
    try {
      final athletes = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Athlete')
          .where('sport', isEqualTo: sport)
          .get();

      final when = DateFormat('MMM d, h:mm a').format(startTime);
      final title = 'New session: $sessionTitle';
      final body = 'Starts $when';

      for (final doc in athletes.docs) {
        await writeNotification(
          toUid: doc.id,
          title: title,
          body: body,
          type: 'session',
          data: {'sessionId': sessionId},
        );
      }
    } catch (e) {
      debugPrint('NotificationDispatcher.onSessionCreated error: $e');
    }
  }

  /// Notify users who should see a new announcement.
  /// - If `sport` is null (admin), notify everyone.
  /// - If `sport` is set (coach), notify athletes + coaches in that sport.
  static Future<void> onAnnouncementPosted({
    required String message,
    required String? sport,
    required String announcementId,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      if (sport != null && sport.isNotEmpty) {
        query = query.where('sport', isEqualTo: sport);
      }
      final users = await query.get();

      final title = 'Announcement';
      final body = message.length > 120
          ? '${message.substring(0, 117)}...'
          : message;

      for (final doc in users.docs) {
        await writeNotification(
          toUid: doc.id,
          title: title,
          body: body,
          type: 'announcement',
          data: {'announcementId': announcementId},
        );
      }
    } catch (e) {
      debugPrint('NotificationDispatcher.onAnnouncementPosted error: $e');
    }
  }

  /// Notify each athlete whose attendance was just marked.
  static Future<void> onAttendanceMarked({
    required Map<String, String> marksByUid,
    required String sessionTitle,
    required String sessionId,
  }) async {
    try {
      for (final entry in marksByUid.entries) {
        await writeNotification(
          toUid: entry.key,
          title: 'Attendance marked',
          body: '$sessionTitle — you were marked ${entry.value}',
          type: 'attendance',
          data: {'sessionId': sessionId, 'status': entry.value},
        );
      }
    } catch (e) {
      debugPrint('NotificationDispatcher.onAttendanceMarked error: $e');
    }
  }
}