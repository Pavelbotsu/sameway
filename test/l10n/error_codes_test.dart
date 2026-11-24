import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/l10n/error_codes.dart';
import 'package:sameway/l10n/l10n.dart';

void main() {
  for (final code in l10nLanguageCodes) {
    test('every server code and message has a real message ($code)', () {
      final l = lookupL10n(Locale(code));
      serverErrorMessages.forEach((serverCode, message) {
        final text = message(l, const {});
        expect(text.trim(), isNotEmpty, reason: serverCode);
        expect(text, isNot(l.legacy_errGeneric), reason: serverCode);
      });
      serverMessageTexts.forEach((serverText, message) {
        final text = message(l);
        expect(text.trim(), isNotEmpty, reason: serverText);
        expect(text, isNot(l.legacy_errGeneric), reason: serverText);
      });
    });
  }

  test('unknown and missing codes return null', () {
    final l = lookupL10n(const Locale('en'));
    expect(serverErrorMessage(l, null), isNull);
    expect(serverErrorMessage(l, 'no_such_code'), isNull);
    expect(serverErrorMessage(l, 'wrong_code'), l.legacy_errWrongCode);
  });

  test('codes use the numbers the server sends', () {
    final l = lookupL10n(const Locale('en'));
    expect(serverErrorMessage(l, 'wrong_code', {'attempts_left': 2}),
        l.legacy_wrongCodeAttemptsLeft(2));
    expect(serverErrorMessage(l, 'no_show_too_early', {'wait_s': 61}),
        l.legacy_noShowTooEarly(2));
    expect(serverErrorMessage(l, 'no_show_too_early'), l.err_noShowTooEarly);
  });

  test('messages without a code: exact, limits and binding errors', () {
    final l = lookupL10n(const Locale('en'));
    expect(serverMessageText(l, 'invalid credentials'),
        l.legacy_errInvalidCredentials);
    expect(serverMessageText(l, 'email already registered'),
        l.legacy_errEmailTaken);
    expect(serverMessageText(l, 'bio is too long (max 160 characters)'),
        l.err_textTooLong(160));
    expect(serverMessageText(l, 'message too long (max 2000 characters)'),
        l.err_textTooLong(2000));
    expect(serverMessageText(l, 'photo is too large (max 3 MB)'),
        l.err_photoTooLarge('3'));
    expect(
        serverMessageText(
            l,
            "Key: 'req.Email' Error:Field validation for 'Email' failed on "
            "the 'email' tag"),
        l.err_emailInvalid);
    expect(
        serverMessageText(
            l,
            "Key: 'req.NewPassword' Error:Field validation for 'NewPassword' "
            "failed on the 'min' tag"),
        l.legacy_passwordTooShort);
    expect(serverMessageText(l, 'coordinates out of range'), isNull);
  });

  // Runs only when the backend is checked out next to the app (not in CI).
  final backend = Directory('../sameway_backend');
  Iterable<String> goSources() sync* {
    for (final f in backend.listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.go') && !f.path.endsWith('_test.go')) {
        yield f.readAsStringSync();
      }
    }
  }

  test('every code the backend sends is mapped', () {
    final found = <String>{};
    final literal = RegExp(r'"code":\s*"([a-z_]+)"');
    for (final src in goSources()) {
      for (final m in literal.allMatches(src)) {
        found.add(m.group(1)!);
      }
    }
    // Codes built at run time (parseBirthDate) are listed by hand.
    found.addAll(['underage', 'birth_date_invalid']);
    expect(found.difference(serverErrorMessages.keys.toSet()), isEmpty,
        reason: 'add the code to lib/l10n/error_codes.dart');
  }, skip: backend.existsSync() ? false : 'backend not checked out');

  // A new 4xx message without a code must be decided: mapped in
  // serverMessageTexts (the user can act on it) or listed here (client bug,
  // can't happen from the app's UI, or a 404 that "Not found" covers).
  const genericOnPurpose = {
    'cannot block yourself',
    'cannot message yourself',
    'cannot rate yourself',
    'cannot request yourself',
    'comment is too long (max 500 characters)', // matched by the limit rule
    'conversation not found',
    'conversation_id or ride_request_id required',
    'coordinates out of range',
    'distance_km out of range',
    'driver not active',
    'forbidden',
    'invalid token',
    'message too long (max 2000 characters)', // matched by the limit rule
    'missing token',
    'no accepted ride for this passenger',
    'no accepted ride to reset',
    'not a participant on this ride',
    'not a participant',
    'not part of this ride',
    'only the passenger can confirm pickup',
    'passenger location unknown',
    'photo is too large (max 3 MB)', // matched by the photo rule
    'planned_after must be an RFC3339 timestamp',
    'planned_at must be an RFC3339 timestamp',
    'rated user was not on this ride',
    'reason too long (max 1000 characters)', // matched by the limit rule
    'request not found',
    'ride has not been completed',
    'ride not found or not yours',
    'ride not found',
    'ride request not found',
    'send the image in the \'photo\' field',
    'session expired',
    'trip not found',
  };
  test('every 4xx message without a code is decided', () {
    // c.JSON(http.StatusXxx, gin.H{"error": "…"}) on one line, without "code".
    final site = RegExp(
        r'http\.Status(\w+),\s*gin\.H\{"error":\s*"((?:[^"\\]|\\.)*)"(?:\s*\})');
    final open = <String>{};
    for (final src in goSources()) {
      for (final m in site.allMatches(src)) {
        final status = m.group(1)!;
        if (const {'InternalServerError', 'ServiceUnavailable', 'BadGateway',
          'GatewayTimeout'}.contains(status)) {
          continue;
        }
        final msg = m.group(2)!.replaceAll(r'\"', '"');
        final l = lookupL10n(const Locale('en'));
        if (serverMessageText(l, msg) == null &&
            !genericOnPurpose.contains(msg)) {
          open.add('$status: $msg');
        }
      }
    }
    expect(open, isEmpty,
        reason: 'map it in lib/l10n/error_codes.dart (serverMessageTexts) or '
            'add it to genericOnPurpose here');
  }, skip: backend.existsSync() ? false : 'backend not checked out');
}
