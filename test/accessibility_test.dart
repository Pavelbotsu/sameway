import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/app_localizations.dart';
import 'package:sameway/core/app_theme.dart';
import 'package:sameway/core/widgets/sos_button.dart';
import 'package:sameway/features/driver/driver_setup.dart';
import 'package:sameway/features/legal/birth_date_field.dart';
import 'package:sameway/features/legal/legal_consent_checks.dart';

/// Flutter's accessibility guidelines (WCAG contrast, 48 dp tap targets,
/// labelled tap targets) on the safety- and consent-critical widgets.
Future<void> expectAccessible(WidgetTester tester, Widget child) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: const [AppLocalizations.delegate],
    home: Scaffold(body: Center(child: SingleChildScrollView(child: child))),
  ));
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void main() {
  testWidgets('SOS button', (tester) async {
    await expectAccessible(tester, const SosButton(lat: 50, lng: 20));
  });

  testWidgets('SOS sheet', (tester) async {
    await expectAccessible(tester, const SosSheet(lat: 50, lng: 20));
  });

  testWidgets('consent checkboxes', (tester) async {
    await expectAccessible(
      tester,
      LegalConsentChecks(
        ageConfirmed: false,
        termsAccepted: false,
        onAgeChanged: (_) {},
        onTermsChanged: (_) {},
      ),
    );
  });

  testWidgets('date of birth field', (tester) async {
    await expectAccessible(
        tester, BirthDateField(value: null, onChanged: (_) {}));
  });

  testWidgets('driver declaration sheet', (tester) async {
    await expectAccessible(tester, const DriverDeclarationSheet());
  });
}
