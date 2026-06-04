import '../app_localizations.dart';

class EmailValidator {
  // RFC 5322-lite: a local part, an @, a domain with at least one dot.
  // Intentionally lenient — the server is the source of truth.
  static final RegExp _re =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  static String? validate(String? value, AppLocalizations l) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l.invalidEmail;
    if (!_re.hasMatch(v)) return l.invalidEmail;
    return null;
  }
}
