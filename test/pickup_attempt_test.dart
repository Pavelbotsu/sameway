import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/passenger/passenger_provider.dart';
import 'package:sameway/features/passenger/passenger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Submits a pickup code against a canned /pickup/confirm response.
Future<PickupAttempt> _submit(int status, Map<String, dynamic> body) async {
  final provider = PassengerProvider(
      PassengerRepository(ApiClient(TokenStorage())), WebSocketClient());
  provider.acceptedRequestId = 'r1';
  late PickupAttempt result;
  await http.runWithClient(() async {
    result = await provider.confirmPickup('1234');
  }, () => MockClient((_) async => http.Response(jsonEncode(body), status)));
  provider.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  test('right code', () async {
    final r = await _submit(200, {'ok': true});
    expect(r.ok, isTrue);
  });

  test('wrong code reports the tries left', () async {
    final r = await _submit(400, {'error': 'wrong code', 'code': 'wrong_code', 'attempts_left': 3});
    expect(r.ok, isFalse);
    expect(r.locked, isFalse);
    expect(r.attemptsLeft, 3);
  });

  test('lockout is reported as locked, not as a wrong code', () async {
    final r = await _submit(429, {'error': 'too many', 'code': 'pickup_locked', 'attempts_left': 0});
    expect(r.locked, isTrue);
    expect(r.attemptsLeft, isNull);
  });

  test('other failures carry the error', () async {
    final r = await _submit(500, {'error': 'db error'});
    expect(r.ok, isFalse);
    expect(r.error, isA<ApiException>());
  });
}
