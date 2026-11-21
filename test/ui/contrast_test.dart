import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const surfaces = {
    'background': SwColors.background,
    'surface1': SwColors.surface1,
    'surface2': SwColors.surface2,
    'surface3': SwColors.surface3,
  };

  group('field border (WCAG 1.4.11, ≥ 3:1 on every surface)', () {
    for (final s in surfaces.entries) {
      test('on ${s.key}', () {
        final ratio = contrast(SwColors.fieldBorder, s.value);
        expect(ratio, greaterThanOrEqualTo(3), reason: 'fieldBorder on ${s.key}: ${ratio.toStringAsFixed(2)}');
      });
    }
  });

  group('text ≥ 4.5:1', () {
    void pair(String name, Color fg, Color bg) =>
        test(name, () => expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name: ${contrast(fg, bg).toStringAsFixed(2)}'));

    for (final s in surfaces.entries) {
      pair('text on ${s.key}', SwColors.text, s.value);
      pair('secondary on ${s.key}', SwColors.textSecondary, s.value);
      pair('tertiary on ${s.key}', SwColors.textTertiary, s.value);
      pair('warning on ${s.key}', SwColors.warning, s.value);
      pair('danger on ${s.key}', SwColors.danger, s.value);
    }

    for (final role in [RoleColors.driver, RoleColors.passenger]) {
      final r = role.role.name;
      pair('onAccent on $r fill', SwColors.onAccent, role.fill);
      pair('$r onLight on snackbar', role.onLight, SwColors.snackbar);
      pair('$r onDark on its tint', role.onDark, role.tint);
      pair('text on $r tint', SwColors.text, role.tint);
      for (final s in surfaces.entries) {
        pair('$r onDark on ${s.key}', role.onDark, s.value);
      }
    }

    pair('onAccent on danger fill', SwColors.onAccent, SwColors.danger);
    pair('onAccent on snackbar', SwColors.onAccent, SwColors.snackbar);
    pair('warning on warningTint', SwColors.warning, SwColors.warningTint);
    pair('text on warningTint', SwColors.text, SwColors.warningTint);
    pair('danger on dangerTint', SwColors.danger, SwColors.dangerTint);
    pair('text on dangerTint', SwColors.text, SwColors.dangerTint);
    pair('eco on ecoTint', SwColors.eco, SwColors.ecoTint);
    for (final f in SwColors.avatarFills) {
      pair('text on avatar fill ${f.toARGB32().toRadixString(16)}', SwColors.text, f);
    }
  });
}
