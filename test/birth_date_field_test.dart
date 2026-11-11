import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/app_localizations.dart';
import 'package:sameway/features/legal/birth_date_field.dart';

void main() {
  test('latest allowed birth date is exactly 18 years ago', () {
    expect(latestAllowedBirthDate(DateTime(2026, 11, 10)), DateTime(2008, 11, 10));
    // 29 Feb today → 29 Feb 18 years ago rolls to 1 Mar in a non-leap year.
    expect(latestAllowedBirthDate(DateTime(2028, 2, 29)), DateTime(2010, 3, 1));
  });

  test('formats as YYYY-MM-DD', () {
    expect(formatBirthDate(DateTime(1990, 1, 5)), '1990-01-05');
  });

  testWidgets('picker cannot select someone under 18', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(
        body: BirthDateField(value: null, onChanged: (_) {}, showError: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Enter your date of birth — Sameway is for people aged 18 or older'),
        findsOneWidget);

    await tester.tap(find.byIcon(Icons.cake_outlined));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, latestAllowedBirthDate(DateTime.now()));
  });
}
