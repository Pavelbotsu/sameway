import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks device-level network reachability via connectivity_plus and exposes
/// a single `isOnline` boolean for the [ConnectivityPill] to observe.
///
/// connectivity_plus on its own only reports the radio state (wifi vs mobile
/// vs none) — actual reachability of our backend is a separate question
/// handled by the WS state on each role provider. So the pill shows:
///   - isOnline=false → "No internet" red pill
///   - isOnline=true && wsState=disconnected → "Reconnecting…" amber pill
///   - both healthy → no pill
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _hydrate();
    _sub = _connectivity.onConnectivityChanged.listen(_update);
  }

  Future<void> _hydrate() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _update(results);
    } catch (_) {/* assume online if the plugin is grumpy */}
  }

  void _update(List<ConnectivityResult> results) {
    // Any non-`none` result counts as online — we don't gate on wifi-only.
    final online =
        results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
