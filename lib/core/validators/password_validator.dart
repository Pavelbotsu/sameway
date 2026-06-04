import '../app_localizations.dart';

class PasswordValidator {
  static const int minLength = 6;

  static String? validate(String? value, AppLocalizations l) {
    final v = value ?? '';
    if (v.length < minLength) return l.minSixChars;
    return null;
  }

  /// Returns null when [confirm] matches [original]; otherwise the localized
  /// "passwords do not match" message. Both inputs are compared verbatim
  /// (no trim) so trailing whitespace is treated as significant.
  static String? confirm(
      String? original, String? confirm, AppLocalizations l) {
    if ((original ?? '') != (confirm ?? '')) return l.passwordsNotMatch;
    return null;
  }
}
