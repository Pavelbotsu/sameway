import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/session.dart';
import 'package:sameway/core/websocket_client.dart';

/// In-memory socket. `serverSend` delivers a frame; `drop` ends the stream the
/// way a lost connection or a refused upgrade does.
class _FakeTransport implements WsTransport {
  final _ctrl = StreamController<dynamic>();
  final sent = <Object>[];
  @override
  Stream<dynamic> get stream => _ctrl.stream;
  @override
  void add(Object data) => sent.add(data);
  @override
  void close() {
    if (!_ctrl.isClosed) _ctrl.close();
  }

  void serverSend(String frame) => _ctrl.add(frame);
  void drop() => close();
}

class _Harness {
  final transports = <_FakeTransport>[];
  int probes = 0;
  bool tokenValid = true;
  late final WebSocketClient client = WebSocketClient(
    connector: (_) {
      final t = _FakeTransport();
      transports.add(t);
      return t;
    },
    tokenProbe: (_) async {
      probes++;
      return tokenValid;
    },
    random: Random(1),
  );
  _FakeTransport get last => transports.last;
}

void main() {
  late int expiries;
  late StreamSubscription<void> sub;

  setUp(() {
    expiries = 0;
    sub = SessionEvents.instance.onExpired.listen((_) => expiries++);
  });
  tearDown(() => sub.cancel());

  test('hello marks the socket connected and is not forwarded', () {
    fakeAsync((async) {
      final h = _Harness();
      final events = <Map<String, dynamic>>[];
      h.client.messages.listen(events.add);
      h.client.connect('tok');
      expect(h.client.currentState, WsState.connecting);

      h.last.serverSend('{"type":"hello","payload":{}}');
      async.flushMicrotasks();
      expect(h.client.currentState, WsState.connected);
      expect(events, isEmpty);

      h.last.serverSend('{"type":"ride_request","payload":{"request_id":"r1"}}');
      async.flushMicrotasks();
      expect(events.single['type'], 'ride_request');
      h.client.dispose();
    });
  });

  test('repeated drops of a working socket never log the user out', () {
    fakeAsync((async) {
      final h = _Harness();
      h.client.connect('tok');
      for (var i = 0; i < 10; i++) {
        h.last.serverSend('{"type":"hello","payload":{}}');
        async.flushMicrotasks();
        h.last.drop(); // backend restart / tunnel / elevator
        async.elapse(const Duration(seconds: 40)); // past max backoff
      }
      expect(expiries, 0);
      expect(h.probes, 0, reason: 'a socket that connected is not an auth failure');
      expect(h.transports.length, 11, reason: 'it kept reconnecting');
      h.client.dispose();
    });
  });

  test('offline (never connects) keeps retrying when the token is fine', () {
    fakeAsync((async) {
      final h = _Harness()..tokenValid = true; // probe: network error / not 401
      h.client.connect('tok');
      for (var i = 0; i < 9; i++) {
        h.last.drop(); // upgrade never happens
        async.elapse(const Duration(seconds: 40));
      }
      expect(expiries, 0);
      expect(h.probes, greaterThan(0), reason: 'it checked the token');
      expect(h.client.currentState, isNot(WsState.disconnected),
          reason: 'still trying');
      h.client.dispose();
    });
  });

  test('a token the server rejects ends the session', () {
    fakeAsync((async) {
      final h = _Harness()..tokenValid = false; // probe sees HTTP 401
      h.client.connect('tok');
      for (var i = 0; i < 3; i++) {
        h.last.drop();
        async.elapse(const Duration(seconds: 40));
      }
      expect(expiries, 1);
      final attempts = h.transports.length;
      async.elapse(const Duration(minutes: 5));
      expect(h.transports.length, attempts, reason: 'stopped reconnecting');
      h.client.dispose();
    });
  });

  test('backoff is jittered around the schedule', () {
    fakeAsync((async) {
      final h = _Harness();
      h.client.connect('tok');
      h.last.serverSend('{"type":"hello","payload":{}}');
      async.flushMicrotasks();
      h.last.drop();
      // First retry is ~1 s (0.7–1.3 s): not before 0.7 s, done by 1.3 s.
      async.elapse(const Duration(milliseconds: 690));
      expect(h.transports.length, 1);
      async.elapse(const Duration(milliseconds: 620));
      expect(h.transports.length, 2);
      h.client.dispose();
    });
  });
}
