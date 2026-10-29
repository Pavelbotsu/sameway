import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Remote Config, initialized once at startup
/// (see main.dart, right after Firebase.initializeApp).
///
/// `init()` never throws: on a cold offline start `fetchAndActivate` fails
/// with the in-code defaults still in place, which is exactly the intended
/// degraded behavior — startup must not block or crash on Remote Config.
///
/// Currently declares no parameters. The one it used to expose
/// (`carry_distance_threshold_m`, via a `carryThreshold` getter) had no
/// consumer: the carry-distance gate is enforced entirely server-side in the Go
/// matching query, where it belongs — a client-side copy could only ever
/// disagree with it. The getter was removed rather than left as a speculative
/// integration point.
///
/// The service itself is kept because it is wired into startup and is the place
/// a real remote-config flag would go.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService _instance = RemoteConfigService._();
  factory RemoteConfigService() => _instance;

  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> init() async {
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 15),
      ));
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      // Offline / throttled / first-run without network: defaults stand.
      debugPrint('RemoteConfig init failed (defaults in effect): $e');
    }
  }
}
