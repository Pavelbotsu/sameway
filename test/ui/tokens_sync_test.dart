import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every colour in `SwColors` must also be in the design pack's
/// `design/tokens.json`, so the code and the tokens can't drift apart.
///
/// The design pack is a sibling repo (`../design-pack`). When it isn't
/// checked out next to the app (CI), the test is skipped.
void main() {
  const tokensPath = '../design-pack/design/tokens.json';
  const colorsPath = 'lib/theme/sw_colors.dart';
  final tokensFile = File(tokensPath);

  test('every SwColors value is in tokens.json', () {
    final source = File(colorsPath).readAsStringSync();
    final code = {
      for (final m in RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)').allMatches(source))
        m.group(1)!.toUpperCase(),
    };
    expect(code, isNotEmpty, reason: 'No colours found in $colorsPath');

    final tokens = <String>{};
    void collect(Object? node) {
      if (node is String) {
        final argb = _hexToArgb(node);
        if (argb != null) tokens.add(argb);
      } else if (node is Map) {
        node.values.forEach(collect);
      } else if (node is List) {
        node.forEach(collect);
      }
    }

    final json = jsonDecode(tokensFile.readAsStringSync()) as Map<String, dynamic>;
    collect(json['color']);

    final missing = code.difference(tokens).map((c) => '0x$c').toList()..sort();
    expect(missing, isEmpty, reason: 'In SwColors but not in $tokensPath: $missing');
  }, skip: tokensFile.existsSync() ? false : '$tokensPath not checked out');
}

/// "#RRGGBB" or "#RRGGBBAA" (CSS order) → "AARRGGBB" (Flutter order).
String? _hexToArgb(String s) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$').firstMatch(s.trim());
  if (m == null) return null;
  return '${(m.group(2) ?? 'FF').toUpperCase()}${m.group(1)!.toUpperCase()}';
}
