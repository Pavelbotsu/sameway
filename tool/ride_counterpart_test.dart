// Host side of the two-party ride (see integration_test/ride_flow.dart):
// plays whichever role the emulator didn't take, so the full flow can be
// tested with a single emulator. Not part of `flutter test` (lives outside
// test/); run it explicitly, see integration_test/two_device_ride_test.dart.
// Add --dart-define=ROLE=passenger to make the emulator the driver.
//
// No test binding on purpose: flutter_test's binding replaces HttpClient with
// one that answers 400, and this side must reach the real backend. There is
// no Keystore on the host, so the token lives in memory.
import 'package:sameway/core/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/ride_flow.dart';

class _MemoryStore implements SecretStore {
  final _data = <String, String>{};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  rideTest(secure: _MemoryStore());
}
