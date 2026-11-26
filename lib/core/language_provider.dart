import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import 'app_localizations.dart';

/// The app language: "Use device language" (the default) or a language the
/// user picked in PR_Language, saved on this phone. Server sync comes with
/// `user_settings` (Phase 5).
class LanguageProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// [deviceLocale] is for tests; the app follows the system locale and
  /// updates when it changes.
  LanguageProvider({Locale? deviceLocale})
      : _device = deviceLocale ?? PlatformDispatcher.instance.locale,
        _followSystem = deviceLocale == null {
    if (_followSystem) WidgetsBinding.instance.addObserver(this);
    _load();
  }

  final bool _followSystem;
  Locale _device;

  /// The language the user picked, or null for "Use device language".
  Locale? _override;
  Locale? get chosen => _override;
  bool get usesDeviceLanguage => _override == null;

  /// The language the app shows.
  Locale get locale => _override ?? resolveDeviceLocale(_device);

  /// The device language when the app has it, else English.
  Locale get deviceLanguage => resolveDeviceLocale(_device);

  static const _prefsKey = 'app_lang';

  /// The supported language matching [device], or English.
  static Locale resolveDeviceLocale(Locale device) =>
      AppLocalizations.supportedLanguageCodes.contains(device.languageCode)
          ? Locale(device.languageCode)
          : const Locale('en');

  /// The app language for code without a BuildContext (notification
  /// channels, the foreground-service notification): the saved choice when
  /// it has an ARB file, else the device language, else English.
  static Future<Locale> storedOrDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && l10nLanguageCodes.contains(code)) return Locale(code);
    return l10nResolve(PlatformDispatcher.instance.locale);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null) return;
    if (!AppLocalizations.supportedLanguageCodes.contains(code)) {
      // A language the app no longer ships: back to the device language.
      await prefs.remove(_prefsKey);
      return;
    }
    if (_override?.languageCode == code) return;
    _override = Locale(code);
    notifyListeners();
  }

  /// Use [locale] from now on, whatever the device language.
  Future<void> setLocale(Locale locale) async {
    if (_override == locale) return;
    _override = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }

  /// Follow the device language again.
  Future<void> useDeviceLanguage() async {
    if (_override == null) return;
    _override = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final next = locales?.isNotEmpty == true
        ? locales!.first
        : PlatformDispatcher.instance.locale;
    if (next == _device) return;
    _device = next;
    if (_override == null) notifyListeners();
  }

  @override
  void dispose() {
    if (_followSystem) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
