import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts in the device language when supported', () {
    SharedPreferences.setMockInitialValues({});
    expect(LanguageProvider(deviceLocale: const Locale('uk', 'UA')).locale,
        const Locale('uk'));
    expect(LanguageProvider(deviceLocale: const Locale('de', 'AT')).locale,
        const Locale('de'));
    expect(LanguageProvider(deviceLocale: const Locale('pl', 'PL')).locale,
        const Locale('pl'));
  });

  test('falls back to English for unsupported device languages', () {
    SharedPreferences.setMockInitialValues({});
    expect(LanguageProvider(deviceLocale: const Locale('ja')).locale,
        const Locale('en'));
  });

  test("the user's own choice wins over the device language", () async {
    SharedPreferences.setMockInitialValues({'app_lang': 'it'});
    final p = LanguageProvider(deviceLocale: const Locale('uk'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.locale, const Locale('it'));

    await p.setLocale(const Locale('fr'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_lang'), 'fr');
  });
}
