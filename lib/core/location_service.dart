import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'token_storage.dart';

/// Keeps the driver's position reaching the server while the app is not in the
/// foreground.
///
/// Why this exists: every server-side match path gates on
/// `current_location_at > NOW() - MATCH_LOC_FRESH_S`. The app's own
/// `Timer.periodic` only runs while the Flutter isolate is awake, so a driver
/// who locked their phone — the normal state of a phone in a car — stopped
/// refreshing that timestamp and silently dropped out of matching. Passengers
/// then saw no drivers, and the driver saw nothing wrong at all.
///
/// Design notes:
///  * This is ADDITIVE. The in-app timer in driver_home_screen still runs and
///    still works; the service is redundancy for when it can't. If the service
///    fails to start (permission denied, OEM restriction) the app keeps
///    working in the foreground, and DriverProvider warns the driver that
///    they will disappear from matching once the screen locks.
///  * Requires the `<service … foregroundServiceType="location">` declaration
///    in AndroidManifest.xml; without it every start fails on Android 14+.
///  * The callback runs in a SEPARATE isolate with no access to app state, so
///    it reads the JWT from storage and posts directly rather than going
///    through ApiClient.
///
/// Android only — [start] is a no-op elsewhere.
class LocationService {
  static bool _initialized = false;

  /// Whether a background location service is running.
  static Future<bool> get isRunning async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sameway_location',
        channelName: 'Sharing your route',
        channelDescription:
            'Keeps you visible to matching passengers while you drive.',
        // LOW: this notification is a legal/OS requirement, not something the
        // driver needs to look at. Don't buzz them at the wheel.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Matches the in-app timer. The server's freshness window is 120s, so
        // this leaves room for several missed ticks.
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Why the last [start] failed, for logs and crash reports. Null after a
  /// successful start.
  static String? lastError;

  /// Starts the service. Safe to call repeatedly. Returns true when the
  /// service is running, and also on platforms where it does not apply
  /// (nothing to warn about there). Returns false when it could not start —
  /// callers should warn the driver (they will drop out of matching once the
  /// screen locks) but otherwise carry on, since the in-app timer still runs.
  static Future<bool> start() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      // A location-type foreground service throws SecurityException on
      // Android 14+ without a granted location permission. Check first so the
      // failure has a readable reason instead of an opaque platform error.
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return _fail('location permission not granted ($perm)');
      }
      _init();
      if (await FlutterForegroundTask.isRunningService) {
        lastError = null;
        return true;
      }
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'Sameway is sharing your route',
        notificationText: 'Passengers heading your way can find you.',
        callback: _locationTaskEntry,
      );
      if (result is ServiceRequestFailure) {
        return _fail('startService failed: ${result.error}');
      }
      lastError = null;
      return true;
    } catch (e) {
      // Never let this break the drive flow — the app-level timer still runs.
      return _fail('startService threw: $e');
    }
  }

  static bool _fail(String reason) {
    lastError = reason;
    debugPrint('LocationService: $reason');
    // Non-fatal, so a broken start shows up in Crashlytics instead of only on
    // a driver's screen. Honours the user's crash-reporting consent.
    FirebaseCrashlytics.instance
        .recordError(StateError(reason), StackTrace.current,
            reason: 'background location start', fatal: false)
        .catchError((Object _) {});
    return false;
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

/// Isolate entry point. Must be a top-level function annotated for AOT.
@pragma('vm:entry-point')
void _locationTaskEntry() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

class _LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await http
          .put(
            Uri.parse('$kApiBase/driver/location'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
            body: '{"lat":${pos.latitude},"lng":${pos.longitude}}',
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // A missed tick is fine — the freshness window tolerates several.
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
