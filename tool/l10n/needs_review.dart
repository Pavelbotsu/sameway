// Lists every uk/pl string marked "x-needs-review" as Markdown, for the PR
// description (decision 28: the product owner reviews UK and PL).
//
//   dart run tool/l10n/needs_review.dart            # both languages
//   dart run tool/l10n/needs_review.dart uk         # one language
//   dart run tool/l10n/needs_review.dart --count    # totals only
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

String _cell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', '<br>');

void main(List<String> args) {
  final countOnly = args.contains('--count');
  final langs = args.where((a) => !a.startsWith('--')).toList();
  final en = _arb('en');
  for (final code in langs.isEmpty ? ['uk', 'pl'] : langs) {
    final arb = _arb(code);
    final keys = [
      for (final k in arb.keys)
        if (k.startsWith('@') &&
            !k.startsWith('@@') &&
            (arb[k] as Map)['x-needs-review'] == true)
          k.substring(1),
    ];
    if (countOnly) {
      stdout.writeln('$code: ${keys.length}');
      continue;
    }
    stdout
      ..writeln('### ${code.toUpperCase()} — ${keys.length} strings to review')
      ..writeln()
      ..writeln('| Key | English | ${code.toUpperCase()} |')
      ..writeln('|---|---|---|');
    for (final k in keys) {
      stdout.writeln(
          '| `$k` | ${_cell('${en[k]}')} | ${_cell('${arb[k]}')} |');
    }
    stdout.writeln();
  }
}
