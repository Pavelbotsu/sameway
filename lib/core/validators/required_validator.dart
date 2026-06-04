import '../app_localizations.dart';

class RequiredValidator {
  /// Returns the localized "Required" message when [value] is null/empty
  /// after trimming. Pass [AppLocalizations] from the screen so the message
  /// matches the current locale.
  static String? validate(String? value, AppLocalizations l) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l.fieldRequired;
    return null;
  }
}
