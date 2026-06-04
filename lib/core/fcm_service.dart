import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'token_storage.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Background/terminated — Flutter engine not fully running, keep this minimal.
}

class FcmService {
  // Attach to MaterialApp so foreground FCM messages can show a SnackBar
  // without needing a BuildContext.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Refresh token whenever Firebase rotates it.
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      sendTokenToBackend();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      // Suppress in-app banner for ride_request — the bottom offer panel
      // already shows the offer; a SnackBar per nearby driver would flood.
      if (msg.data['type'] == 'ride_request') return;
      final notif = msg.notification;
      final title = notif?.title ?? msg.data['title'] as String?;
      final body = notif?.body ?? msg.data['body'] as String?;
      if (title == null && body == null) return;
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final text = [title, body].whereType<String>().join(': ');
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    });
  }

  /// Call after login/register and on app startup when already logged in.
  static Future<void> sendTokenToBackend() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await http.put(
        Uri.parse('$kApiBase/auth/fcm-token'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {}
  }
}
