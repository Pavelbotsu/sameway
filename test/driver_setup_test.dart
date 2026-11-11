import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/app_localizations.dart';
import 'package:sameway/features/driver/driver_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  test('maps backend codes to setup steps', () {
    expect(driverSetupNeedFor(const ApiException('x', statusCode: 403, code: 'driver_declaration_required')),
        DriverSetupNeed.declaration);
    expect(driverSetupNeedFor(const ApiException('x', statusCode: 400, code: 'car_details_required')),
        DriverSetupNeed.carDetails);
    expect(driverSetupNeedFor(const ApiException('x', statusCode: 400)), isNull);
    expect(driverSetupNeedFor(Exception('x')), isNull);
  });

  testWidgets('declaration needs all four boxes, then records it', (tester) async {
    final posted = <Map<String, dynamic>>[];
    bool? popped;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Builder(builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const DriverDeclarationSheet(),
                );
              },
              child: const Text('open'),
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm all four to drive with Sameway'), findsOneWidget);
      expect(posted, isEmpty);

      for (final box in find.byType(Checkbox).evaluate().toList()) {
        await tester.tap(find.byWidget(box.widget));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      // The request is real async (token storage + mocked HTTP).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          posted.add(jsonDecode(req.body) as Map<String, dynamic>);
          expect(req.url.path, '/auth/driver-declaration');
          return http.Response('{"ok":true}', 200);
        }));

    expect(posted.single, {
      'licence': true, 'insurance': true, 'roadworthy': true, 'cost_sharing': true,
    });
    expect(popped, isTrue);
  });
}
