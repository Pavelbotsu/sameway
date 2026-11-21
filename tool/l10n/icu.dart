// Minimal ICU MessageFormat reader for the ARB tools and tests: finds the
// arguments of a message and the branches of its plural/select arguments.
// Matches gen-l10n with use-escaping off (apostrophes are literal).

class IcuArg {
  IcuArg(this.name, this.kind, this.branches);

  /// Placeholder name.
  final String name;

  /// null for a plain `{name}`, else `plural`, `select`, …
  final String? kind;

  /// Branch selector → branch text (plural/select only).
  final Map<String, String> branches;
}

/// All arguments in [message], including those nested in branches.
List<IcuArg> icuArgs(String message) {
  final out = <IcuArg>[];
  _scan(message, out);
  return out;
}

void _scan(String s, List<IcuArg> out) {
  var i = 0;
  while (i < s.length) {
    if (s[i] != '{') {
      i++;
      continue;
    }
    final end = _matching(s, i);
    final body = s.substring(i + 1, end);
    final comma = body.indexOf(',');
    if (comma < 0) {
      out.add(IcuArg(body.trim(), null, const {}));
    } else {
      final name = body.substring(0, comma).trim();
      final rest = body.substring(comma + 1);
      final comma2 = rest.indexOf(',');
      final kind = (comma2 < 0 ? rest : rest.substring(0, comma2)).trim();
      final branches = <String, String>{};
      if (comma2 >= 0) {
        final b = rest.substring(comma2 + 1);
        var j = 0;
        while (j < b.length) {
          final open = b.indexOf('{', j);
          if (open < 0) break;
          final selector = b.substring(j, open).trim();
          final close = _matching(b, open);
          final text = b.substring(open + 1, close);
          branches[selector] = text;
          _scan(text, out);
          j = close + 1;
        }
      }
      out.add(IcuArg(name, kind, branches));
    }
    i = end + 1;
  }
}

int _matching(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw FormatException('unbalanced braces', s, open);
}

/// Ukrainian uses one apostrophe, ’ (U+2019): "ім’я", "п’ятниця". The deck
/// and the old strings mix in ' and ʼ (U+02BC).
String normalizeUkApostrophes(String s) =>
    s.replaceAll("'", '’').replaceAll('ʼ', '’');

/// The message with every argument replaced by `{name}` and branches dropped:
/// the text a reader sees around the placeholders.
String icuSkeleton(String message) {
  final b = StringBuffer();
  var i = 0;
  while (i < message.length) {
    if (message[i] == '{') {
      final end = _matching(message, i);
      final body = message.substring(i + 1, end);
      final comma = body.indexOf(',');
      b.write('{${(comma < 0 ? body : body.substring(0, comma)).trim()}}');
      i = end + 1;
    } else {
      b.write(message[i]);
      i++;
    }
  }
  return b.toString();
}
