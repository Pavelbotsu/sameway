import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart' show kApiHost;
import 'session.dart';

// Derived from the same host as the HTTP base (see api_client.dart) so a
// single --dart-define=API_HOST switches both transports together.
const _wsBase = 'wss://$kApiHost';

enum WsState { disconnected, connecting, connected }

class WebSocketClient {
  WebSocketChannel? _channel;
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

  /// Consecutive attempts that failed without ever delivering a frame. An
  /// invalid or revoked token makes the server answer 401 and never upgrade,
  /// which looks exactly like a flaky network from here — except it will never
  /// succeed. After [_authFailureThreshold] such attempts we surface a session
  /// expiry instead of reconnecting forever behind a "Reconnecting…" pill.
  int _failedHandshakes = 0;
  static const _authFailureThreshold = 3;

  // Backoff schedule in seconds, capped at 30s.
  static const _backoff = [1, 2, 4, 8, 16, 30];

  // Application-level keepalive. Free ngrok tunnels (and most proxies/load
  // balancers) silently close a WebSocket that has had no traffic for ~60s of
  // idle time; that drop is what surfaced the perpetual "Reconnecting…" pill.
  // A lightweight ping every 25s keeps the tunnel "active" so the socket is
  // not reaped. The server is expected to ignore unknown message types.
  static const _pingInterval = Duration(seconds: 25);

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
      _channel?.sink.close();
    } catch (_) {}
    _channel = WebSocketChannel.connect(Uri.parse('$_wsBase/ws?token=$t'));
    _channel!.stream.listen(
      (data) {
        if (generation != _generation) return; // superseded channel
        // A delivered frame is the only proof the handshake actually completed.
        if (_current != WsState.connected) {
          _attempt = 0;
          _failedHandshakes = 0;
          _emit(WsState.connected);
        }
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          // Swallow heartbeat acks — they exist only to keep the tunnel warm
          // and must not reach feature listeners.
          if (decoded['type'] == 'pong') return;
          _controller.add(decoded);
        } catch (_) {}
      },
      onDone: () => _scheduleReconnect(generation),
      onError: (_) => _scheduleReconnect(generation),
      cancelOnError: true,
    );
    // Deliberately NOT emitting `connected` here. It used to be optimistic,
    // which meant a rejected token (401, no upgrade) still flashed "connected"
    // before failing — hiding a permanent auth failure behind what looked like
    // flaky connectivity. `connecting` stands until a frame arrives.
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_pingInterval, (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {/* sink already closed — reconnect will handle it */}
    });
  }

  void _scheduleReconnect(int generation) {
    // A channel we already replaced finishing its teardown must not schedule
    // anything: that turned one reconnect into two.
    if (generation != _generation) return;

    _heartbeat?.cancel();
    _heartbeat = null;
    _emit(WsState.disconnected);
    if (_token == null) return; // explicit disconnect

    // Never reached `connected`, so no frame ever arrived. Repeatedly, that
    // means the server is refusing the token, not that the network is bad.
    if (_current != WsState.connected) {
      _failedHandshakes++;
      if (_failedHandshakes >= _authFailureThreshold) {
        _token = null; // stop the loop
        _failedHandshakes = 0;
        SessionEvents.instance.fireExpired();
        return;
      }
    }

    final delay = _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt++;
    _reconnect?.cancel();
    _reconnect = Timer(Duration(seconds: delay), _connect);
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
      _channel?.sink.close();
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
