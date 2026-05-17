import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

const _wsBase = 'ws://10.0.2.2:8080';

class WebSocketClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect(String token) {
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(Uri.parse('$_wsBase/ws?token=$token'));
    _channel!.stream.listen(
      (data) {
        try {
          _controller.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (_) {}
      },
      onDone: () {},
      onError: (_) {},
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
