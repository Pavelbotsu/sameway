import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'gen/l10n.dart';

export 'gen/l10n.dart';

/// `context.l10n.pHome_whereTo` — the generated ARB strings (lib/l10n/*.arb).
extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}

/// Language codes with an ARB file. Single source for the picker, the
/// device-language fallback and `MaterialApp.supportedLocales`.
const l10nLanguageCodes = ['en', 'uk', 'pl'];

/// The supported locale for [locale]'s language, or English.
Locale l10nResolve(Locale locale) => l10nLanguageCodes.contains(locale.languageCode)
    ? Locale(locale.languageCode)
    : const Locale('en');

/// [L10n] for code that has no `BuildContext` (notification channels, the
/// foreground-service notification). Unsupported locales get English.
L10n l10nFor(Locale locale) => lookupL10n(l10nResolve(locale));

/// Registered instead of `L10n.delegate`: it accepts every locale and loads
/// English for the ones without an ARB file, so `L10n.of(context)` never
/// fails (e.g. in a test or widget tree with another locale).
class L10nFallbackDelegate extends LocalizationsDelegate<L10n> {
  const L10nFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<L10n> load(Locale locale) =>
      SynchronousFuture<L10n>(l10nFor(locale));

  @override
  bool shouldReload(L10nFallbackDelegate old) => false;
}
