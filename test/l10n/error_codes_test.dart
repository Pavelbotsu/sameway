import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/l10n/error_codes.dart';
import 'package:sameway/l10n/l10n.dart';

void main() {
  for (final code in l10nLanguageCodes) {
    test('every server code has a real message ($code)', () {
      final l = lookupL10n(Locale(code));
      serverErrorMessages.forEach((serverCode, message) {
        final text = message(l);
        expect(text.trim(), isNotEmpty, reason: serverCode);
        expect(text, isNot(l.legacy_errGeneric), reason: serverCode);
      });
    });
  }

  test('unknown and missing codes return null', () {
    final l = lookupL10n(const Locale('en'));
    expect(serverErrorMessage(l, null), isNull);
    expect(serverErrorMessage(l, 'no_such_code'), isNull);
    expect(serverErrorMessage(l, 'wrong_code'), l.legacy_errWrongCode);
  });

  // Every `"code": "…"` the Go API sends is mapped. Runs only when the backend
  // is checked out next to the app (not in CI).
  final backend = Directory('../sameway_backend');
  test('every code the backend sends is mapped', () {
    final found = <String>{};
    final literal = RegExp(r'"code":\s*"([a-z_]+)"');
    for (final f in backend.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.go') || f.path.endsWith('_test.go')) continue;
      for (final m in literal.allMatches(f.readAsStringSync())) {
        found.add(m.group(1)!);
      }
    }
    // Codes built at run time (parseBirthDate) are listed by hand.
    found.addAll(['underage', 'birth_date_invalid']);
    expect(found.difference(serverErrorMessages.keys.toSet()), isEmpty,
        reason: 'add the code to lib/l10n/error_codes.dart');
  }, skip: backend.existsSync() ? false : 'backend not checked out');
}
