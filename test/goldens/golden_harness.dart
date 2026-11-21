import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';

import 'sample_text.dart';

/// Phone frame for component goldens (CLAUDE.md: 390×844).
const goldenSize = Size(390, 844);

typedef GoldenBuilder = Widget Function(BuildContext context, SampleText s, SwRole role);

/// Renders [build] for every role × {en, uk} × {1×, 2×} text scale and
/// compares it with `<name>/<role>_<lang>_<scale>x.png`. Fails on layout
/// overflow and on any text below 13 px.
void swGoldenMatrix(String name, GoldenBuilder build) {
  group(name, () {
    for (final role in SwRole.values) {
      for (final lang in const ['en', 'uk']) {
        for (final scale in const [1.0, 2.0]) {
          final file = '$name/${role.name}_${lang}_${scale.toInt()}x.png';
          testWidgets(file, (tester) async {
            await pumpSwFrame(tester, role: role, lang: lang, scale: scale,
                child: Builder(builder: (c) => build(c, SampleText(lang), role)));
            expectNoTextBelow13(tester);
            await expectLater(find.byKey(_frameKey), matchesGoldenFile(file));
          });
        }
      }
    }
  });
}

const _frameKey = ValueKey('sw-golden-frame');

Future<void> pumpSwFrame(
  WidgetTester tester, {
  required SwRole role,
  required String lang,
  required double scale,
  required Widget child,
}) async {
  tester.view.physicalSize = goldenSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: SwTheme.build(role),
    locale: Locale(lang),
    supportedLocales: const [Locale('en'), Locale('uk')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: RepaintBoundary(
        key: _frameKey,
        child: ColoredBox(
          color: SwColors.background,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(SwSpace.screen),
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// v3: 13 px is the minimum anywhere (before the user's text scaling).
void expectNoTextBelow13(WidgetTester tester) {
  final tooSmall = <String>[];
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    void check(InlineSpan span, double? inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is TextSpan) {
        if ((span.text?.trim().isNotEmpty ?? false) && (size == null || size < SwType.minSize)) {
          tooSmall.add('"${span.text}" at ${size ?? 'default'} px');
        }
        for (final c in span.children ?? const <InlineSpan>[]) {
          check(c, size);
        }
      }
    }

    check(p.text, null);
  }
  expect(tooSmall, isEmpty, reason: 'Text below 13 px: $tooSmall');
}
