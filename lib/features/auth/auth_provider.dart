import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../core/analytics.dart';
import '../../core/legal.dart';
import '../../core/location_service.dart';
import '../../core/token_storage.dart';
import 'auth_repository.dart';

enum AuthStatus { idle, loading, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.idle;
  String? error;

  /// The exception behind [error], so screens can show a localized message
  /// (friendlyError) instead of raw exception text.
  Object? lastError;
  String? role;

  /// The last successful auth call said this account must still accept the
  /// current Terms/Privacy and confirm 18+ before using the app.
  bool needsConsent = false;

  AuthProvider(this._repo, this._storage);

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    return _run(() => _repo.login(email: email, password: password));
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required bool acceptTerms,
    required bool ageConfirmed,
  }) async {
    return _run(
      () => _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
        acceptTerms: acceptTerms,
        ageConfirmed: ageConfirmed,
      ),
    );
  }

  Future<bool> _run(Future<AuthResult> Function() call) async {
    status = AuthStatus.loading;
    error = null;
    lastError = null;
    notifyListeners();
    try {
      final result = await call();
      await _storage.save(
        token: result.token,
        role: result.role,
        userId: result.userId,
        name: result.name,
        email: result.email,
      );
      needsConsent = result.needsConsent;
      if (!needsConsent) {
        // Lets the splash screen skip the terms gate on later cold starts.
        await _storage.setAcceptedTermsVersion(result.userId, kTermsVersion);
      }
      // Covers login, register AND switchRole — all route through _run.
      Analytics.setUser(result.userId, result.role);
      role = result.role;
      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      lastError = e;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> switchRole(String role) async {
    return _run(() => _repo.switchRole(role: role));
  }

  /// Records Terms/Privacy acceptance + 18+ for the signed-in account.
  /// Throws on failure so the gate screen can show it.
  Future<void> acceptTerms() async {
    await _repo.acceptTerms();
    final userId = await _storage.getUserId();
    if (userId != null) {
      await _storage.setAcceptedTermsVersion(userId, kTermsVersion);
    }
    needsConsent = false;
    notifyListeners();
  }

  void clearError() {
    error = null;
    lastError = null;
    status = AuthStatus.idle;
    notifyListeners();
  }

  Future<void> logout() async {
    // A driver's background location service outlives the screen that
    // started it; signing out must not leave it running (and posting nothing
    // useful) behind an ongoing notification.
    await LocationService.stop();
    await _storage.clear();
    role = null;
    needsConsent = false;
    notifyListeners();
  }

  /// Permanently deletes the account on the server, then clears everything
  /// this device holds for it. Throws ApiException (403 wrong password,
  /// 409 ride in progress) — nothing local is touched in that case.
  Future<void> deleteAccount(String password) async {
    final userId = await _storage.getUserId();
    await _repo.deleteAccount(password);
    // Server side is done; everything below is best-effort local cleanup.
    if (userId != null) await _deleteProfilePhotos(userId);
    try {
      // Stops pushes to this device for the deleted account (the server
      // already dropped the token; this invalidates it at FCM too).
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await logout();
  }

  /// Profile photos live in Firebase Storage under `user_photos/{userId}/` and the
  /// backend has no handle on them. Whether this succeeds depends on the
  /// Storage security rules (audit P0-12).
  Future<void> _deleteProfilePhotos(String userId) async {
    try {
      final dir = FirebaseStorage.instance.ref('user_photos/$userId');
      final list = await dir.listAll().timeout(const Duration(seconds: 10));
      for (final item in list.items) {
        await item.delete().timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('deleteAccount: photo cleanup failed: $e');
    }
  }
}
