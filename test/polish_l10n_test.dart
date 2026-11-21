import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/app_localizations.dart';

// Every key having a Polish version is checked on the ARB files
// (test/l10n/arb_rules_test.dart and gen-l10n's untranslated list in CI).
void main() {
  test('Polish strings are used for the pl locale', () {
    final pl = AppLocalizations(const Locale('pl'));
    expect(pl.signIn, 'Zaloguj się');
    expect(pl.wrongCodeAttemptsLeft(2), 'Zły kod — pozostałe próby: 2');
    expect(AppLocalizations.supportedLanguageCodes, contains('pl'));
    expect(AppLocalizations.delegate.isSupported(const Locale('pl')), isTrue);
  });

  test('the app ships en, uk and pl only (decision 16)', () {
    expect(AppLocalizations.supportedLanguageCodes, ['en', 'uk', 'pl']);
    for (final dropped in ['es', 'de', 'fr', 'it']) {
      expect(AppLocalizations.delegate.isSupported(Locale(dropped)), isFalse);
    }
  });

  test('the old API reads the ARB strings', () {
    final uk = AppLocalizations(const Locale('uk'));
    expect(uk.chooseRole, 'Обери свою роль, щоб почати');
    expect(uk.rideStatusLabel('done'), 'завершено');
    expect(uk.rideStatusLabel('mystery'), 'mystery');
    expect(uk.sosShareBody('https://m', null, null), contains('—'));
    final en = AppLocalizations(const Locale('en'));
    expect(en.pendingOffersCount(1), '1 offer awaiting reply');
    expect(en.pendingOffersCount(3), '3 offers awaiting reply');
  });
}
