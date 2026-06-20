import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'token_storage.dart';
import 'widgets/pre_permission_sheet.dart';

/// Three named channels matching the backend's FCM payloads. The Android OS
/// surfaces each independently in Settings → Notifications, so users can
/// silence chat without losing critical ride alerts. Channel IDs must match
/// the `ChannelID` strings the backend stamps into AndroidConfig.
class FcmChannels {
  static const ride = AndroidNotificationChannel(
    'ride_critical',
    'Ride alerts',
    description: 'Ride offers, accepted, pickup, and ride-completion events.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  static const chat = AndroidNotificationChannel(
    'chat',
    'Chat messages',
    description: 'New messages from your driver or passenger.',
    importance: Importance.defaultImportance,
    playSound: true,
  );
  static const marketing = AndroidNotificationChannel(
    'marketing',
    'Promotions & tips',
    description: 'Optional promotional and informational notifications.',
    importance: Importance.low,
    playSound: false,
  );
}

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

    // Phase 3.6: create the three named channels on Android so the OS lists
    // them in Settings → Notifications with independent toggles. No-op on
    // iOS (channel concept doesn't exist there) and on the web.
    if (!kIsWeb && Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android =
          plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(FcmChannels.ride);
        await android.createNotificationChannel(FcmChannels.chat);
        await android.createNotificationChannel(FcmChannels.marketing);
      }
    }

    // Phase 1.7: permission is no longer requested here (no BuildContext at
    // app startup). Home screens call `maybeRequestPermissionWithRationale`
    // once we have a UI to anchor the rationale sheet to.

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

  /// Phase 1.7: show the rationale sheet (once per install) and then request
  /// the OS notification permission. Safe to call multiple times — the
  /// rationale flag in TokenStorage prevents repeat prompts, and the FCM
  /// `requestPermission` call is itself idempotent.
  static Future<void> maybeRequestPermissionWithRationale(
      BuildContext context) async {
    final storage = TokenStorage();
    final shown = await storage.hasShownNotificationRationale();
    if (shown) return;
    if (!context.mounted) return;
    final accepted = await PrePermissionSheet.askNotifications(context);
    await storage.markNotificationRationaleShown();
    if (!accepted) return;
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
  }
}
