// Adds or updates hand-written keys in lib/l10n/app_{en,uk,pl}.arb.
//
//   dart run tool/l10n/add_keys.dart path/to/spec.json
//
// spec.json:
//   {
//     "key": {
//       "en": "…", "uk": "…", "pl": "…",
//       "description": "…",                        (optional)
//       "placeholders": {"name": {"type": "int"}}, (optional; String by default)
//       "review": ["uk", "pl"]                     (optional; languages I wrote)
//     }
//   }
//
// Placeholders found in the English text default to String; a placeholder used
// in a plural (in any language) is an int. New keys go before the legacy_*
// block so related keys stay together.
import 'dart:convert';
import 'dart:io';

import 'icu.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/l10n/add_keys.dart spec.json');
    exit(64);
  }
  final spec = (jsonDecode(File(args.single).readAsStringSync())
      as Map<String, dynamic>);
  for (final code in ['en', 'uk', 'pl']) {
    final file = File('lib/l10n/app_$code.arb');
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final head = <String, dynamic>{};
    final tail = <String, dynamic>{};
    arb.forEach((k, v) {
      if (spec.containsKey(k) ||
          (k.startsWith('@') && spec.containsKey(k.substring(1)))) {
        return; // replaced below
      }
      final bare = k.startsWith('@') && !k.startsWith('@@') ? k.substring(1) : k;
      (bare.startsWith('legacy_') ? tail : head)[k] = v;
    });
    spec.forEach((key, raw) {
      final s = raw as Map<String, dynamic>;
      final text = s[code] as String?;
      if (text == null) {
        stderr.writeln('$key: missing $code');
        exit(1);
      }
      head[key] = code == 'uk' ? normalizeUkApostrophes(text) : text;
      if (code == 'en') {
        final plurals = {
          for (final l in ['en', 'uk', 'pl'])
            for (final a in icuArgs(s[l] as String))
              if (a.kind == 'plural') a.name,
        };
        final given =
            (s['placeholders'] as Map<String, dynamic>?) ?? const {};
        final ph = <String, dynamic>{
          for (final a in icuArgs(text))
            a.name: given[a.name] ??
                {'type': plurals.contains(a.name) ? 'int' : 'String'},
        };
        head['@$key'] = {
          if (s['description'] != null) 'description': s['description'],
          if (ph.isNotEmpty) 'placeholders': ph,
        };
      } else if ((s['review'] as List?)?.contains(code) ?? false) {
        head['@$key'] = {'x-needs-review': true};
      }
    });
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({...head, ...tail})}\n');
  }
  stdout.writeln('${spec.length} keys written');
}
