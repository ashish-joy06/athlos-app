import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FcmListener extends StatefulWidget {
  const FcmListener({super.key, required this.child});

  final Widget child;

  @override
  State<FcmListener> createState() => _FcmListenerState();
}

class _FcmListenerState extends State<FcmListener> {
  @override
  void initState() {
    super.initState();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final title = message.notification!.title ?? 'Notification';
        final body = message.notification!.body ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Optional: Handle when app is opened from background/tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked: ${message.data}');
      // Navigate or handle accordingly if you want
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
