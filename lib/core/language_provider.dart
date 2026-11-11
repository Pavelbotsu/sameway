import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  /// Starts in the phone's language when the app has it, otherwise English —
  /// until the user picks a language, which then sticks. It used to always
  /// start in English, so a Ukrainian or German phone opened in English.
  LanguageProvider({Locale? deviceLocale})
      : _locale = resolveDeviceLocale(
            deviceLocale ?? PlatformDispatcher.instance.locale) {
    _load();
  }

  Locale _locale;
  Locale get locale => _locale;

  static const _prefsKey = 'app_lang';

  /// The supported language matching [device], or English.
  static Locale resolveDeviceLocale(Locale device) =>
      AppLocalizations.supportedLanguageCodes.contains(device.languageCode)
          ? Locale(device.languageCode)
          : const Locale('en');

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null || code == _locale.languageCode) return;
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}
