import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Fire-and-forget Firebase Analytics. Every call is void and swallows its
/// own errors — instrumentation must never block or break a ride flow, so
/// call sites log AFTER a confirmed success and move on.
abstract class Analytics {
  static final FirebaseAnalytics _a = FirebaseAnalytics.instance;

  static void logEvent(String name, [Map<String, Object>? params]) {
    _a.logEvent(name: name, parameters: params).catchError((Object e) {
      debugPrint('analytics: logEvent($name) failed: $e');
    });
  }

  /// Ties subsequent events to the signed-in user. Called on every auth
  /// success (login / register / role switch).
  static void setUser(String userId, String role) {
    _a.setUserId(id: userId).catchError((Object e) {
      debugPrint('analytics: setUserId failed: $e');
    });
    _a.setUserProperty(name: 'role', value: role).catchError((Object e) {
      debugPrint('analytics: setUserProperty failed: $e');
    });
  }
}
