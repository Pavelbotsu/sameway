import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';
import 'package:sameway/ui/ui.dart';

import 'ui_test_app.dart';

/// Flutter's accessibility guidelines on every v3 component, both roles:
/// 48 dp tap targets, labelled tap targets, text contrast.
void main() {
  final components = <String, Widget Function()>{
    'buttons': () => Column(children: [
          SwPrimaryButton(label: 'Book seat · 16 zł', onPressed: () {}),
          SwSecondaryButton(label: 'Keep browsing', onPressed: () {}),
          SwDangerButton(label: 'Cancel seat', onPressed: () {}),
          SwDangerButton(label: 'Cancel seat', onPressed: () {}, filled: true),
          SwLaterButton(
            label: 'Leave without Olena',
            availableAt: DateTime(2026, 1, 1, 9, 10),
            now: () => DateTime(2026, 1, 1, 9, 4),
            availableText: (_, m) => 'Available at 09:10 · in $m min',
            onPressed: () {},
          ),
        ]),
    'fields': () => const Column(children: [
          SwSearchField(hint: 'Where to?'),
          SwTextField(label: 'Email', icon: Icons.mail_outline, errorText: 'Enter a full email'),
        ]),
    'selection': () => Column(children: [
          SwSegmented<int>(segments: const [SwSegment(0, 'Instant booking'), SwSegment(1, 'Ask me')], selected: 0, onChanged: (_) {}),
          Row(children: [
            SwChip(label: '2 min', selected: false, onTap: () {}),
            SwChip(label: '4 min', selected: true, onTap: () {}),
          ]),
          Row(children: [
            SwToggle(value: true, onChanged: (_) {}, semanticLabel: 'Auto-accept'),
            SwStepper(value: 1, min: 1, max: 3, onChanged: (_) {}, decreaseLabel: 'Fewer seats', increaseLabel: 'More seats'),
          ]),
          SwToggleRow(title: 'Auto-accept your people', value: false, onChanged: (_) {}),
        ]),
    'badges': () => const Wrap(children: [
          SwStatusBadge('Confirmed'),
          SwStatusBadge.deadline('Answer by Thu 10:00'),
          SwTagBadge('Your people', icon: Icons.star_border),
        ]),
    'cards': () => Column(children: [
          SwRideCard(
            departTime: '09:00', arrival: '→ 11:20 · 2 h 20', price: '16 zł', seatsLeft: '2 seats left',
            stops: const ['Kraków', 'Tarnów', 'Rzeszów'], driverName: 'Marek', bookingMode: 'Instant',
            selected: true, onTap: () {},
          ),
          SwDriverOfferCard(
            driverName: 'Kasia', title: 'Kasia · 9 min', subtitle: 'Walk 450 m', actionLabel: 'Request',
            onAction: () {}, onTap: () {},
          ),
        ]),
    'code, price, progress, seats': () => Column(children: [
          const SwPickupCode(title: 'Your pickup code', code: '4827'),
          SwPriceScale(value: 16, min: 8, max: 21, suggestedMin: 14, suggestedMax: 17, onChanged: (_) {},
              format: (v) => '$v zł', semanticLabel: 'Price per seat'),
          const SwProgressRow(title: 'Fuel covered', valueText: '24 of 65 zł', fraction: .37),
          const SwSegmentSeats(rows: [
            SwSegmentSeatRow(label: 'Kraków → Tarnów', seats: 3, occupants: ['Olena'], semanticLabel: '1 of 3 seats taken'),
          ]),
        ]),
    'lists and feedback': () => Column(children: [
          SwListGroup(children: [
            const SwKeyValueRow(label: 'Fuel for the route', value: '65 zł'),
            SwListRow(title: 'Your booking', onTap: () {}),
          ]),
          SwSnackBar(message: 'Route ended', actionLabel: 'Undo', onAction: () {}),
          SwBanner(message: 'Location access is off.', actionLabel: 'Open Settings', onAction: () {}),
          const SwAvatar(name: 'Marek', ring: true),
        ]),
    'sheet': () => SwBottomSheet(
          title: 'Cancel your seat?',
          child: SwSecondaryButton(label: 'Keep browsing', onPressed: () {}),
        ),
  };

  for (final role in SwRole.values) {
    for (final c in components.entries) {
      testWidgets('${c.key} · ${role.name}', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSw(tester, c.value(), role: role);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}
