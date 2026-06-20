import 'dart:async';

/// Session-expiry hook. ApiClient fires it when a request that *had* an
/// Authorization header comes back 401 — that's the JWT-expired signal.
/// 403s are resource-permission errors (wrong role, not part of the ride)
/// and do NOT fire this. Unauthenticated 401s (no token sent) also don't
/// fire, otherwise a polling loop after logout would re-trigger forever.
///
/// main.dart listens and reacts by clearing storage + navigating to
/// AuthScreen with a localized SnackBar. Decoupled from any widget tree so
/// ApiClient doesn't need a BuildContext.
///
/// Single broadcast stream is enough — we only ever have one active root
/// listener. A throttle guards against expiry bursts (multiple concurrent
/// requests all hitting 401) collapsing into a single navigation.
class SessionEvents {
  SessionEvents._();
  static final SessionEvents instance = SessionEvents._();

  final _ctrl = StreamController<void>.broadcast();
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<void> get onExpired => _ctrl.stream;

  /// Idempotent — first call within 5 s of the last one is a no-op. Real
  /// session expiry only happens once per user action; the throttle just
  /// prevents the "10 concurrent calls all 401" cascade.
  void fireExpired() {
    final now = DateTime.now();
    if (now.difference(_lastFire) < const Duration(seconds: 5)) return;
    _lastFire = now;
    _ctrl.add(null);
  }
}
