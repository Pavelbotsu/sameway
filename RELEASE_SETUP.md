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
# Dev, against a local tunnel
flutter run --dart-define=API_HOST=<your-tunnel>.ngrok-free.dev

# Release — API_HOST now defaults to production, so the define is optional
flutter build apk --release
```
