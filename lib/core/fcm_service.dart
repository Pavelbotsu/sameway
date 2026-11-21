import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../l10n/l10n.dart';
import 'api_client.dart';
import 'language_provider.dart';
import 'token_storage.dart';
import 'widgets/pre_permission_sheet.dart';

/// Three named channels matching the backend's FCM payloads. The Android OS
/// surfaces each independently in Settings → Notifications, so users can
/// silence chat without losing critical ride alerts. Channel IDs must match
/// the `ChannelID` strings the backend stamps into AndroidConfig.
class FcmChannels {
  // Names and descriptions are in the app language (ARB); re-creating a
  // channel with the same id renames it in Android Settings.
  static AndroidNotificationChannel ride(L10n l) => AndroidNotificationChannel(
    'ride_critical',
    l.notif_channelRide,
    description: l.notif_channelRideDesc,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  static AndroidNotificationChannel chat(L10n l) => AndroidNotificationChannel(
    'chat',
    l.notif_channelChat,
    description: l.notif_channelChatDesc,
    importance: Importance.defaultImportance,
    playSound: true,
  );
  static AndroidNotificationChannel marketing(L10n l) =>
      AndroidNotificationChannel(
    'marketing',
    l.notif_channelMarketing,
    description: l.notif_channelMarketingDesc,
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

  /// Phase 3.6: create the three named channels on Android so the OS lists
  /// them in Settings → Notifications with independent toggles. No-op on
  /// iOS (channel concept doesn't exist there) and on the web. Called again
  /// when the app language changes: same ids, new names.
  static Future<void> createChannels(Locale locale) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final l = l10nFor(locale);
    await android.createNotificationChannel(FcmChannels.ride(l));
    await android.createNotificationChannel(FcmChannels.chat(l));
    await android.createNotificationChannel(FcmChannels.marketing(l));
  }

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    await createChannels(await LanguageProvider.storedOrDevice());

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
      // Bounded: this had no timeout, so a hung connection left the future
      // pending for the process lifetime.
      await http
          .put(
            Uri.parse('$kApiBase/auth/fcm-token'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Best-effort: onTokenRefresh and the next app start retry it.
    }
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
