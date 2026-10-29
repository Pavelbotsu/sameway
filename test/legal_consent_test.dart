import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/app_localizations.dart';
import 'package:sameway/features/auth/auth_repository.dart';
import 'package:sameway/features/legal/legal_consent_checks.dart';
import 'package:sameway/features/legal/terms_gate_screen.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

/// Controlled-widget harness: owns the two flags like AuthScreen does.
class _Harness extends StatefulWidget {
  final bool showError;
  const _Harness({this.showError = false});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool age = false;
  bool terms = false;
  @override
  Widget build(BuildContext context) => LegalConsentChecks(
        ageConfirmed: age,
        termsAccepted: terms,
        onAgeChanged: (v) => setState(() => age = v),
        onTermsChanged: (v) => setState(() => terms = v),
        showError: widget.showError,
      );
}

void main() {
  group('LegalConsentChecks', () {
    testWidgets('both boxes start unchecked (consent must be explicit)',
        (tester) async {
      await tester.pumpWidget(_host(const _Harness()));
      await tester.pumpAndSettle();
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes.length, 2);
      expect(boxes.every((b) => b.value == false), isTrue);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('tapping a label toggles its box', (tester) async {
      await tester.pumpWidget(_host(const _Harness()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I confirm I am 18 or older'));
      await tester.pump();
      final state = tester.state<_HarnessState>(find.byType(_Harness));
      expect(state.age, isTrue);
      expect(state.terms, isFalse);
    });

    testWidgets('error shows until both are checked', (tester) async {
      await tester.pumpWidget(_host(const _Harness(showError: true)));
      await tester.pumpAndSettle();
      const msg = 'Confirm you are 18 or older and accept the terms to continue';
      expect(find.text(msg), findsOneWidget);

      await tester.tap(find.text('I confirm I am 18 or older'));
      await tester.pump();
      expect(find.text(msg), findsOneWidget, reason: 'one box is not enough');

      await tester.tap(
          find.text('I accept the Terms of Service and the Privacy Policy'));
      await tester.pump();
      expect(find.text(msg), findsNothing);
    });
  });

  group('TermsGateScreen.destination', () {
    test('routes to the gate only when consent is owed', () {
      expect(
        TermsGateScreen.destination(role: 'driver', needsConsent: true),
        isA<TermsGateScreen>(),
      );
      expect(
        TermsGateScreen.destination(role: 'passenger', needsConsent: false),
        isNot(isA<TermsGateScreen>()),
      );
    });
  });

  group('AuthResult.needsConsent', () {
    Map<String, dynamic> base() =>
        {'token': 't', 'user_id': 'u', 'role': 'passenger'};

    test('reads the server flag', () {
      expect(
          AuthResult.fromJson({...base(), 'needs_consent': true}).needsConsent,
          isTrue);
    });

    test('defaults to false when an older backend omits it', () {
      expect(AuthResult.fromJson(base()).needsConsent, isFalse);
    });
  });
}
