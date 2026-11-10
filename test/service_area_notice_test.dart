import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/passenger/passenger_provider.dart';
import 'package:sameway/features/passenger/passenger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  test('outside the service area: told once, not counted as a sync failure', () async {
    final provider = PassengerProvider(
        PassengerRepository(ApiClient(TokenStorage())), WebSocketClient());
    final notices = <PassengerNotice>[];
    final sub = provider.notices.listen(notices.add);
    await http.runWithClient(() async {
      for (var i = 0; i < 4; i++) {
        await provider.updateLocation(52.23, 21.01); // Warsaw
      }
    }, () => MockClient((_) async => http.Response(
        '{"error":"Sameway isn\'t available here yet","code":"outside_service_area"}', 403)));
    await Future<void>.delayed(Duration.zero);

    expect(notices, [PassengerNotice.outsideServiceArea]);
    expect(provider.outsideServiceArea, isTrue);
    expect(provider.locationSyncFailing, isFalse);
    await sub.cancel();
    provider.dispose();
  });
}
