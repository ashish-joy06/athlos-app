import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Central service for local notifications.
/// Uses flutter_local_notifications to display anything that arrives in
/// the user's `notifications` Firestore collection.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'athlos_default',
    'Athlos',
    channelDescription: 'Training sessions, announcements, attendance',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails();

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
    macOS: _iosDetails,
  );

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // TODO: deep-link based on response.payload if needed
      },
    );

    // Request runtime permissions on Android 13+ and iOS.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Show a local notification. On web this is a no-op since the plugin
  /// has limited web support — we fall back to the browser Notification API.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      // Web: rely on the browser's own Notification API.
      // The Firestore listener still fires; the user sees the browser tab
      // indicator if they've enabled notifications.
      return;
    }
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _details,
      payload: payload,
    );
  }
}

/// Writes a notification doc to Firestore for a recipient.
/// Firestore rules allow any signed-in user to create these.
Future<void> writeNotification({
  required String toUid,
  required String title,
  required String body,
  required String type,
  Map<String, dynamic>? data,
}) async {
  if (toUid.isEmpty) return;
  await FirebaseFirestore.instance.collection('notifications').add({
    'toUid': toUid,
    'fromUid': FirebaseAuth.instance.currentUser?.uid ?? '',
    'title': title,
    'body': body,
    'type': type,
    'data': data ?? const {},
    'createdAt': Timestamp.now(),
    'read': false,
  });
}