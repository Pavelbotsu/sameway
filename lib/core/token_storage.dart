import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the JWT lives. The platform implementation is the Android Keystore
/// (EncryptedSharedPreferences); tests pass a fake.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  const PlatformSecretStore();

  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// Session data on the device. The JWT is kept in [SecretStore]; role, id,
/// name and email are not secrets and stay in SharedPreferences.
///
/// Older installs kept the JWT in SharedPreferences (plain XML in the app
/// sandbox). The first [getToken] moves it into the secret store. If the
/// secret store fails (broken Keystore on some devices, a plugin missing in
/// an isolate, unit tests) the token stays in / falls back to
/// SharedPreferences rather than logging the user out. The background
/// location isolate uses this same class, so it reads whichever copy exists.
class TokenStorage {
  TokenStorage({SecretStore secure = const PlatformSecretStore()})
      : _secure = secure;

  final SecretStore _secure;

  static const _token = 'jwt';
  static const _role = 'role';
  static const _userId = 'user_id';
  static const _name = 'name';
  static const _email = 'email';

  Future<void> save({
    required String token,
    required String role,
    required String userId,
    String? name,
    String? email,
  }) async {
    final p = await SharedPreferences.getInstance();
    try {
      await _secure.write(_token, token);
      await p.remove(_token);
    } catch (e) {
      debugPrint('TokenStorage: secure write failed, using prefs ($e)');
      await p.setString(_token, token);
    }
    await p.setString(_role, role);
    await p.setString(_userId, userId);
    if (name != null) await p.setString(_name, name);
    if (email != null) await p.setString(_email, email);
  }

  Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    // A prefs copy is either a pre-migration token or the fallback written
    // by save(); either way it is the newest one.
    final legacy = p.getString(_token);
    try {
      if (legacy != null) {
        await _secure.write(_token, legacy);
        await p.remove(_token);
        return legacy;
      }
      return await _secure.read(_token);
    } catch (e) {
      debugPrint('TokenStorage: secure store unavailable ($e)');
      return legacy;
    }
  }

  Future<String?> getRole() async {
    return (await SharedPreferences.getInstance()).getString(_role);
  }

  Future<String?> getUserId() async {
    return (await SharedPreferences.getInstance()).getString(_userId);
  }

  Future<String?> getName() async {
    return (await SharedPreferences.getInstance()).getString(_name);
  }

  Future<String?> getEmail() async {
    return (await SharedPreferences.getInstance()).getString(_email);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    try {
      await _secure.delete(_token);
    } catch (_) {/* nothing stored there */}
    await p.remove(_token);
    await p.remove(_role);
    await p.remove(_userId);
    await p.remove(_name);
    await p.remove(_email);
  }

  // First-run onboarding flag. Bumping the version suffix re-shows the carousel
  // after a major UX change — old installs see the new tutorial once, then
  // never again. Bumped to _v2 when the passenger/driver safety pages were added.
  static const _onboardingDone = 'onboarding_completed_v2';

  Future<bool> hasCompletedOnboarding() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_onboardingDone) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboardingDone, true);
  }

  // Pre-permission rationale flags (Phase 1.7). We show the explanation
  // sheet once per permission category and remember the user's choice so
  // we don't nag on every cold start.
  static const _locRationaleShown = 'location_rationale_shown';
  static const _notifRationaleShown = 'notification_rationale_shown';

  Future<bool> hasShownLocationRationale() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_locRationaleShown) ?? false;
  }

  Future<void> markLocationRationaleShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_locRationaleShown, true);
  }

  Future<bool> hasShownNotificationRationale() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_notifRationaleShown) ?? false;
  }

  Future<void> markNotificationRationaleShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notifRationaleShown, true);
  }

  // Terms/Privacy version this user is known (from the server) to have
  // accepted on this device. Lets the splash screen gate a stored session
  // without a network call; the server stays the source of truth (login and
  // register report needs_consent). Keyed by user so a second account on the
  // same phone is asked separately. Survives logout on purpose.
  static String _termsKey(String userId) => 'terms_version_$userId';

  Future<int> getAcceptedTermsVersion(String userId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_termsKey(userId)) ?? 0;
  }

  Future<void> setAcceptedTermsVersion(String userId, int version) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_termsKey(userId), version);
  }
}
