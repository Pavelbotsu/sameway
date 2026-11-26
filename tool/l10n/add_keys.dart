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
// A language left out of an existing key keeps its text. Existing keys are
// updated in place and keep their metadata unless the spec gives new values.
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
  final arbs = {
    for (final code in ['en', 'uk', 'pl'])
      code: jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>,
  };
  String textOf(String key, String code) {
    final s = spec[key] as Map<String, dynamic>;
    final t = (s[code] as String?) ?? arbs[code]![key] as String?;
    if (t == null) {
      stderr.writeln('$key: missing $code');
      exit(1);
    }
    return code == 'uk' ? normalizeUkApostrophes(t) : t;
  }

  for (final code in ['en', 'uk', 'pl']) {
    final arb = arbs[code]!;
    final head = <String, dynamic>{};
    final tail = <String, dynamic>{};
    final updated = <String, dynamic>{};
    spec.forEach((key, raw) {
      final s = raw as Map<String, dynamic>;
      updated[key] = textOf(key, code);
      final old = arb['@$key'] as Map<String, dynamic>?;
      if (code == 'en') {
        final plurals = {
          for (final l in ['en', 'uk', 'pl'])
            for (final a in icuArgs(textOf(key, l)))
              if (a.kind == 'plural') a.name,
        };
        final given = (s['placeholders'] as Map<String, dynamic>?) ??
            (old?['placeholders'] as Map<String, dynamic>?) ??
            const {};
        final ph = <String, dynamic>{
          for (final a in icuArgs(updated[key] as String))
            a.name: given[a.name] ??
                {'type': plurals.contains(a.name) ? 'int' : 'String'},
        };
        updated['@$key'] = {
          ...?old,
          if (s['description'] != null) 'description': s['description'],
        }..remove('placeholders');
        if (ph.isNotEmpty) (updated['@$key'] as Map)['placeholders'] = ph;
        if ((updated['@$key'] as Map).isEmpty) updated.remove('@$key');
      } else if ((s['review'] as List?)?.contains(code) ?? false) {
        updated['@$key'] = {...?old, 'x-needs-review': true};
      } else if (old != null) {
        updated['@$key'] = old;
      }
    });
    arb.forEach((k, v) {
      if (updated.containsKey(k)) {
        head[k] = updated.remove(k); // in place
        return;
      }
      final bare = k.startsWith('@') && !k.startsWith('@@') ? k.substring(1) : k;
      if (spec.containsKey(bare)) return; // metadata dropped by the update
      (bare.startsWith('legacy_') ? tail : head)[k] = v;
    });
    // New keys (and new metadata of existing keys) that had no slot yet.
    final pending = Map.of(updated);
    final out = <String, dynamic>{};
    for (final e in {...head, ...tail}.entries) {
      out[e.key] = e.value;
      final meta = '@${e.key}';
      if (pending.containsKey(meta) && !e.key.startsWith('@')) {
        out[meta] = pending.remove(meta);
      }
    }
    final fresh = <String, dynamic>{};
    for (final k in pending.keys.where((k) => !k.startsWith('@'))) {
      fresh[k] = pending[k];
      if (pending.containsKey('@$k')) fresh['@$k'] = pending['@$k'];
    }
    final result = <String, dynamic>{};
    var inserted = false;
    for (final e in out.entries) {
      final bare = e.key.startsWith('@') && !e.key.startsWith('@@')
          ? e.key.substring(1)
          : e.key;
      if (!inserted && bare.startsWith('legacy_')) {
        result.addAll(fresh);
        inserted = true;
      }
      result[e.key] = e.value;
    }
    if (!inserted) result.addAll(fresh);
    File('lib/l10n/app_$code.arb').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(result)}\n');
  }
  stdout.writeln('${spec.length} keys written');
}
