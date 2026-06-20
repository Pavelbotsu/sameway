import 'package:flutter/services.dart';

/// Named haptic helpers so call sites can express *intent*
/// (`Haptics.confirm()`, `Haptics.reject()`) instead of repeating
/// raw `HapticFeedback` plumbing and re-deciding the impact level
/// at every call point.
///
/// All methods are fire-and-forget; failures (web, desktop, OEM with
/// disabled vibration) are swallowed silently.
abstract class Haptics {
  /// Accept ride, submit pickup code success, dropoff. Mediumimpact bump.
  static Future<void> confirm() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Decline ride, pickup-code mismatch. Sharp double-pulse via vibrate.
  static Future<void> reject() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// SOS confirm, ride-cancellation confirm — high-stakes commitment.
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Map marker tap, sheet snap-point, chat send. Crisp selection click.
  static Future<void> tap() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Pull-to-refresh threshold reached. Subtle.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
