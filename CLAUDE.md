# sameway (Flutter): build and test

Project rules are in `../CLAUDE.md`. This file only has commands.

- Flutter: `C:\Users\hp855\dev\flutter_windows_3.24.3-stable\flutter\bin` (contains Flutter 3.35.2 / Dart 3.9 despite the folder name). In PowerShell use `flutter.bat` by full path if `flutter` isn't found.
- Setup: `flutter pub get`, then `git config core.hooksPath .githooks` (pre-commit runs gitleaks; install it with `go install github.com/zricethezav/gitleaks/v8@v8.21.2`). CI runs gitleaks on every push (`.github/workflows/gitleaks.yml`); allow-listed files are in `.gitleaks.toml`.
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
- Strings (from Phase 2): ARB in `lib/l10n/app_{en,uk,pl}.arb`, generated class `L10n` (`context.l10n.key`). `lib/l10n/gen/` is not committed: `flutter pub get` or `flutter gen-l10n` regenerates it (run it after changing an ARB file; the analyzer shows errors until then). `build/l10n_untranslated.json` must stay `{}`.
  - Add hand-written keys: `dart run tool/l10n/add_keys.dart spec.json` (format in the script; mark the languages you wrote with `"review"`).
  - Copy deck changed? `dart run tool/l10n/import_copy_deck.dart --report`, decide each new row in `tool/l10n/copy_deck_map.txt`, then run it without `--report`. `test/l10n/copy_deck_coverage_test.dart` fails until every row is decided.
  - Strings to review: `dart run tool/l10n/needs_review.dart` rewrites `../design-pack/l10n/needs_review.md` (commit it on the design-pack branch; the PR links to it). `--stdout` prints it, `--count` gives totals.
  - Server errors: `lib/l10n/error_codes.dart` maps `code`s and the English texts of codeless errors; anything unmapped shows the generic error and is logged to Crashlytics. The full list per endpoint is `../design-pack/docs/SERVER_ERRORS.md`.
  - Formatting: `SwFormat.of(context)` (`lib/l10n/format.dart`) for distance, duration, 24 h time, deadlines with a day name, dates, weekday chips, whole złoty. Server error codes → `lib/l10n/error_codes.dart`.
  - `lib/core/app_localizations.dart` is the old API, now a wrapper over the `legacy_*` keys. Don't add to it; when a screen moves to `context.l10n`, delete unused getters and their `legacy_*` keys.
  - `test/l10n/` enforces the copy rules and the no-hard-coded-strings rule; a literal that must stay gets `// l10n-ignore: <reason>`.
