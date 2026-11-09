# Release setup — one-time steps before the tester round

Three things must be done by hand because they need console access or a private
key. **The Android build fails until step 1 is complete** — deliberately, so a
build can't silently ship with the placeholder package name.

---

## 1. Register the real package name in Firebase (blocks the build)

`applicationId` is now `com.sameway.app`. It was `com.example.sameway`, which
the Play Store rejects and which cannot be changed after publishing.

1. Firebase console → project `sameway-f87ea` → Project settings → **Add app** →
   Android.
2. Package name: `com.sameway.app`.
3. Download the new `google-services.json` and replace
   `android/app/google-services.json`.
4. Rebuild. Until then:
   `No matching client found for package name 'com.sameway.app'`

Keep the old `com.example.sameway` app registered if any test install of it
still matters; otherwise delete it.

---

## 2. Create the release keystore

Release builds were signed with the **debug** key — a well-known shared key that
anyone can use to forge an update, and one the Play Store will not accept.

```
keytool -genkey -v -keystore %USERPROFILE%\sameway-release.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias sameway
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
it in. That file is gitignored — **back the keystore up somewhere safe**. Losing
it means you can never publish an update to the listing again.

Register the release SHA-1 in Firebase (needed for any Google sign-in and for
API-key restrictions):

```
keytool -list -v -keystore %USERPROFILE%\sameway-release.jks -alias sameway
```

Without `key.properties` the release build still works but falls back to the
debug key and logs a warning. **Do not distribute that build**: switching to a
real key later forces every tester to uninstall and reinstall, because Android
refuses upgrades across a signature change.

---

## 3. Rotate the leaked credentials

Both of these are in the public git history of `sameway_backend`
(`origin/main` and `origin/WIP`) and must be treated as compromised:

- **Firebase service-account private key** — `serviceAccountKey.json`,
  key id `<SERVICE_ACCOUNT_KEY_ID>`.
  Console → Project settings → Service accounts → revoke it, generate a
  replacement, and keep the new file **outside** the repo (compose mounts it at
  `/secrets/serviceAccountKey.json`).
- **Groq API key** `<GROQ_API_KEY>` — revoke in the Groq console.

Also restrict the Android API key `<ANDROID_API_KEY>` (in `google-services.json`,
which is normal to commit) to the Firebase APIs actually used, bound to
`com.sameway.app` plus the release SHA-1 from step 2.

Rotation is the fix. Purging the keys from git history is cleanup — see the
"Phase 0" notes in the remediation plan.

---

## Build commands

```
# Emulator against the local backend (sameway_backend/scripts/dev.sh, :4040).
# Debug and profile builds use http://10.0.2.2:4040 by default.
flutter run

# Physical phone / testers: the ngrok tunnel. Release builds default to it
# until there is a domain, so the define is optional. Release builds need
# android/key.properties; without it they fail on purpose. For a local test
# build only, -PallowDebugSigning=true signs with the debug key (never
# distribute that APK).
flutter run --dart-define=API_HOST=<your-tunnel>.ngrok-free.dev
flutter build apk --release
flutter build apk --release -PallowDebugSigning=true   # local test only

# STORE SUBMISSION — STORE_BUILD makes the app refuse to start (red
# "Misconfigured build" screen) if API_HOST is ngrok, local or plain http.
# --obfuscate needs --split-debug-info; keep build/symbols for every release
# you ship, it is the only way to read Dart stack traces from that build.
flutter build appbundle --release \
  --dart-define=STORE_BUILD=true --dart-define=API_HOST=<production host> \
  --obfuscate --split-debug-info=build/symbols/$(git rev-parse --short HEAD)

# Upload the Dart symbols to Crashlytics (Firebase CLI, logged in). The app ID
# is mobilesdk_app_id in android/app/google-services.json. The R8 mapping
# file is uploaded by the Crashlytics Gradle plugin during the build.
firebase crashlytics:symbols:upload --app=<FIREBASE_ANDROID_APP_ID> build/symbols/<commit>
```

On-emulator integration tests (local backend must be running):

```
flutter build apk --profile --target-platform android-x64 -t integration_test/backend_smoke_test.dart
flutter drive --profile --driver test_driver/integration_test.dart   --target integration_test/backend_smoke_test.dart   --use-application-binary build/app/outputs/flutter-apk/app-profile.apk
```
