import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/passenger/passenger_provider.dart';
import 'package:sameway/features/passenger/passenger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a nearby_changed frame asks the screen to refresh', () async {
    final provider = PassengerProvider(
        PassengerRepository(ApiClient(TokenStorage())), WebSocketClient());
    var hints = 0;
    final sub = provider.nearbyChanged.listen((_) => hints++);
    provider.handleMessageForTest({'type': 'nearby_changed', 'payload': {}});
    await Future<void>.delayed(Duration.zero);
    expect(hints, 1);
    await sub.cancel();
    provider.dispose();
  });
}
