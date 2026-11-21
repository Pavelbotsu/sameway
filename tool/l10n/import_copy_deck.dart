// Imports design-pack/l10n/copy_deck.csv into lib/l10n/app_{en,uk,pl}.arb.
//
//   dart run tool/l10n/import_copy_deck.dart            # write ARB files
//   dart run tool/l10n/import_copy_deck.dart --report   # list rows needing a decision
//
// Every deck row ends up as exactly one of:
//   * an ARB key (derived from the first screen + the suggested key), or
//   * merged into another key, or
//   * skipped with a reason (board note, OS string, sample value).
// Rows that contain sample data (names, times, prices, places, counts) or have
// no translation need an explicit line in tool/l10n/copy_deck_map.txt
// (fields separated by " | "; the deck never contains "|"):
//
//   suggested_key | action | key | en | uk | pl | review
//   suggested_key | pl | <Polish text>          (deck en/uk, Polish written by me)
//   suggested_key | skip | <reason>
//
//   action  keep   import the deck text as is (key column optional)
//           icu    use the en/uk/pl columns (ICU, placeholders); empty uk/pl
//                  columns fall back to the deck cell
//           merge  key column = the ARB key this row duplicates
//           skip   key column = reason
//   review  which languages I wrote or changed beyond swapping a sample for a
//           placeholder: "uk", "pl", "uk pl" (→ "x-needs-review" in that ARB)
//
// The importer owns the ARB keys whose English metadata has "x-deck"; other
// keys (legacy_*, formatting, errors) are left alone.
import 'dart:convert';
import 'dart:io';

import 'icu.dart';

const _deckPath = '../design-pack/l10n/copy_deck.csv';
const _mapPath = 'tool/l10n/copy_deck_map.txt';

/// Boards that are design artefacts, not app screens.
const _boards = {'Platform', 'Rules', 'Errors'};

/// Variant boards: the same screens drawn again (light, small, XL, platform).
const _variantBoards = {'L_Screens', 'SE_Screens', 'XL_Screens'};

final _sample = RegExp(
  r'\d|Marek|Olena|Kasia|Tomasz|Ewa|Pavlo|Anna|Oksana|Piotr|Jan\b|Ola\b|'
  r'Mogilsk|Politechnik|Kraków|Krakow|Rzeszów|Tarnów|Bochni|Dębic|Zakopan|'
  r'Wieliczk|Galeri|Rondo|ul\.|Škoda|Octavia|Toyota|@example',
);

class Row {
  Row(this.key, this.type, this.screens, this.en, this.pl, this.uk);
  final String key, type, en, pl, uk;
  final List<String> screens;
}

class MapLine {
  MapLine(this.action, this.key, this.en, this.uk, this.pl, this.review);
  final String action, key, en, uk, pl;
  final Set<String> review;
}

