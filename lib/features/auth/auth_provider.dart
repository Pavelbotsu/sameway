import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart' show kApiBase;
import '../../core/analytics.dart';
import '../../core/legal.dart';
import '../../core/location_service.dart';
import '../../core/token_storage.dart';
import '../../core/websocket_client.dart';
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

  /// Whether the consent screen must ask for the date of birth. null = not
  /// known this session (cold start): the gate then asks to be safe; the
  /// server ignores it when one is already on file.
  bool? needsBirthDate;

  /// The shared socket, closed on sign-out. Optional so tests can omit it.
  final WebSocketClient? _ws;

  AuthProvider(this._repo, this._storage, {WebSocketClient? ws}) : _ws = ws;

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
    required DateTime birthDate,
  }) async {
    return _run(
      () => _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
        acceptTerms: acceptTerms,
        ageConfirmed: ageConfirmed,
        birthDate: birthDate,
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
      needsBirthDate = result.needsBirthDate;
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
  Future<void> acceptTerms({DateTime? birthDate}) async {
    await _repo.acceptTerms(birthDate: birthDate);
    final userId = await _storage.getUserId();
    if (userId != null) {
      await _storage.setAcceptedTermsVersion(userId, kTermsVersion);
    }
    needsBirthDate = false;
    needsConsent = false;
    notifyListeners();
  }

  void clearError() {
    error = null;
    lastError = null;
    status = AuthStatus.idle;
    notifyListeners();
  }

  /// Signs out: revokes the session on the server (best-effort), stops the
  /// device receiving this account's pushes, then clears local state.
  Future<void> logout() async {
    final token = await _storage.getToken();
    if (token != null) {
      // Raw http, not ApiClient: if the token is already invalid, the 401
      // must not trigger the "session expired" flow in the middle of a
      // deliberate sign-out. Offline is fine too — the token simply expires.
      try {
        await http.post(
          Uri.parse('$kApiBase/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    // Without this the shared socket keeps reconnecting with the revoked
    // token and ends in a bogus "session expired" message.
    _ws?.disconnect();
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
    // Not logout(): the session is already revoked server-side.
    await _clearLocalSession();
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
