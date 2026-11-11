import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's choice about optional data collection: Firebase Analytics,
/// Crashlytics crash reports and Performance Monitoring.
///
/// None of these are needed to provide the service, so under GDPR + ePrivacy
/// (PL: Prawo komunikacji elektronicznej art. 399) they run only with consent.
/// AndroidManifest.xml disables all three by default so nothing is collected
/// before [apply] runs; the choice is per device and survives logout.
enum AnalyticsConsent { undecided, granted, denied }

abstract class ConsentService {
  static const _key = 'analytics_consent_v1';

  static Future<AnalyticsConsent> get() async {
    final p = await SharedPreferences.getInstance();
    return switch (p.getString(_key)) {
      'granted' => AnalyticsConsent.granted,
      'denied' => AnalyticsConsent.denied,
      _ => AnalyticsConsent.undecided,
    };
  }

  static Future<void> set(bool granted) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, granted ? 'granted' : 'denied');
    await _setCollection(granted);
  }

  /// Applies the stored choice. Call once at startup, after
  /// Firebase.initializeApp(). Undecided counts as "no".
  static Future<void> apply() async {
    await _setCollection(await get() == AnalyticsConsent.granted);
  }

  static Future<void> _setCollection(bool on) async {
    // Each SDK independently; one failing must not leave the others on.
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on);
    } catch (e) {
      debugPrint('consent: analytics: $e');
    }
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on);
    } catch (e) {
      debugPrint('consent: crashlytics: $e');
    }
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(on);
    } catch (e) {
      debugPrint('consent: performance: $e');
    }
  }
}
