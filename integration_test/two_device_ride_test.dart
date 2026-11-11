// Emulator side of the two-party ride (see ride_flow.dart). One emulator is
// enough: run tool/ride_counterpart_test.dart on the host at the same time.
//
//   cd sameway_backend && ./scripts/dev.sh        # :4040, needs OSRM access
//   flutter build apk --profile --target-platform android-x64 \
//     -t integration_test/two_device_ride_test.dart --dart-define=RUN=<id>
//   flutter drive --profile --driver test_driver/integration_test.dart \
//     --target integration_test/two_device_ride_test.dart \
//     --use-application-binary build/app/outputs/flutter-apk/app-profile.apk
//   # in parallel, on the host:
//   flutter test tool/ride_counterpart_test.dart --dart-define=RUN=<id> \
//     --dart-define=API_HOST=localhost:4040 --dart-define=API_INSECURE=true
//   # add --dart-define=ROLE=passenger on the host to make the emulator drive
import 'package:integration_test/integration_test.dart';

import 'ride_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  rideTest();
}
