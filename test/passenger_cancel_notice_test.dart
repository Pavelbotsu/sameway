import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/passenger/passenger_provider.dart';
import 'package:sameway/features/passenger/passenger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which notice (if any) a ride_cancelled frame produces for an accepted ride.
Future<List<PassengerNotice>> _noticesFor(String cancelledBy) async {
  final provider = PassengerProvider(
      PassengerRepository(ApiClient(TokenStorage())), WebSocketClient());
  provider.acceptedRequestId = 'r1';
  final got = <PassengerNotice>[];
  final sub = provider.notices.listen(got.add);
  await http.runWithClient(() async {
    provider.handleMessageForTest({
      'type': 'ride_cancelled',
      'payload': {'request_id': 'r1', 'cancelled_by': cancelledBy},
    });
    await Future<void>.delayed(Duration.zero);
  }, () => MockClient((_) async => http.Response('[]', 200)));
  await sub.cancel();
  provider.dispose();
  return got;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  test('driver ending the route before pickup is explained', () async {
    expect(await _noticesFor('driver_ended'),
        [PassengerNotice.cancelledDriverEnded]);
  });

  test('existing reasons still map', () async {
    expect(await _noticesFor('no_show'), [PassengerNotice.cancelledNoShow]);
    expect(await _noticesFor('timeout'), [PassengerNotice.cancelledTimeout]);
  });
}