void main(List<String> args) {
  final report = args.contains('--report');
  final rows = _readDeck();
  final map = _readMap();

  final unresolved = <Row>[];
  final out = <String, Map<String, String>>{}; // key → {en, uk, pl}
  final meta = <String, Map<String, dynamic>>{};
  final review = <String, Set<String>>{}; // key → langs
  final used = <String>{};

  for (final r in rows) {
    final m = map[r.key];
    if (m == null) {
      if (_needsDecision(r)) {
        unresolved.add(r);
        continue;
      }
      if (_autoSkip(r) != null) continue;
    }
    if (m != null && (m.action == 'skip' || m.action == 'merge')) continue;
    if (m == null && _autoSkip(r) != null) continue;

    final key = (m != null && m.key.isNotEmpty) ? m.key : _deriveKey(r, used);
    if (!used.add(key)) {
      stderr.writeln('duplicate key $key (${r.key})');
      exitCode = 1;
    }
    final icu = m?.action == 'icu';
    final en = icu && m!.en.isNotEmpty ? m.en : r.en;
    final uk = icu && m!.uk.isNotEmpty ? m.uk : (m?.uk.isNotEmpty ?? false) ? m!.uk : r.uk;
    final pl = icu && m!.pl.isNotEmpty ? m.pl : (m?.pl.isNotEmpty ?? false) ? m!.pl : r.pl;
    if (uk.isEmpty || pl.isEmpty) {
      stderr.writeln('missing uk/pl for ${r.key} → $key');
      exitCode = 1;
    }
    out[key] = {'en': en, 'uk': uk, 'pl': pl};
    final langs = <String>{...?m?.review};
    if (r.uk.isEmpty) langs.add('uk');
    if (r.pl.isEmpty) langs.add('pl');
    if (langs.isNotEmpty) review[key] = langs;
    meta[key] = {
      'description': [
        if (r.type == 'a11y label') 'Semantics label.',
        if (r.type == 'placeholder') 'Field hint.',
        'Screens: ${r.screens.join(' ')}',
      ].join(' '),
      'x-deck': r.key,
    };
  }

  // Map lines for keys the deck no longer has.
  final deckKeys = rows.map((r) => r.key).toSet();
  for (final k in map.keys) {
    if (!deckKeys.contains(k)) stderr.writeln('map line for unknown row $k');
  }
  // Merge targets must exist.
  map.forEach((k, m) {
    if (m.action == 'merge' && !used.contains(m.key)) {
      stderr.writeln('merge target ${m.key} ($k) is not a key');
      exitCode = 1;
    }
  });

  if (report) {
    for (final r in unresolved) {
      stdout.writeln([r.key, r.type, r.screens.join(' '), r.en, r.uk, r.pl]
          .join('\t'));
    }
    stderr.writeln('${unresolved.length} rows need a decision; '
        '${out.length} keys would be written');
    return;
  }
  if (unresolved.isNotEmpty) {
    stderr.writeln('${unresolved.length} rows need a line in $_mapPath '
        '(run with --report)');
    exit(1);
  }
  if (exitCode != 0) exit(exitCode);
  _writeArb(out, meta, review);
  stdout.writeln('${out.length} deck keys written');
}

bool _needsDecision(Row r) {
  if (_autoSkip(r) != null) return false;
  return r.uk.isEmpty || r.pl.isEmpty || _sample.hasMatch(r.en);
}

/// Rows skipped without a map line: board notes and rows only on boards.
String? _autoSkip(Row r) {
  final real = r.screens.where((s) => !_boards.contains(s)).toList();
  if (real.isEmpty && r.uk.isEmpty) return 'board-note';
  return null;
}

String _family(String screen) {
  final i = screen.indexOf('_');
  return i < 0 ? screen : screen.substring(0, i);
}

String _deriveKey(Row r, Set<String> used) {
  final real = r.screens
      .where((s) => !_boards.contains(s) && !_variantBoards.contains(s))
      .toList();
  final screens = real.isEmpty ? r.screens : real;
  final families = screens.map(_family).where((f) => f != 'PF').toSet();
  final prefix = families.length >= 2 ? 'common' : _camel(screens.first);
  var purpose = r.key.substring(r.key.indexOf('_') + 1);
  var p = _camel(purpose);
  if (p.isEmpty || RegExp(r'^\d').hasMatch(p)) p = 'n$p';
  p = p[0].toLowerCase() + p.substring(1);
  final suffix = switch (r.type) {
    'a11y label' => '_a11y',
    'placeholder' => '_hint',
    _ => '',
  };
  var key = '${prefix}_$p$suffix';
  var n = 2;
  while (used.contains(key)) {
    key = '${prefix}_$p$n$suffix';
    n++;
  }
  return key;
}

