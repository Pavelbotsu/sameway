import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'token_storage.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Background/terminated — Flutter engine not fully running, keep this minimal.
}

class FcmService {
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
