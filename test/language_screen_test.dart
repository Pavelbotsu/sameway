import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sameway/core/language_provider.dart';
import 'package:sameway/features/account/language_screen.dart';
import 'package:sameway/l10n/l10n.dart';
import 'package:sameway/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LanguageProvider> _pump(WidgetTester tester,
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final provider = LanguageProvider(deviceLocale: const Locale('uk', 'UA'));
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: provider,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: SwTheme.build(SwRole.passenger),
        locale: context.watch<LanguageProvider>().locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10nFallbackDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LanguageScreen(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return provider;
}

/// The row containing [text] is announced as a radio that is [checked].
void _expectRadio(WidgetTester tester, String text, {required bool checked}) {
  expect(
    tester.getSemantics(find.text(text)),
    containsSemantics(
      hasCheckedState: true,
      isChecked: checked,
      isInMutuallyExclusiveGroup: true,
      hasTapAction: true,
    ),
  );
}

void main() {
  testWidgets('device language first, then en/pl/uk by their own names',
      (tester) async {
    await _pump(tester);
    // Device is Ukrainian and nothing is chosen: UI in Ukrainian.
    expect(find.text('Мова'), findsOneWidget);
    expect(find.text('Системна'), findsOneWidget);
    expect(find.text('Зараз: українська'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Polski'), findsOneWidget);
    expect(find.text('Українська'), findsOneWidget);
    expect(find.text('польська'), findsOneWidget);
    // Dropped languages are gone.
    expect(find.text('Deutsch'), findsNothing);
    _expectRadio(tester, 'Системна', checked: true);
    _expectRadio(tester, 'Polski', checked: false);
  });

  testWidgets('picking a language saves it and switches the app',
      (tester) async {
    final p = await _pump(tester);
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();
    expect(p.chosen, const Locale('pl'));
    expect((await SharedPreferences.getInstance()).getString('app_lang'), 'pl');
    expect(find.text('Język'), findsOneWidget);
    _expectRadio(tester, 'Polski', checked: true);
    _expectRadio(tester, 'Język urządzenia', checked: false);

    await tester.tap(find.text('Język urządzenia'));
    await tester.pumpAndSettle();
    expect(p.usesDeviceLanguage, isTrue);
    expect(find.text('Мова'), findsOneWidget);
  });

  testWidgets('rows are big enough to tap and the back button has a label',
      (tester) async {
    await _pump(tester, prefs: {'app_lang': 'en'});
    for (final t in ['Use device language', 'English', 'Polski', 'Українська']) {
      final row = find.ancestor(of: find.text(t), matching: find.byType(InkWell));
      expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48));
    }
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Currently Ukrainian'), findsOneWidget);
  });
}
