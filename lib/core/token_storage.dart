import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _token = 'jwt';
  static const _role = 'role';
  static const _userId = 'user_id';

  Future<void> save({
    required String token,
    required String role,
    required String userId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_token, token);
    await p.setString(_role, role);
    await p.setString(_userId, userId);
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

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_token);
    await p.remove(_role);
    await p.remove(_userId);
  }
}
