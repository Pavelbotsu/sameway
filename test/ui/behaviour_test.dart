import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';
import 'package:sameway/ui/ui.dart';

import 'ui_test_app.dart';

void main() {
  group('SwLaterButton', () {
    testWidgets('says when, then enables itself at availableAt', (tester) async {
      var now = DateTime(2026, 11, 20, 9, 4, 30);
      var pressed = 0;
      await pumpSw(
        tester,
        SwLaterButton(
          label: 'Leave without Olena',
          availableAt: DateTime(2026, 11, 20, 9, 10),
          now: () => now,
          availableText: (_, m) => 'Available at 09:10 · in $m min',
          onPressed: () => pressed++,
        ),
      );
      expect(find.text('Available at 09:10 · in 6 min'), findsOneWidget); // 5.5 min rounds up
      await tester.tap(find.text('Leave without Olena'));
      expect(pressed, 0);

      now = DateTime(2026, 11, 20, 9, 9, 50);
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Available at 09:10 · in 1 min'), findsOneWidget);

      now = DateTime(2026, 11, 20, 9, 10);
      await tester.pump(const Duration(seconds: 15));
      expect(find.textContaining('Available at'), findsNothing);
      await tester.tap(find.text('Leave without Olena'));
      expect(pressed, 1);
    });
  });

  testWidgets('disabled primary button shows its reason', (tester) async {
    await pumpSw(tester, const SwPrimaryButton(label: 'Start sharing route', onPressed: null, disabledReason: 'Add a destination first'));
    expect(find.text('Add a destination first'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('SwStepper stays within min and max', (tester) async {
    var v = 1;
    await tester.pumpWidget(MaterialApp(
      theme: SwTheme.build(SwRole.driver),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => SwStepper(
            value: v, min: 1, max: 3,
            onChanged: (n) => set(() => v = n),
            decreaseLabel: 'Fewer seats', increaseLabel: 'More seats',
          ),
        ),
      ),
    ));
    await tester.tap(find.bySemanticsLabel('Fewer seats'));
    expect(v, 1);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.bySemanticsLabel('More seats'));
      await tester.pump();
    }
    expect(v, 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('SwSegmented, SwChip and SwToggle report taps', (tester) async {
    int? seg;
    var chip = 0;
    bool? toggled;
    await pumpSw(
      tester,
      Column(children: [
        SwSegmented<String>(
          segments: const [SwSegment('instant', 'Instant booking'), SwSegment('ask', 'Ask me')],
          selected: 'instant',
          onChanged: (s) => seg = s == 'ask' ? 1 : 0,
        ),
        SwChip(label: '4 min', selected: false, onTap: () => chip++),
        SwToggle(value: false, onChanged: (v) => toggled = v, semanticLabel: 'Auto-accept'),
      ]),
    );
    await tester.tap(find.text('Ask me'));
    await tester.tap(find.text('4 min'));
    await tester.tap(find.bySemanticsLabel('Auto-accept'));
    expect(seg, 1);
    expect(chip, 1);
    expect(toggled, isTrue);
  });

  testWidgets('SwPriceScale steps by 1 and clamps', (tester) async {
    final handle = tester.ensureSemantics();
    var v = 20;
    await tester.pumpWidget(MaterialApp(
      theme: SwTheme.build(SwRole.driver),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => SwPriceScale(
            value: v, min: 8, max: 21,
            onChanged: (n) => set(() => v = n),
            format: (n) => '$n zł',
            semanticLabel: 'Price per seat',
          ),
        ),
      ),
    ));
    final owner = tester.renderObject(find.byType(SwPriceScale)).owner!.semanticsOwner!;
    int id() => tester.getSemantics(find.bySemanticsLabel('Price per seat')).id;

    owner.performAction(id(), SemanticsAction.increase);
    await tester.pump();
    expect(v, 21);
    expect(tester.getSemantics(find.bySemanticsLabel('Price per seat')).getSemanticsData().hasAction(SemanticsAction.increase), isFalse);

    owner.performAction(id(), SemanticsAction.decrease);
    await tester.pump();
    expect(v, 20);

    // Tapping the left end of the scale goes to the minimum.
    final scale = tester.getRect(find.byType(GestureDetector).first);
    await tester.tapAt(scale.centerLeft + const Offset(1, 0));
    await tester.pump();
    expect(v, 8);
    handle.dispose();
  });

  testWidgets('SwPickupCode reads the digits one by one', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSw(tester, const SwPickupCode(title: 'Your pickup code', code: '4827'));
    expect(find.bySemanticsLabel('Your pickup code: 4 8 2 7'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('SwTextField shows the error under the field', (tester) async {
    await pumpSw(tester, const SwTextField(label: 'Email', errorText: 'Enter a full email'));
    final field = tester.getRect(find.byType(TextField));
    final error = tester.getRect(find.text('Enter a full email'));
    expect(error.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(error.left, field.left);
  });

  testWidgets('showSwSnackBar runs the action and closes', (tester) async {
    var undone = 0;
    await tester.pumpWidget(MaterialApp(
      theme: SwTheme.build(SwRole.driver),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSwSnackBar(context, message: 'Route ended', actionLabel: 'Undo', onAction: () => undone++),
            child: const Text('end'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('end'));
    await tester.pumpAndSettle();
    expect(find.text('Route ended'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Route ended'), findsNothing);
  });

  testWidgets('context.role follows the theme and falls back to passenger', (tester) async {
    late RoleColors inTheme, outside;
    await tester.pumpWidget(MaterialApp(
      theme: SwTheme.build(SwRole.driver),
      home: Builder(builder: (c) {
        inTheme = c.role;
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        outside = c.role;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle(); // MaterialApp animates theme changes
    expect(inTheme.role, SwRole.driver);
    expect(outside.role, SwRole.passenger);
  });
}
