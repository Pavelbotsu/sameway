import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;
import 'session.dart';
import 'token_storage.dart';

/// Backend host (and optional port) — the single source of truth for both the
/// HTTP and WebSocket bases (websocket_client.dart). Resolution:
///   1. `--dart-define=API_HOST=...` always wins;
///   2. debug builds: the local dev backend (sameway_backend/scripts/dev.sh)
///      as seen from the Android emulator;
///   3. release builds: the ngrok tunnel used for device testing until the
///      service has a domain. Store builds refuse to run against it — see
///      [kMisconfiguredStoreBuild].
const _definedHost = String.fromEnvironment('API_HOST');
const kLocalDevHost = '10.0.2.2:4040';
const _testTunnelHost = 'ibuprofen-dolly-prison.ngrok-free.dev';
const kApiHost = _definedHost != ''
    ? _definedHost
    : (kReleaseMode ? _testTunnelHost : kLocalDevHost);

/// Plain http/ws only for the local dev backend (or when forced with
/// `--dart-define=API_INSECURE=true`, e.g. a LAN IP). Everything else is TLS.
/// Android blocks cleartext anyway except to the emulator host, and only in
/// debug builds (android/app/src/debug/res/xml/network_security_config.xml).
const kApiInsecure =
    bool.fromEnvironment('API_INSECURE') || kApiHost == kLocalDevHost;
const kApiBase = '${kApiInsecure ? 'http' : 'https'}://$kApiHost';

/// Set with `--dart-define=STORE_BUILD=true` for builds that go to Google
/// Play / the App Store. Such a build refuses to start while it points at a
/// test backend — see [storeBuildProblem].
const kStoreBuild = bool.fromEnvironment('STORE_BUILD');

/// Why this build must not ship, or null. A store build pointing at an ngrok
/// tunnel (the release default until there is a domain), the local dev
/// backend, or plain http would send every user's traffic to a developer
/// machine — and nothing about the build itself would look wrong.
String? storeBuildProblem({
  bool storeBuild = kStoreBuild,
  String host = kApiHost,
  bool insecure = kApiInsecure,
}) {
  if (!storeBuild) return null;
  final h = host.toLowerCase();
  if (h.isEmpty) return 'API_HOST is empty';
  if (h.contains('ngrok')) return 'API_HOST is an ngrok test tunnel ($host)';
  if (h.startsWith('10.0.2.2') || h.startsWith('localhost') || h.startsWith('127.')) {
    return 'API_HOST is a local development address ($host)';
  }
  if (insecure) return 'API_INSECURE is set (plain http)';
  return null;
}
const kWsBase = '${kApiInsecure ? 'ws' : 'wss'}://$kApiHost';
const _base = kApiBase;

// Timeouts are tiered by what the call actually does. A single blanket 120s
// applied to everything, including the 10-second location ping — so a stalled
// ping held the request for two minutes, during which the driver's server-side
// location went stale and they dropped out of matching entirely, with the UI
// still showing a spinner.
//
//  - [_kFastTimeout]  location pings, typing, read receipts: high-frequency,
//                     cheap, and worthless once superseded by the next one.
//  - [_kRoutingTimeout] anything that makes the server call OSRM (route set,
//                     search, pickup route). OSRM itself is bounded at 8s
//                     server-side, so this only needs headroom over that.
//  - [_kStandardTimeout] everything else.
const _kFastTimeout = Duration(seconds: 10);
const _kRoutingTimeout = Duration(seconds: 30);
const _kStandardTimeout = Duration(seconds: 60);

/// Paths whose cost is dominated by an upstream routing call.
bool _isRoutingPath(String path) =>
    path.contains('/route') ||
    path.contains('/search') ||
    path.contains('/reposition') ||
    path.startsWith('/pickup-route');

/// Paths fired on a timer, where a slow response is better abandoned.
bool _isFastPath(String path) =>
    path.endsWith('/location') ||
    path.endsWith('/typing') ||
    path.endsWith('/read') ||
    path.endsWith('/nearby-drivers');

Duration _timeoutFor(String path) {
  if (_isFastPath(path)) return _kFastTimeout;
  if (_isRoutingPath(path)) return _kRoutingTimeout;
  return _kStandardTimeout;
}

