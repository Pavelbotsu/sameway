// One-shot: merges build/legacy_dump.json (from legacy_dump_test.dart) into
// lib/l10n/app_{en,uk,pl}.arb as legacy_* keys. Deleted with the old _t().
//
//   dart run tool/l10n/build_legacy_arb.dart
import 'dart:convert';
import 'dart:io';

/// Placeholders passed as ints (the rest are Strings).
const _intPlaceholders = {
  'driversHeadingYourWay': ['n'],
  'relayStopInfo': ['meters'],
  'detourAddsLabel': ['meters', 'seconds'],
  'adviceWalkCloser': ['meters'],
  'etaApprox': ['min'],
  'walkApproxMinutes': ['min'],
  'walkEstimate': ['minutes', 'metres'],
  'routeSummary': ['count'],
  'pendingOffersCount': ['count'],
  'ageYears': ['n'],
  'wrongCodeAttemptsLeft': ['n'],
  'noShowTooEarly': ['minutes'],
};

/// English used `count == 1 ? … : …`; these become ICU plurals. UK and PL
/// already use the "Label: N" pattern and need no plural.
const _enOverrides = {
  'routeSummary':
      '{km} km · {count, plural, =1{1 passenger} other{{count} passengers}} notified',
  'pendingOffersCount':
      '{count, plural, =1{1 offer} other{{count} offers}} awaiting reply',
  'wrongCodeAttemptsLeft':
      'Wrong code — {n, plural, =1{1 try} other{{n} tries}} left',
};

final _placeholder = RegExp(r'\{([a-zA-Z]+)\}');

void main() {
  final dump = (jsonDecode(File('build/legacy_dump.json').readAsStringSync())
          as Map<String, dynamic>)
      .cast<String, dynamic>();
  for (final code in ['en', 'uk', 'pl']) {
    final file = File('lib/l10n/app_$code.arb');
    final arb = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    dump.forEach((name, values) {
      final key = 'legacy_$name';
      var text = (values as Map<String, dynamic>)[code] as String;
      if (code == 'en' && _enOverrides.containsKey(name)) {
        text = _enOverrides[name]!;
      }
      arb[key] = text;
      if (code == 'en') {
        final names = _placeholder
            .allMatches(values['en'] as String)
            .map((m) => m.group(1)!)
            .toSet();
        final ints = _intPlaceholders[name] ?? const [];
        arb['@$key'] = {
          'description': 'Legacy AppLocalizations.$name',
          if (names.isNotEmpty)
            'placeholders': {
              for (final p in names)
                p: {'type': ints.contains(p) ? 'int' : 'String'},
            },
        };
      }
    });
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n');
  }
}
