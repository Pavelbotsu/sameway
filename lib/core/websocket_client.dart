import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

const _wsBase = 'wss://ibuprofen-dolly-prison.ngrok-free.dev';

enum WsState { disconnected, connecting, connected }

class WebSocketClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _state = StreamController<WsState>.broadcast();

  String? _token;
  Timer? _reconnect;
  int _attempt = 0;
  WsState _current = WsState.disconnected;

  // Backoff schedule in seconds, capped at 30s.
  static const _backoff = [1, 2, 4, 8, 16, 30];

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  Stream<WsState> get state => _state.stream;
  WsState get currentState => _current;

  void connect(String token) {
    _token = token;
    _attempt = 0;
    _reconnect?.cancel();
    _connect();
  }

  void _connect() {
    final t = _token;
    if (t == null) return;
    _emit(WsState.connecting);
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = WebSocketChannel.connect(Uri.parse('$_wsBase/ws?token=$t'));
    _channel!.stream.listen(
      (data) {
        // First successful frame implies the handshake completed.
        if (_current != WsState.connected) {
          _attempt = 0;
          _emit(WsState.connected);
        }
        try {
          _controller.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
    // Optimistically mark connected; the first frame or onDone refines it.
    _emit(WsState.connected);
  }

  void _scheduleReconnect() {
    _emit(WsState.disconnected);
    if (_token == null) return; // explicit disconnect
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
    _reconnect?.cancel();
    _reconnect = null;
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
