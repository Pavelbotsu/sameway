// End-to-end smoke test: runs ON the emulator against the local backend.
//
//   cd sameway_backend && ./scripts/dev.sh          # backend on :4040
//   cd sameway && flutter test integration_test -d <emulator-id>
//
// Debug builds talk to http://10.0.2.2:4040 (the emulator's alias for the dev
// machine), so this exercises the real network path: cleartext config, the
// API client, consent at signup, the WebSocket greeting and account deletion.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/auth/auth_provider.dart';
import 'package:sameway/features/auth/auth_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final email = 'smoke-${DateTime.now().millisecondsSinceEpoch}@example.com';
  const password = 'smoke-pass-123';
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final repo = AuthRepository(api);

  test('debug build targets the local backend', () {
    expect(kApiBase, 'http://10.0.2.2:4040');
  });

  test('register needs consent, then the full account lifecycle works',
      () async {
    // Without the 18+ / terms attestations the server refuses.
    await expectLater(
      repo.register(
        name: 'Smoke Test',
        email: email,
        password: password,
        role: 'passenger',
        acceptTerms: false,
        ageConfirmed: false,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'consent_required')),
    );

    final res = await repo.register(
      name: 'Smoke Test',
      email: email,
      password: password,
      role: 'passenger',
      acceptTerms: true,
      ageConfirmed: true,
    );
    expect(res.needsConsent, isFalse);
    await storage.save(token: res.token, role: res.role, userId: res.userId);

    // Authenticated call + a consent-gated endpoint.
    final profile = await api.get('/auth/profile', auth: true) as Map;
    expect(profile['email'], email);
    await api.put('/passenger/location', {'lat': 50.0614, 'lng': 19.9366},
        auth: true);

    // The WebSocket connects and the server's hello flips it to connected.
    final ws = WebSocketClient();
    final connected = ws.state.firstWhere((s) => s == WsState.connected);
    ws.connect(res.token);
    await connected.timeout(const Duration(seconds: 10));
    ws.dispose();

    // Data export returns the account's own data.
    final export = await api.get('/auth/export', auth: true) as Map;
    expect((export['profile'] as Map)['email'], email);

    // Account deletion: wrong password is a plain 403, then it works.
    await expectLater(
      repo.deleteAccount('wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    await repo.deleteAccount(password);

    // The old login no longer works.
    await expectLater(
      repo.login(email: email, password: password),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    await storage.clear();
  });

  test('logout revokes the session on the server', () async {
    final email2 = 'logout-${DateTime.now().millisecondsSinceEpoch}@example.com';
    final res = await repo.register(
      name: 'Logout Test',
      email: email2,
      password: password,
      role: 'driver',
      acceptTerms: true,
      ageConfirmed: true,
    );
    await storage.save(token: res.token, role: res.role, userId: res.userId);
    final auth = AuthProvider(repo, storage);
    await auth.logout();

    expect(await storage.getToken(), isNull);
    final probe = await http.get(Uri.parse('$kApiBase/auth/profile'),
        headers: {'Authorization': 'Bearer ${res.token}'});
    expect(probe.statusCode, 401, reason: 'old token must be revoked');
  });

  test('legal pages are served', () async {
    for (final path in ['/legal/privacy', '/legal/terms', '/account/delete']) {
      final res = await http.get(Uri.parse('$kApiBase$path'));
      expect(res.statusCode, 200, reason: path);
      expect(utf8.decode(res.bodyBytes), contains('<html'), reason: path);
    }
  });
}
