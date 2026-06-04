class TextSanitizer {
  // Strip ASCII control characters (0x00–0x1F, 0x7F) and common zero-width
  // unicode codepoints. Whitespace inside the string is preserved; only
  // leading/trailing whitespace is trimmed.
  static final RegExp _stripRe = RegExp(
    r'[\x00-\x1F\x7F​‌‍⁠﻿]',
  );

  static String sanitize(String input) {
    return input.replaceAll(_stripRe, '').trim();
  }

  /// Stricter variant for short identifier-style fields (e.g. car plate).
  /// Collapses internal whitespace runs to a single space.
  static String sanitizeIdentifier(String input) {
    return sanitize(input).replaceAll(RegExp(r'\s+'), ' ');
  }
}
