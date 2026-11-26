import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No user-visible string literals in widgets: every word comes from ARB
/// (lib/l10n). A literal that must stay (brand name, map attribution) carries
/// `// l10n-ignore: <reason>` on its line or the line above; a file that never
/// reaches users (dev-only screen, feature behind a flag that is off and
/// deleted in a later phase) starts with `// l10n-ignore-file: <reason>`.
///
/// Heuristic, not a parser: it looks for string literals with letters passed
/// to Text(...), TextSpan(text: ...) and the usual label/title/hint/tooltip
/// parameters. Interpolations are ignored ('$name' has no letters of its own).

const _roots = ['lib/features', 'lib/ui', 'lib/core/widgets'];
const _files = [
  'lib/core/fcm_service.dart',
  'lib/core/location_service.dart',
  'lib/main.dart',
];

final _contexts = RegExp(
  r'\b(?:Text|SelectableText|Tooltip)\(\s*'
  r'|\bTextSpan\([^)]*?\btext:\s*'
  r'|\b(?:hintText|labelText|helperText|errorText|counterText|prefixText|suffixText'
  r'|tooltip|semanticLabel|semanticsLabel|label|title|subtitle|message|content'
  r'|actionLabel|retryLabel|channelName|channelDescription|notificationTitle'
  r'|notificationText|description|placeholder)\s*:\s*',
);

/// The literal (and an optional `cond ? 'a' : 'b'` partner) right after a
/// context.
final _literal = RegExp(
    r"""^(?:[\w.!]+\s*\?\s*)?(r?)('{3}|"{3}|'|")((?:\\.|(?!\2).)*?)\2""",
    dotAll: true);

final _letters = RegExp(r'[A-Za-zÀ-žЀ-ӿ]');
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

List<String> _violations(File f) {
  final src = f.readAsStringSync();
  // Whole files that never reach users (dev-only, behind a flag that is off
  // everywhere and deleted in a later phase).
  if (src.contains('// l10n-ignore-file:')) return const [];
  final lines = src.split('\n');
  final out = <String>[];
  for (final m in _contexts.allMatches(src)) {
    final rest = src.substring(m.end);
    final lit = _literal.firstMatch(rest);
    if (lit == null) continue;
    final body = lit.group(3)!.replaceAll(_interpolation, '');
    if (!_letters.hasMatch(body)) continue;
    final line = '\n'.allMatches(src.substring(0, m.start)).length;
    bool ignored(int i) =>
        i >= 0 && i < lines.length && lines[i].contains('// l10n-ignore:');
    if (ignored(line) || ignored(line - 1) || ignored(line + 1)) continue;
    out.add('${f.path}:${line + 1}: ${lines[line].trim()}');
  }
  return out;
}

void main() {
  test('no hard-coded user-visible strings', () {
    final files = <File>[
      for (final r in _roots)
        ...Directory(r)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      for (final p in _files) File(p),
    ];
    final violations = [for (final f in files) ..._violations(f)];
    expect(violations, isEmpty,
        reason: 'Move these to lib/l10n/app_*.arb (or mark them '
            '"// l10n-ignore: <reason>"):\n${violations.join('\n')}');
  });

  test('l10n-ignore markers give a reason', () {
    // "// l10n-ignore" or "// l10n-ignore-file" with no reason after a colon.
    final bare = RegExp(
        r'//\s*l10n-ignore(?:-file)?(?:\s|$)|//\s*l10n-ignore(?:-file)?:\s*$');
    final bad = <String>[];
    for (final r in ['lib']) {
      for (final f in Directory(r)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (bare.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
