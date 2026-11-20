import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'list_group.dart';

/// One part of a between-cities route with its seats.
class SwSegmentSeatRow {
  const SwSegmentSeatRow({
    required this.label,
    required this.seats,
    required this.occupants,
    required this.semanticLabel,
  });

  /// "Kraków → Tarnów"
  final String label;

  /// Seats offered on the trip.
  final int seats;

  /// Names of the passengers on this part (initial shown in the square).
  final List<String> occupants;

  /// "2 of 3 seats taken"
  final String semanticLabel;
}

/// Seats by part of the route (I_DriverManage): one row per segment,
/// a filled square per booked seat with the passenger's initial.
class SwSegmentSeats extends StatelessWidget {
  const SwSegmentSeats({super.key, required this.rows});
  final List<SwSegmentSeatRow> rows;

  @override
  Widget build(BuildContext context) {
    return SwListGroup(children: [for (final r in rows) _Row(row: r)]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final SwSegmentSeatRow row;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final squares = Semantics(
      label: row.semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < row.seats; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _Seat(name: i < row.occupants.length ? row.occupants[i] : null, fill: role.fill),
          ],
        ],
      ),
    );
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwSpace.s16, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SwSpace.s12,
            runSpacing: 6,
            children: [
              Text(row.label, style: SwType.body.copyWith(color: SwColors.text, fontWeight: FontWeight.w600)),
              squares,
            ],
          ),
        ),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.name, required this.fill});
  final String? name;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final taken = name != null && name!.trim().isNotEmpty;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: taken ? fill : SwColors.background,
        borderRadius: BorderRadius.circular(SwRadius.inner),
        border: Border.all(color: taken ? fill : SwColors.fieldBorder),
      ),
      child: taken
          ? Text(
              name!.trim().characters.first.toUpperCase(),
              textScaler: TextScaler.noScaling, // fixed square; meaning is in semanticLabel
              style: const TextStyle(fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w700, height: 1, color: SwColors.onAccent),
            )
          : null,
    );
  }
}
