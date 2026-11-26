import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every row of design-pack/l10n/copy_deck.csv is an ARB key, merged into one,
/// or skipped with a reason in tool/l10n/copy_deck_map.txt. When the deck
/// changes, this fails until the new rows are decided. Skipped when the design
/// pack isn't checked out next to the app (CI).
void main() {
  final deck = File('../design-pack/l10n/copy_deck.csv');
  test('every copy deck row has a decision', () async {
    final r = await Process.run(
      'dart',
      ['run', 'tool/l10n/import_copy_deck.dart', '--report'],
      runInShell: true,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect('${r.stderr}', contains('0 rows need a decision'),
        reason: 'add lines to tool/l10n/copy_deck_map.txt:\n${r.stdout}');
  }, skip: deck.existsSync() ? false : 'design-pack not checked out');
}
