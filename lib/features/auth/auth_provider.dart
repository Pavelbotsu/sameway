import 'package:flutter/foundation.dart';
import '../../core/token_storage.dart';
import 'auth_repository.dart';

enum AuthStatus { idle, loading, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.idle;
  String? error;
  String? role;

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
  }) async {
    return _run(
      () => _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
      ),
    );
  }

  Future<bool> _run(Future<AuthResult> Function() call) async {
    status = AuthStatus.loading;
    error = null;
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
      role = result.role;
      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> switchRole(String role) async {
    return _run(() => _repo.switchRole(role: role));
  }

  void clearError() {
    error = null;
    status = AuthStatus.idle;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clear();
    role = null;
    notifyListeners();
  }
}
