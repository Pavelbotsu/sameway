import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/app_localizations.dart';

void main() {
  test('every translated string has a Polish version', () {
    final src = File('lib/core/app_localizations.dart').readAsStringSync();
    final calls = RegExp(r'_t\(\s*\n\s*en:').allMatches(src).length;
    final pl = RegExp(r'^\s*pl: ', multiLine: true).allMatches(src).length;
    expect(calls, greaterThan(300));
    expect(pl, calls, reason: 'add a pl: argument to new _t(...) strings');
  });

  test('Polish strings are used for the pl locale', () {
    final pl = AppLocalizations(const Locale('pl'));
    expect(pl.signIn, 'Zaloguj się');
    expect(pl.wrongCodeAttemptsLeft(2), 'Zły kod — pozostałe próby: 2');
    expect(AppLocalizations.supportedLanguageCodes, contains('pl'));
    expect(AppLocalizations.delegate.isSupported(const Locale('pl')), isTrue);
  });
}
