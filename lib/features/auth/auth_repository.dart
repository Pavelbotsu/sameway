import '../../core/api_client.dart';

class AuthResult {
  final String token;
  final String userId;
  final String role;
  final String? name;
  final String? email;

  AuthResult.fromJson(Map<String, dynamic> j)
      : token = j['token'] as String,
        userId = j['user_id'] as String,
        role = j['role'] as String,
        name = j['name'] as String?,
        email = j['email'] as String?;
}

class AuthRepository {
  final ApiClient _api;
  AuthRepository(this._api);

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await _api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> switchRole({required String role}) async {
    final data = await _api.post('/auth/switch-role', {'role': role}, auth: true);
    return AuthResult.fromJson(data);
  }
}
