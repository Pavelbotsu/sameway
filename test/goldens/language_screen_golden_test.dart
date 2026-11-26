@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sameway/core/language_provider.dart';
import 'package:sameway/features/account/language_screen.dart';
import 'package:sameway/l10n/l10n.dart';
import 'package:sameway/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// PR_Language at 390×844: both roles, EN and UK, 1× and 2× text scale.
/// "Use device language" is selected (device = the shown language).
void main() {
  for (final role in SwRole.values) {
    for (final lang in const ['en', 'uk']) {
      for (final scale in const [1.0, 2.0]) {
        final file =
            'language_screen/${role.name}_${lang}_${scale.toInt()}x.png';
        testWidgets(file, (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = goldenSize;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final provider = LanguageProvider(deviceLocale: Locale(lang));
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: SwTheme.build(role),
              locale: Locale(lang),
              supportedLocales: L10n.supportedLocales,
              localizationsDelegates: const [
                L10nFallbackDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const LanguageScreen(),
            ),
          ));
          await tester.pumpAndSettle();
          expectNoTextBelow13(tester);
          await expectLater(
              find.byType(LanguageScreen), matchesGoldenFile(file));
        });
      }
    }
  }
}
