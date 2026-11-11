// Host-side entry point for `flutter drive` runs of integration_test/.
//
// Runs a prebuilt profile-mode (AOT) APK, ~30 MB instead of the ~130 MB debug
// APK `flutter test integration_test` installs — which doesn't fit on a
// nearly full emulator. Profile builds also use the local dev backend
// (http://10.0.2.2:4040, see lib/core/api_client.dart):
//
//   flutter build apk --profile --target-platform android-x64 \
//     -t integration_test/backend_smoke_test.dart
//   flutter drive --profile --driver test_driver/integration_test.dart \
//     --target integration_test/backend_smoke_test.dart \
//     --use-application-binary build/app/outputs/flutter-apk/app-profile.apk
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
