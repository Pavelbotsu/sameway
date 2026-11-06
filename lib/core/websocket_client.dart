import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart' show kApiBase, kApiHost;
import 'session.dart';

// Derived from the same host as the HTTP base (see api_client.dart) so a
// single --dart-define=API_HOST switches both transports together.
const _wsBase = 'wss://$kApiHost';

enum WsState { disconnected, connecting, connected }

/// The socket as the client needs it. Production wraps a WebSocketChannel;
/// tests substitute an in-memory fake.
abstract class WsTransport {
  Stream<dynamic> get stream;
  void add(Object data);
  void close();
}

class _ChannelTransport implements WsTransport {
  final WebSocketChannel _ch;
  _ChannelTransport(this._ch);
  @override
  Stream<dynamic> get stream => _ch.stream;
  @override
  void add(Object data) => _ch.sink.add(data);
  @override
  void close() => _ch.sink.close();
}

WsTransport _defaultConnector(Uri uri) =>
    _ChannelTransport(WebSocketChannel.connect(uri));

/// Asks the server whether [token] is still accepted. Returns false only for a
/// definite rejection (HTTP 401); any network failure returns true, because
/// "can't reach the server" must never be mistaken for "logged out".
Future<bool> _defaultTokenProbe(String token) async {
  try {
    final res = await http.get(
      Uri.parse('$kApiBase/auth/profile'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    return res.statusCode != 401;
  } catch (_) {
    return true;
  }
}

class WebSocketClient {
  WebSocketClient({
    WsTransport Function(Uri)? connector,
    Future<bool> Function(String token)? tokenProbe,
    Random? random,
  })  : _connector = connector ?? _defaultConnector,
        _tokenProbe = tokenProbe ?? _defaultTokenProbe,
        _random = random ?? Random();

  final WsTransport Function(Uri) _connector;
  final Future<bool> Function(String token) _tokenProbe;
  final Random _random;

  WsTransport? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _state = StreamController<WsState>.broadcast();

  String? _token;
  Timer? _reconnect;
  Timer? _heartbeat;
  int _attempt = 0;
  WsState _current = WsState.disconnected;

  /// Incremented on every [_connect]. Callbacks captured by an older channel
  /// compare against it and bail — without this, closing the previous channel
  /// fired its `onDone`, which scheduled *another* reconnect on top of the one
  /// already in flight, so reconnects multiplied instead of replacing.
  int _generation = 0;

  /// Consecutive attempts that ended without the socket ever delivering a
  /// frame. That happens both when the server refuses the token (401, no
  /// upgrade) and when there is simply no network — the socket can't tell
  /// them apart. So after [_probeThreshold] such attempts the token is checked
  /// over plain HTTP ([_tokenProbe]); only a definite 401 ends the session.
  ///
  /// It used to fire session expiry directly after 3 failures, and counted a
  /// drop of a WORKING socket as a failure too (the state was set to
  /// disconnected before the check), so ~3 s without signal or any backend
  /// restart logged the user out mid-ride.
  int _failedHandshakes = 0;
  static const _probeThreshold = 3;
  bool _probing = false;

  // Backoff schedule in seconds, capped at 30s, with ±30 % jitter so a backend
  // restart doesn't make every client reconnect in the same instant.
  static const _backoff = [1, 2, 4, 8, 16, 30];

  // Application-level keepalive. Free ngrok tunnels (and most proxies/load
  // balancers) silently close a WebSocket that has had no traffic for ~60s of
  // idle time; that drop is what surfaced the perpetual "Reconnecting…" pill.
  // A lightweight ping every 25s keeps the tunnel "active" so the socket is
  // not reaped. The server ignores client frames.
  static const _pingInterval = Duration(seconds: 25);

  // Control frames that must not reach feature listeners: the server greets
  // every new connection with `hello` (that greeting is what proves the
  // upgrade succeeded), and `pong` is kept for older servers.
  static const _controlTypes = {'hello', 'pong'};

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  Stream<WsState> get state => _state.stream;
  WsState get currentState => _current;

  void connect(String token) {
    // Already live on this exact token — don't tear a working socket down and
    // rebuild it. Both role providers call this against the shared client, so
    // without the guard a role switch produced a needless reconnect.
    if (_token == token && _current == WsState.connected) return;
    _token = token;
    _attempt = 0;
    _failedHandshakes = 0;
    _reconnect?.cancel();
    _connect();
  }

  void _connect() {
    final t = _token;
    if (t == null) return;
    final generation = ++_generation;
    _emit(WsState.connecting);
    try {
      _channel?.close();
    } catch (_) {}
    final channel = _connector(Uri.parse('$_wsBase/ws?token=$t'));
    _channel = channel;
    channel.stream.listen(
      (data) {
        if (generation != _generation) return; // superseded channel
        // A delivered frame is the proof the handshake completed. Current
        // servers send `hello` immediately, so this flips at once.
        if (_current != WsState.connected) {
          _attempt = 0;
          _failedHandshakes = 0;
          _emit(WsState.connected);
        }
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          if (_controlTypes.contains(decoded['type'])) return;
          _controller.add(decoded);
        } catch (_) {}
      },
      onDone: () => _scheduleReconnect(generation),
      onError: (_) => _scheduleReconnect(generation),
      cancelOnError: true,
    );
    // Deliberately NOT emitting `connected` here: a rejected token (401, no
    // upgrade) must not flash "connected". `connecting` stands until a frame
    // arrives.
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_pingInterval, (_) {
      try {
        _channel?.add(jsonEncode({'type': 'ping'}));
      } catch (_) {/* sink already closed — reconnect will handle it */}
    });
  }

  void _scheduleReconnect(int generation) {
    // A channel we already replaced finishing its teardown must not schedule
    // anything: that turned one reconnect into two.
    if (generation != _generation) return;

    // Read BEFORE switching to disconnected — afterwards every drop would
    // look like a socket that never connected.
    final wasConnected = _current == WsState.connected;

    _heartbeat?.cancel();
    _heartbeat = null;
    _emit(WsState.disconnected);
    final token = _token;
    if (token == null) return; // explicit disconnect

    if (!wasConnected) {
      _failedHandshakes++;
      if (_failedHandshakes >= _probeThreshold && !_probing) {
        _failedHandshakes = 0;
        _probeToken(token);
      }
    }

    final base = _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt++;
    final jitter = 0.7 + _random.nextDouble() * 0.6; // ×0.7 … ×1.3
    _reconnect?.cancel();
    _reconnect = Timer(
      Duration(milliseconds: (base * 1000 * jitter).round()),
      _connect,
    );
  }

  /// Runs alongside the normal retry loop; only a definite rejection of the
  /// SAME token stops it and ends the session.
  Future<void> _probeToken(String token) async {
    _probing = true;
    try {
      final accepted = await _tokenProbe(token);
      if (!accepted && _token == token) {
        disconnect();
        SessionEvents.instance.fireExpired();
      }
    } finally {
      _probing = false;
    }
  }

  void _emit(WsState s) {
    if (_current == s) return;
    _current = s;
    _state.add(s);
  }

  void disconnect() {
    _token = null;
    _generation++; // orphan any in-flight channel callbacks
    _failedHandshakes = 0;
    _reconnect?.cancel();
    _reconnect = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      _channel?.close();
    } catch (_) {}
    _channel = null;
    _emit(WsState.disconnected);
  }

  void dispose() {
    disconnect();
    _controller.close();
    _state.close();
  }
}
