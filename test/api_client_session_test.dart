import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/app_localizations.dart';
import 'package:sameway/core/error_handling.dart';
import 'package:sameway/core/session.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs one authenticated GET against a canned response and reports which
/// session signals fired.
Future<({ApiException error, List<String> signals})> _call(
    int status, Map<String, dynamic> body) async {
  final signals = <String>[];
  final s = SessionEvents.instance;
  final subs = [
    s.onExpired.listen((_) => signals.add('expired')),
    s.onConsentRequired.listen((_) => signals.add('consent')),
    s.onSuspended.listen((_) => signals.add('suspended')),
  ];
  late ApiException err;
  await http.runWithClient(() async {
    try {
      await ApiClient(TokenStorage()).get('/x', auth: true);
      fail('expected ApiException');
    } on ApiException catch (e) {
      err = e;
    }
  }, () => MockClient((_) async => http.Response(jsonEncode(body), status)));
  await Future<void>.delayed(Duration.zero); // let broadcast listeners run
  for (final sub in subs) {
    await sub.cancel();
  }
  return (error: err, signals: signals);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  // SessionEvents throttles each signal for 5 s, so each kind fires once here.
  test('403 consent_required shows the terms gate, not a logout', () async {
    final r = await _call(403, {'error': 'accept the current terms', 'code': 'consent_required'});
    expect(r.signals, ['consent']);
    expect(r.error.code, 'consent_required');
  });

  test('403 account_suspended signs the user out', () async {
    final r = await _call(403, {'error': 'suspended', 'code': 'account_suspended'});
    expect(r.signals, ['suspended']);
  });

  test('an ordinary 403 does not touch the session', () async {
    final r = await _call(403, {'error': 'not a participant'});
    expect(r.signals, isEmpty);
    expect(r.error.statusCode, 403);
    expect(r.error.code, isNull);
  });

  test('401 still means session expired', () async {
    final r = await _call(401, {'error': 'session expired'});
    expect(r.signals, ['expired']);
  });

  testWidgets('friendlyError: 403 is no longer "session expired"',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(ctx);
    expect(
        friendlyError(ctx, const ApiException('not a participant on this ride', statusCode: 403)),
        'not a participant on this ride');
    expect(
        friendlyError(ctx,
            const ApiException('x', statusCode: 403, code: 'account_suspended')),
        l.accountSuspended);
    expect(friendlyError(ctx, const ApiException('x', statusCode: 401)),
        l.errSessionExpired);
  });
}