class ApiException implements Exception {
  final String message;
  // statusCode is 0 for non-HTTP failures (timeout, parse, transport).
  // `friendlyError` in core/error_handling.dart maps it to a user-facing
  // message; the 401 session-expiry hook lives in ApiClient itself.
  final int statusCode;
  /// Machine-readable reason the backend attaches to some errors, e.g.
  /// `consent_required`, `account_suspended`, `active_ride`, `wrong_password`.
  final String? code;
  const ApiException(this.message, {this.statusCode = 0, this.code});
  @override
  String toString() => message;
}

class ApiClient {
  final TokenStorage _storage;
  ApiClient(this._storage);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final h = await _headers(auth, mutating: true);
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: h,
            body: jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      return _parse(res, authed: h.containsKey('Authorization'));
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final h = await _headers(auth, mutating: true);
      final res = await http
          .put(
            Uri.parse('$_base$path'),
            headers: h,
            body: jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      return _parse(res, authed: h.containsKey('Authorization'));
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  /// POST whose response is a JSON array rather than an object.
  ///
  /// [post] casts the body to a Map and would throw on a list; endpoints like
  /// /passenger/nearby-drivers return one. Shares the same timeout tiering and
  /// 401 → session-expiry handling, which is the point — these calls used to
  /// bypass ApiClient entirely with a raw http.post and got neither.
  Future<dynamic> postRaw(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final h = await _headers(auth, mutating: true);
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: h,
            body: jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      if (res.statusCode >= 400) {
        throw _error(res, authed: h.containsKey('Authorization'));
      }
      return jsonDecode(res.body);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<dynamic> get(String path, {bool auth = false}) async {
    try {
      final h = await _headers(auth, mutating: false);
      final res = await http
          .get(
            Uri.parse('$_base$path'),
            headers: h,
          )
          .timeout(_timeoutFor(path));
      if (res.statusCode >= 400) {
        throw _error(res, authed: h.containsKey('Authorization'));
      }
      return jsonDecode(res.body);
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
  }) async {
    try {
      final h = await _headers(auth, mutating: true);
      final res = await http
          .delete(
            Uri.parse('$_base$path'),
            headers: h,
          )
          .timeout(_timeoutFor(path));
      return _parse(res, authed: h.containsKey('Authorization'));
    } on TimeoutException {
      throw const ApiException('timeout');
    }
  }

  // `mutating` is retained so call sites read intent-revealingly, even though
  // it no longer changes the headers.
  //
  // X-Idempotency-Key used to be set here on every mutating call. The server
  // never read it, and a fresh UUID per ATTEMPT could not have deduplicated a
  // retry even if it had — so it advertised a guarantee that did not exist.
  // Real protection against double-submits lives in the database: the partial
  // unique index uniq_active_ride_request plus ON CONFLICT DO NOTHING in
  // CreateRideRequestFull.
  Future<Map<String, String>> _headers(bool auth, {required bool mutating}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Map<String, dynamic> _parse(http.Response res, {required bool authed}) {
    if (res.statusCode >= 400) throw _error(res, authed: authed);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Builds the ApiException for an error response and raises the
  /// account-wide signals main.dart reacts to. Only for requests we actually
  /// authenticated:
  ///   - 401 → session expired (a 401 without a token just means the user is
  ///     already logged out; re-firing would loop the navigation);
  ///   - 403 `consent_required` → current Terms not accepted yet → terms gate;
  ///   - 403 `account_suspended` → suspended → sign out with an explanation.
  /// Any other 403 is "not allowed to touch this resource" (wrong role, not
  /// part of this ride) and doesn't affect the session.
  ApiException _error(http.Response res, {required bool authed}) {
    String msg = 'Request failed';
    String? code;
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map) {
        if (parsed['error'] != null) msg = parsed['error'].toString();
        code = parsed['code']?.toString();
      }
    } catch (_) {/* not JSON — keep default */}
    if (authed) {
      if (res.statusCode == 401) {
        SessionEvents.instance.fireExpired();
      } else if (res.statusCode == 403 && code == 'consent_required') {
        SessionEvents.instance.fireConsentRequired();
      } else if (res.statusCode == 403 && code == 'account_suspended') {
        SessionEvents.instance.fireSuspended();
      }
    }
    return ApiException(msg, statusCode: res.statusCode, code: code);
  }
}
