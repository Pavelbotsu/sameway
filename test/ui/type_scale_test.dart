import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';

/// v3: no text below 13 px; no hex colours in widgets.
/// Scope is lib/theme + lib/ui for now; Phase 23 widens it to all of lib/.
void main() {
  test('every SwTheme text style is ≥ 13 px', () {
    for (final role in SwRole.values) {
      final t = SwTheme.build(role).textTheme;
      final styles = {
        'displayLarge': t.displayLarge, 'displayMedium': t.displayMedium, 'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge, 'headlineMedium': t.headlineMedium, 'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge, 'titleMedium': t.titleMedium, 'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge, 'bodyMedium': t.bodyMedium, 'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge, 'labelMedium': t.labelMedium, 'labelSmall': t.labelSmall,
      };
      for (final e in styles.entries) {
        expect(e.value?.fontSize, greaterThanOrEqualTo(SwType.minSize), reason: '${role.name} ${e.key}');
      }
    }
  });

  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('no fontSize below 13 in lib/theme and lib/ui', () {
    final re = RegExp(r'fontSize:\s*\(?\s*(\d+(?:\.\d+)?)');
    final bad = <String>[];
    for (final f in [...dartFiles('lib/theme'), ...dartFiles('lib/ui')]) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in re.allMatches(lines[i])) {
          if (double.parse(m.group(1)!) < SwType.minSize) bad.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('no hex colours or raw Material colours in lib/ui', () {
    final hex = RegExp(r'Color\(\s*0x');
    final material = RegExp(r'\bColors\.(?!transparent\b)\w+');
    final bad = <String>[];
    for (final f in dartFiles('lib/ui')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (hex.hasMatch(lines[i]) || material.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty);
  });

  test('no hard-coded colours outside SwColors in lib/theme', () {
    final hex = RegExp(r'Color\(\s*0x');
    final bad = <String>[];
    for (final f in dartFiles('lib/theme')) {
      if (f.path.endsWith('sw_colors.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (hex.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });
}