/// "PR_Language" → "prLanguage", "DI_D_Approach" → "diDApproach",
/// "names_are_shown" → "namesAreShown".
String _camel(String s) {
  final parts = s.split(RegExp(r'[_\-\s]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first.toLowerCase();
  return first +
      parts
          .skip(1)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();
}

List<Row> _readDeck() {
  final text = File(_deckPath).readAsStringSync();
  final lines = _parseCsv(text);
  final header = lines.first;
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  return [
    for (final l in lines.skip(1))
      if (l.length == header.length)
        Row(
          l[idx['suggested_key']!],
          l[idx['type']!],
          l[idx['screens']!].split(' '),
          l[idx['en']!],
          l[idx['pl']!],
          l[idx['uk']!],
        ),
  ];
}

List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

Map<String, MapLine> _readMap() {
  final f = File(_mapPath);
  if (!f.existsSync()) return {};
  final out = <String, MapLine>{};
  for (final raw in f.readAsLinesSync()) {
    if (raw.trim().isEmpty || raw.startsWith('#')) continue;
    final c = raw.split('|');
    String at(int i) => i < c.length ? c[i].trim() : '';
    if (out.containsKey(at(0))) {
      stderr.writeln('duplicate map line ${at(0)}');
      exitCode = 1;
    }
    out[at(0)] = at(1) == 'pl'
        // "key | pl | text": deck en/uk, Polish written by me.
        ? MapLine('keep', '', '', '', at(2), const {})
        : MapLine(at(1), at(2), at(3), at(4), at(5),
            at(6).split(' ').where((s) => s.isNotEmpty).toSet());
    if (!{'keep', 'icu', 'merge', 'skip', 'pl'}.contains(at(1))) {
      stderr.writeln('bad action "${at(1)}" for ${at(0)}');
      exitCode = 1;
    }
  }
  return out;
}

void _writeArb(Map<String, Map<String, String>> out,
    Map<String, Map<String, dynamic>> meta, Map<String, Set<String>> review) {
  // Keys this importer wrote before carry x-deck in the English metadata.
  // Read English once, before it is rewritten, so uk/pl drop the same keys.
  final enBefore = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
      as Map<String, dynamic>;
  final owned = enBefore.keys
      .where((k) =>
          k.startsWith('@') &&
          !k.startsWith('@@') &&
          enBefore[k] is Map &&
          (enBefore[k] as Map).containsKey('x-deck'))
      .map((k) => k.substring(1))
      .toSet();
  Set<String>? enKeysAfter;
  for (final code in ['en', 'uk', 'pl']) {
    final file = File('lib/l10n/app_$code.arb');
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    String bare(String k) =>
        k.startsWith('@') && !k.startsWith('@@') ? k.substring(1) : k;
    arb.removeWhere((k, _) =>
        owned.contains(bare(k)) ||
        // Leftovers in uk/pl from an earlier run (e.g. a renamed key).
        (enKeysAfter != null && !k.startsWith('@@') &&
            !enKeysAfter.contains(bare(k))));

    final head = <String, dynamic>{};
    final tail = <String, dynamic>{};
    arb.forEach((k, v) {
      final bare = k.startsWith('@') && !k.startsWith('@@') ? k.substring(1) : k;
      (bare.startsWith('legacy_') ? tail : head)[k] = v;
    });
    final result = <String, dynamic>{...head};
    out.forEach((key, v) {
      result[key] = code == 'uk' ? normalizeUkApostrophes(v[code]!) : v[code];
      if (code == 'en') {
        final m = Map<String, dynamic>.of(meta[key]!);
        // A placeholder that is a plural in any language is an int.
        final plurals = {
          for (final text in v.values)
            for (final a in icuArgs(text))
              if (a.kind == 'plural') a.name,
        };
        final ph = <String, dynamic>{};
        for (final a in icuArgs(v['en']!)) {
          ph[a.name] = {
            'type': plurals.contains(a.name) || _intNames.contains(a.name)
                ? 'int'
                : 'String'
          };
        }
        if (ph.isNotEmpty) m['placeholders'] = ph;
        result['@$key'] = m;
      } else if (review[key]?.contains(code) ?? false) {
        result['@$key'] = {'x-needs-review': true};
      }
    });
    result.addAll(tail);
    if (code == 'en') {
      enKeysAfter = result.keys
          .where((k) => !k.startsWith('@'))
          .toSet();
    }
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  }
}

/// Placeholder names that are always counts.
const _intNames = {'count', 'n', 'minutes', 'seats', 'rides', 'days', 'hours'};
