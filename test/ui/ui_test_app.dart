import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';

/// Pumps [child] in a v3 theme for [role] on a scrollable black page.
Future<void> pumpSw(WidgetTester tester, Widget child, {SwRole role = SwRole.passenger}) async {
  await tester.pumpWidget(MaterialApp(
    theme: SwTheme.build(role),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    ),
  ));
  await tester.pump();
}
