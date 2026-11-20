@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/theme/theme.dart';
import 'package:sameway/ui/ui.dart';

import 'golden_harness.dart';

/// One golden per Main-board component group, with its states.
/// Run: flutter test --tags golden [--update-goldens]
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  Widget gap([double h = 10]) => SizedBox(height: h);

  swGoldenMatrix('buttons', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwPrimaryButton(label: role == SwRole.driver ? s.startSharing : s.bookSeat, onPressed: () {}),
          gap(),
          SwSecondaryButton(label: s.keepBrowsing, onPressed: () {}),
          gap(),
          SwDangerButton(label: s.cancelSeat, onPressed: () {}),
          gap(),
          SwLaterButton(
            label: s.leaveWithout,
            availableAt: DateTime(2026, 11, 20, 9, 10),
            now: () => DateTime(2026, 11, 20, 9, 4),
            availableText: (_, m) => s.availableAt('09:10', m),
            onPressed: () {},
          ),
          gap(),
          SwDangerButton(label: s.cancelSeat, onPressed: () {}, filled: true),
        ],
      ));

  swGoldenMatrix('fields', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwSearchField(hint: s.whereTo),
          gap(),
          SwTextField(
            controller: TextEditingController(text: 'Politechnika'),
            icon: Icons.flag_outlined,
            iconColor: c.role.fill,
            autofocus: true,
          ),
          gap(),
          SwTextField(
            label: s.email,
            controller: TextEditingController(text: 'pavlo@exampl'),
            icon: Icons.mail_outline,
            errorText: s.emailError,
          ),
        ],
      ));

  swGoldenMatrix('selection', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwSegmented<int>(
            segments: [SwSegment(0, s.instantBooking), SwSegment(1, s.askMe)],
            selected: 0,
            onChanged: (_) {},
          ),
          gap(14),
          Wrap(spacing: 8, children: [
            for (final m in const [2, 4, 6])
              SwChip(label: s.minutes(m), selected: m == 4, onTap: () {}),
          ]),
          gap(14),
          Row(children: [
            SwToggle(value: true, onChanged: (_) {}, semanticLabel: s.autoAccept),
            const SizedBox(width: 6),
            SwToggle(value: false, onChanged: (_) {}, semanticLabel: s.autoAccept),
            const SizedBox(width: 6),
            SwStepper(value: 1, min: 1, max: 3, onChanged: (_) {}, decreaseLabel: s.fewerSeats, increaseLabel: s.moreSeats),
          ]),
          gap(14),
          SwListGroup(children: [SwToggleRow(title: s.autoAccept, value: true, onChanged: (_) {})]),
        ],
      ));

  swGoldenMatrix('status_badges', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            SwStatusBadge(s.confirmed),
            SwStatusBadge(s.requested),
            SwStatusBadge(s.searching),
          ]),
          gap(),
          SwStatusBadge.deadline(s.answerBy),
          gap(),
          SwTagBadge(s.yourPeople, icon: Icons.star_border_rounded),
        ],
      ));

  swGoldenMatrix('ride_card', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwRideCard(
            departTime: '09:00',
            arrival: s.arrival,
            price: '16 zł',
            seatsLeft: s.seatsLeft,
            stops: s.stops,
            driverName: 'Marek',
            tag: SwTagBadge(s.yourPeople, icon: Icons.star_border_rounded),
            bookingMode: s.instant,
            selected: true,
            onTap: () {},
          ),
          gap(),
          SwRideCard(
            departTime: '09:00',
            arrival: s.arrival,
            price: '9 zł',
            seatsLeft: s.seatsLeft,
            stops: s.stops,
            chosenFrom: 1,
            driverName: 'Anna',
            bookingMode: s.askMe,
            onTap: () {},
          ),
        ],
      ));

  swGoldenMatrix('driver_offer', (c, s, role) => SwDriverOfferCard(
        driverName: 'Kasia',
        title: s.offerTitle,
        subtitle: s.offerSubtitle,
        actionLabel: s.request,
        onAction: () {},
        onTap: () {},
      ));

  swGoldenMatrix('pickup_code', (c, s, role) => SwPickupCode(title: s.yourPickupCode, code: '4827'));

  swGoldenMatrix('price', (c, s, role) => SwPriceScale(
        value: 16,
        min: 8,
        max: 21,
        suggestedMin: 14,
        suggestedMax: 17,
        onChanged: (_) {},
        format: (v) => '$v zł',
        semanticLabel: s.pricePerSeat,
      ));

  swGoldenMatrix('fuel_covered', (c, s, role) =>
      SwProgressRow(title: s.fuelCovered, valueText: s.fuelCoveredValue, fraction: 24 / 65));

  swGoldenMatrix('segment_seats', (c, s, role) => SwSegmentSeats(rows: [
        SwSegmentSeatRow(label: s.segment(0, 1), seats: 3, occupants: const ['Olena', 'Jan'], semanticLabel: s.seatsTaken(2, 3)),
        SwSegmentSeatRow(label: s.segment(1, 2), seats: 3, occupants: const ['Olena'], semanticLabel: s.seatsTaken(1, 3)),
      ]));

  swGoldenMatrix('key_value', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwListGroup(children: [
            SwKeyValueRow(label: s.fuelForRoute, value: '65 zł'),
            SwKeyValueRow(label: s.suggestedPerSeat, value: '16 zł', total: true),
          ]),
          gap(14),
          SwListGroup(children: [
            SwListRow(title: s.yourBooking, subtitle: s.stops.first, onTap: () {}),
            SwListRow(
              title: s.requestsWhileDriving,
              leading: const Icon(Icons.record_voice_over_outlined, color: SwColors.textSecondary),
              onTap: () {},
            ),
          ]),
        ],
      ));

  swGoldenMatrix('feedback', (c, s, role) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwSnackBar(message: s.routeEnded, actionLabel: s.undo, onAction: () {}),
          gap(),
          SwBanner(message: s.locationOff, actionLabel: s.openSettings, onAction: () {}),
          gap(),
          SwBanner(message: s.locationOff, actionLabel: s.openSettings, onAction: () {}, tone: SwBannerTone.danger, icon: Icons.location_off_outlined),
        ],
      ));

  swGoldenMatrix('avatar', (c, s, role) => const Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SwAvatar(name: 'Marek'),
          SwAvatar(name: 'Kasia', size: 36),
          SwAvatar(name: 'Olena', size: 48, ring: true),
          SwAvatar(name: 'Jan', size: 64, ring: true),
        ],
      ));

  swGoldenMatrix('bottom_sheet', (c, s, role) => SwBottomSheet(
        title: s.cancelYourSeat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwListGroup(children: [SwKeyValueRow(label: s.yourBooking, value: '16 zł')]),
            gap(16),
            SwDangerButton(label: s.cancelSeat, onPressed: () {}, filled: true),
            gap(),
            SwSecondaryButton(label: s.keepBrowsing, onPressed: () {}),
          ],
        ),
      ));
}
