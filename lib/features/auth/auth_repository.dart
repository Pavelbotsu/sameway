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

  /// Fires a synthetic ranking request and returns the server's verdict.
  /// Keys: `ok` (bool), `ai_configured` (bool), `ranker_name` (String),
  /// `model_name` (String), `latency_ms` (int), `used_fallback` (bool),
  /// optional `error` (String), and `top_*` fields on success.
  Future<Map<String, dynamic>> testAIRanker() async {
    final data = await _api.post('/auth/test-ai', {}, auth: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> submitBugReport({
    required String title,
    required String body,
    String? appVersion,
    String? deviceInfo,
  }) async {
    await _api.post(
      '/auth/bug-report',
      {
        'title': title,
        'body': body,
        if (appVersion != null) 'app_version': appVersion,
        if (deviceInfo != null) 'device_info': deviceInfo,
      },
      auth: true,
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.post('/auth/forgot-password', {'email': email});
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _api.post('/auth/reset-password', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
    return AuthResult.fromJson(data);
  }
}
