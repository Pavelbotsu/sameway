import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
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
    await p.setString(_token, token);
    await p.setString(_role, role);
    await p.setString(_userId, userId);
    if (name != null) await p.setString(_name, name);
    if (email != null) await p.setString(_email, email);
  }

  Future<String?> getToken() async {
    return (await SharedPreferences.getInstance()).getString(_token);
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
