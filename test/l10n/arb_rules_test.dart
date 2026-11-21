import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n/icu.dart';

/// Copy rules from docs/04_I18N.md and the root CLAUDE.md, checked on the ARB
/// files themselves.
Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };

/// Placeholders that hold a person's name (or a list of names).
bool _isNamePlaceholder(String p) =>
    p == 'name' ||
    p == 'names' ||
    p.endsWith('Name') ||
    const {'first', 'second', 'newDriver', 'oldDriver', 'passengers'}
        .contains(p);

/// Latin spellings of cities that UK must write in Cyrillic (Краків, Ряшів…).
const _latinCities = [
  'Kraków', 'Krakow', 'Rzeszów', 'Rzeszow', 'Tarnów', 'Dębica', 'Bochnia',
  'Warszawa', 'Wrocław', 'Katowice', 'Zakopane', 'Przemyśl', 'Gdańsk',
  'Poznań', 'Łódź', 'Lublin', 'Poltava',
];

/// Point-of-interest names that contain a city and stay as written.
const _poiAllowlist = ['Galeria Rzeszów', 'Galeria Krakowska'];

const _cyr = 'а-яА-ЯіІїЇєЄґҐʼ’';
final _formalPronoun = RegExp(
    '(?<![$_cyr])(Ви|Вас|Вам|Вами|Ваш|Ваша|Ваше|Ваші|Вашого|Вашої|Вашим|'
    'Вашій|Ваших|Вашу|ви|вас|вам|вами|ваш|ваша|ваше|ваші|вашого|вашої|'
    'вашим|вашій|ваших|вашу)(?![$_cyr])');
final _formalImperative =
    RegExp('[$_cyr]+(іть|йте|ьте|іться|йтеся|ьтеся)(?![$_cyr])');

/// Words that end like a formal imperative but are not one.
const _imperativeAllowlist = {'навіть'};

void main() {
  final en = _arb('en'), uk = _arb('uk'), pl = _arb('pl');
  final enM = _messages(en), ukM = _messages(uk), plM = _messages(pl);

  test('same keys in en, uk and pl', () {
    expect(ukM.keys.toSet().difference(enM.keys.toSet()), isEmpty,
        reason: 'keys only in uk');
    expect(enM.keys.toSet().difference(ukM.keys.toSet()), isEmpty,
        reason: 'keys missing in uk');
    expect(enM.keys.toSet().difference(plM.keys.toSet()), isEmpty,
        reason: 'keys missing in pl');
    expect(plM.keys.toSet().difference(enM.keys.toSet()), isEmpty,
        reason: 'keys only in pl');
  });

  test('uk and pl only use placeholders the English message declares', () {
    final bad = <String>[];
    for (final key in enM.keys) {
      final declared = icuArgs(enM[key]!).map((a) => a.name).toSet();
      for (final (code, m) in [('uk', ukM), ('pl', plM)]) {
        final used = icuArgs(m[key] ?? '').map((a) => a.name).toSet();
        final extra = used.difference(declared);
        if (extra.isNotEmpty) bad.add('$code $key: $extra');
      }
    }
    expect(bad, isEmpty);
  });

  test('plurals have all forms (uk/pl: one, few, many, other)', () {
    final bad = <String>[];
    for (final (code, m) in [('en', enM), ('uk', ukM), ('pl', plM)]) {
      m.forEach((key, text) {
        for (final a in icuArgs(text).where((a) => a.kind == 'plural')) {
          final forms = a.branches.keys.toSet();
          final need = code == 'en' ? {'other'} : {'one', 'few', 'many', 'other'};
          final missing = need.difference(forms);
          if (code == 'en' && !forms.contains('one') && !forms.contains('=1')) {
            missing.add('one|=1');
          }
          if (missing.isNotEmpty) bad.add('$code $key ${a.name}: $missing');
        }
      });
    }
    expect(bad, isEmpty);
  });

  test('uk and pl never decline a name: "Label: {name}" or "{name}: …"', () {
    final bad = <String>[];
    for (final (code, m) in [('uk', ukM), ('pl', plM)]) {
      m.forEach((key, text) {
        final s = icuSkeleton(text);
        for (final match in RegExp(r'\{(\w+)\}').allMatches(s)) {
          if (!_isNamePlaceholder(match.group(1)!)) continue;
          final before = s.substring(0, match.start);
          final after = s.substring(match.end);
          final okBefore = before.isEmpty && after.isEmpty ||
              RegExp(r'(: |· |\(|, |\n)$').hasMatch(before);
          final okAfter = RegExp(r'^(:|,| ·|\)|$)').hasMatch(after) &&
              (before.isEmpty || RegExp(r'(: |· |\(|, )$').hasMatch(before) ||
                  RegExp(r'^(:|,| ·|\))').hasMatch(after));
          if (!okBefore && !okAfter) bad.add('$code $key: $text');
        }
      });
    }
    expect(bad, isEmpty);
  });

  test('uk uses informal «ти»', () {
    // The copy deck's UK is written natively and already uses «ти"; its «ви»
    // means "you two" (rider and driver), so the pronoun check covers the old
    // app strings and hand-written keys. Formal imperatives are checked
    // everywhere.
    bool fromDeck(String key) =>
        (en['@$key'] as Map?)?.containsKey('x-deck') ?? false;
    final bad = <String>[];
    ukM.forEach((key, text) {
      final s = icuSkeleton(text);
      final p = fromDeck(key) ? null : _formalPronoun.firstMatch(s);
      if (p != null) bad.add('$key: «${p.group(0)}» in $text');
      for (final m in _formalImperative.allMatches(s)) {
        if (_imperativeAllowlist.contains(m.group(0)!.toLowerCase())) continue;
        bad.add('$key: «${m.group(0)}» in $text');
      }
    });
    expect(bad, isEmpty);
  });

  test('uk writes city names in Cyrillic, not streets', () {
    final bad = <String>[];
    ukM.forEach((key, text) {
      var s = text;
      for (final poi in _poiAllowlist) {
        s = s.replaceAll(poi, '');
      }
      for (final city in _latinCities) {
        if (s.contains(city)) bad.add('$key: $city in $text');
      }
      if (s.contains('вул.')) bad.add('$key: street name translated: $text');
    });
    expect(bad, isEmpty);
  });

  test('uk uses one apostrophe (’), never a straight one', () {
    final bad = [
      for (final e in ukM.entries)
        if (e.value.contains("'") || e.value.contains('ʼ')) e.key,
    ];
    expect(bad, isEmpty);
  });

  test('needs-review markers are well-formed', () {
    final bad = <String>[];
    for (final (code, arb) in [('uk', uk), ('pl', pl)]) {
      arb.forEach((k, v) {
        if (!k.startsWith('@') || k.startsWith('@@')) return;
        if (!arb.containsKey(k.substring(1))) bad.add('$code $k: no message');
        if (v is! Map || v['x-needs-review'] != true || v.length != 1) {
          bad.add('$code $k: expected {"x-needs-review": true}');
        }
      });
    }
    expect(bad, isEmpty);
  });

  test('no text below the language list: en/uk/pl only', () {
    final files = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(files, {'app_en.arb', 'app_uk.arb', 'app_pl.arb'});
  });
}
