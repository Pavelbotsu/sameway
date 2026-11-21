import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts in the device language when supported', () {
    SharedPreferences.setMockInitialValues({});
    expect(LanguageProvider(deviceLocale: const Locale('uk', 'UA')).locale,
        const Locale('uk'));
    expect(LanguageProvider(deviceLocale: const Locale('pl', 'PL')).locale,
        const Locale('pl'));
  });

  test('falls back to English for unsupported device languages', () {
    SharedPreferences.setMockInitialValues({});
    expect(LanguageProvider(deviceLocale: const Locale('ja')).locale,
        const Locale('en'));
  });

  test('uses the device language until the user picks one', () async {
    SharedPreferences.setMockInitialValues({});
    final p = LanguageProvider(deviceLocale: const Locale('uk'));
    await _settle();
    expect(p.usesDeviceLanguage, isTrue);
    expect(p.chosen, isNull);
    expect(p.deviceLanguage, const Locale('uk'));
  });

  test("the user's own choice wins over the device language", () async {
    SharedPreferences.setMockInitialValues({'app_lang': 'pl'});
    final p = LanguageProvider(deviceLocale: const Locale('uk'));
    await _settle();
    expect(p.locale, const Locale('pl'));
    expect(p.usesDeviceLanguage, isFalse);

    await p.setLocale(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_lang'), 'en');
    expect(p.locale, const Locale('en'));
  });

  test('"Use device language" forgets the choice', () async {
    SharedPreferences.setMockInitialValues({'app_lang': 'pl'});
    final p = LanguageProvider(deviceLocale: const Locale('uk'));
    await _settle();
    await p.useDeviceLanguage();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_lang'), isNull);
    expect(p.chosen, isNull);
    expect(p.locale, const Locale('uk'));
  });

  test('a saved language the app no longer has falls back to the device',
      () async {
    SharedPreferences.setMockInitialValues({'app_lang': 'ja'});
    final p = LanguageProvider(deviceLocale: const Locale('uk'));
    await _settle();
    expect(p.locale, const Locale('uk'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_lang'), isNull);
  });

  test('dropped languages (es/de/fr/it) fall back to device → English',
      () async {
    for (final dropped in ['es', 'de', 'fr', 'it']) {
      SharedPreferences.setMockInitialValues({'app_lang': dropped});
      final onUk = LanguageProvider(deviceLocale: const Locale('uk'));
      await _settle();
      expect(onUk.locale, const Locale('uk'), reason: dropped);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_lang'), isNull, reason: dropped);

      SharedPreferences.setMockInitialValues({'app_lang': dropped});
      final onGerman = LanguageProvider(deviceLocale: const Locale('de'));
      await _settle();
      expect(onGerman.locale, const Locale('en'), reason: dropped);
    }
  });

  test('storedOrDevice reads the saved choice for code without a context',
      () async {
    SharedPreferences.setMockInitialValues({'app_lang': 'uk'});
    expect(await LanguageProvider.storedOrDevice(), const Locale('uk'));
  });
}
