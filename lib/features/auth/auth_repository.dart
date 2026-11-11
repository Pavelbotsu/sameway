import '../../core/api_client.dart';
import '../legal/birth_date_field.dart' show formatBirthDate;

class AuthResult {
  final String token;
  final String userId;
  final String role;
  final String? name;
  final String? email;

  /// Server says this account still has to accept the current Terms/Privacy
  /// version and confirm 18+ (accounts older than consent, or after a version
  /// bump). Absent → false (older backends).
  final bool needsConsent;

  /// The consent screen must also collect the date of birth (account
  /// predates it). Absent → false.
  final bool needsBirthDate;

  AuthResult.fromJson(Map<String, dynamic> j)
      : token = j['token'] as String,
        userId = j['user_id'] as String,
        role = j['role'] as String,
        name = j['name'] as String?,
        email = j['email'] as String?,
        needsConsent = j['needs_consent'] as bool? ?? false,
        needsBirthDate = j['needs_birth_date'] as bool? ?? false;
}

class AuthRepository {
  final ApiClient _api;
  AuthRepository(this._api);

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required bool acceptTerms,
    required bool ageConfirmed,
    required DateTime birthDate,
  }) async {
    final data = await _api.post('/auth/register', {
      'birth_date': formatBirthDate(birthDate),
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'accept_terms': acceptTerms,
      'age_confirmed': ageConfirmed,
    });
    return AuthResult.fromJson(data);
  }

  /// Records acceptance of the current Terms/Privacy + the 18+ attestation
  /// for an account that predates them.
  Future<void> acceptTerms({DateTime? birthDate}) async {
    await _api.post(
      '/auth/consent',
      {
        'accept_terms': true,
        'age_confirmed': true,
        if (birthDate != null) 'birth_date': formatBirthDate(birthDate),
      },
      auth: true,
    );
  }

  /// Permanently deletes the account. Throws ApiException with statusCode
  /// 403 (wrong password) or 409 (ride in progress).
  Future<void> deleteAccount(String password) async {
    await _api.post('/auth/delete-account', {'password': password}, auth: true);
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
