import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'token_storage.dart';

/// Backend hostname — the single source of truth for both HTTP and WebSocket
/// bases. Always a bare host: schemes are added below (https) and in
/// websocket_client.dart (wss), so the app never speaks plaintext.
//
// Defaults to PRODUCTION deliberately. It previously defaulted to a personal
// ngrok tunnel, so a release build made without the --dart-define shipped
// pointed at a dev machine — and nothing about the build failed to signal it.
// Dev runs now pass the override instead:
//   flutter run --dart-define=API_HOST=<your-tunnel>.ngrok-free.dev
const kApiHost = String.fromEnvironment(
  'API_HOST',
  defaultValue: 'ibuprofen-dolly-prison.ngrok-free.dev',
);
const kApiBase = 'https://$kApiHost';
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
  const ApiException(this.message, {this.statusCode = 0});
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
        if (res.statusCode == 401 && h.containsKey('Authorization')) {
          SessionEvents.instance.fireExpired();
        }
        String msg = 'Request failed';
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map && parsed['error'] != null) {
            msg = parsed['error'].toString();
          }
        } catch (_) {/* not JSON — keep default */}
        throw ApiException(msg, statusCode: res.statusCode);
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
        String msg = 'Request failed';
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map && parsed['error'] != null) {
            msg = parsed['error'].toString();
          }
        } catch (_) {/* not JSON — keep default */}
        if (res.statusCode == 401 && h.containsKey('Authorization')) {
          SessionEvents.instance.fireExpired();
        }
        throw ApiException(msg, statusCode: res.statusCode);
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
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      // Only treat 401 from a request we actually authenticated as a session-
      // expiry signal. 403 is the backend saying "you can't touch this
      // specific resource" (e.g. wrong role, not part of this ride) — that
      // doesn't invalidate the session. 401 on a request without an
      // Authorization header just means the user is already logged out, and
      // re-firing the expiry event would loop the SnackBar/navigation.
      if (res.statusCode == 401 && authed) {
        SessionEvents.instance.fireExpired();
      }
      throw ApiException(
        data['error']?.toString() ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
    return data;
  }
}
