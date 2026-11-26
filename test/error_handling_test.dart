import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/error_handling.dart';
import 'package:sameway/l10n/l10n.dart';

Future<BuildContext> _context(WidgetTester tester, String lang) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    locale: Locale(lang),
    localizationsDelegates: const [
      L10nFallbackDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('uk'), Locale('pl')],
    home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }),
  ));
  return ctx;
}

void main() {
  final logged = <String>[];
  setUp(() {
    logged.clear();
    resetReportedGenericErrors();
    genericErrorSink = logged.add;
  });

  testWidgets('a wrong password (401) is not "session expired"',
      (tester) async {
    final ctx = await _context(tester, 'uk');
    final l = ctx.l10n;
    expect(
        friendlyError(ctx,
            const ApiException('invalid credentials', statusCode: 401)),
        l.legacy_errInvalidCredentials);
    expect(
        friendlyError(ctx,
            const ApiException('current password is incorrect', statusCode: 401)),
        l.legacy_errCurrentPasswordWrong);
    expect(friendlyError(ctx, const ApiException('session expired', statusCode: 401)),
        l.legacy_errSessionExpired);
    expect(logged, isEmpty);
  });

  testWidgets('user-fixable errors get their own message', (tester) async {
    final ctx = await _context(tester, 'pl');
    final l = ctx.l10n;
    expect(
        friendlyError(ctx,
            const ApiException('email already registered', statusCode: 409)),
        l.legacy_errEmailTaken);
    expect(
        friendlyError(
            ctx,
            const ApiException("Sameway isn't available here yet",
                statusCode: 403, code: 'outside_service_area')),
        l.legacy_outsideServiceArea);
    expect(
        friendlyError(ctx,
            const ApiException('x', statusCode: 403, code: 'wrong_password')),
        l.err_passwordIncorrect);
    expect(
        friendlyError(
            ctx,
            const ApiException('bio is too long (max 160 characters)',
                statusCode: 400)),
        l.err_textTooLong(160));
    expect(
        friendlyError(
            ctx, const ApiException('anything', statusCode: 429)),
        l.err_tooManyRequests);
    expect(logged, isEmpty);
  });

  testWidgets('the code and its numbers come from the response body',
      (tester) async {
    final ctx = await _context(tester, 'en');
    final e = ApiException.fromResponse(http.Response(
        '{"error":"wrong code","code":"wrong_code","attempts_left":2}', 400));
    expect(e.code, 'wrong_code');
    expect(friendlyError(ctx, e), ctx.l10n.legacy_wrongCodeAttemptsLeft(2));
  });

  testWidgets('the generic fallback logs the raw server message once',
      (tester) async {
    final ctx = await _context(tester, 'en');
    final l = ctx.l10n;
    const e = ApiException('coordinates out of range', statusCode: 400);
    expect(friendlyError(ctx, e), l.legacy_errGeneric);
    expect(friendlyError(ctx, e), l.legacy_errGeneric); // e.g. a rebuild
    expect(logged, ['HTTP 400: coordinates out of range']);

    expect(friendlyError(ctx, StateError('boom')), l.legacy_errGeneric);
    expect(logged.last, contains('boom'));
  });

  testWidgets('offline, server and not-found errors are not "generic"',
      (tester) async {
    final ctx = await _context(tester, 'en');
    final l = ctx.l10n;
    expect(friendlyError(ctx, const SocketException('x')), l.legacy_errOffline);
    expect(friendlyError(ctx, const ApiException('db error', statusCode: 500)),
        l.legacy_errServer);
    expect(friendlyError(ctx, const ApiException('trip not found', statusCode: 404)),
        l.legacy_errNotFound);
    expect(logged, isEmpty);
  });
}
