# sameway (Flutter): build and test

Project rules are in `../CLAUDE.md`. This file only has commands.

- Flutter: `C:\Users\hp855\dev\flutter_windows_3.24.3-stable\flutter\bin` (contains Flutter 3.35.2 / Dart 3.9 despite the folder name). In PowerShell use `flutter.bat` by full path if `flutter` isn't found.
- Setup: `flutter pub get`
- Check: `flutter analyze` and `flutter test`. **Never run `dart format`** on existing files (it rewrites whole files); keep the existing style.
- Run against the local backend (`../sameway_backend/scripts/dev.sh`): `flutter run` (debug builds use `10.0.2.2:4040` automatically). Other hosts: `--dart-define=API_HOST=<host>` (+ `--dart-define=API_INSECURE=true` for plain http on a LAN IP).
- **One emulator only.** For two-party flows the second party runs on the host:
  ```
  flutter build apk --profile --target-platform android-x64 -t integration_test/two_device_ride_test.dart --dart-define=RUN=<id>
  flutter drive --profile --driver test_driver/integration_test.dart --target integration_test/two_device_ride_test.dart --use-application-binary build/app/outputs/flutter-apk/app-profile.apk
  flutter test tool/ride_counterpart_test.dart --dart-define=RUN=<id> --dart-define=API_HOST=localhost:4040 --dart-define=API_INSECURE=true
  ```
  Add `--dart-define=ROLE=passenger` on the host to make the emulator drive. Use the profile APK with `--use-application-binary`: the emulator's storage is nearly full.
- Backend smoke test: same two build/drive steps with `integration_test/backend_smoke_test.dart`.
- Local release build: `flutter build apk --release -PallowDebugSigning=true` (no `android/key.properties` here). Store builds: see `RELEASE_SETUP.md`.
- Goldens (from Phase 1): `test/goldens/`, 390×844, both roles, 1× and 2× text scale, EN and UK. Tagged `golden` and rendered on this Windows machine, so they run locally only: `flutter test --tags golden` (add `--update-goldens` only when the change is intended, then look at the PNGs). CI runs `flutter test --exclude-tags golden`.
- Regenerate goldens with `flutter test --tags golden --update-goldens` after a Flutter or font upgrade, review the diff, commit.
- `test/ui/tokens_sync_test.dart` checks that every `SwColors` value is in `../design-pack/design/tokens.json` (skipped when the design pack isn't checked out next to the app, e.g. in CI). A new colour goes into both.
- Design system: `lib/theme` (tokens, `SwTheme.build(role)`, `context.role`) and `lib/ui` (components). New UI uses these, not `AppColors`.
