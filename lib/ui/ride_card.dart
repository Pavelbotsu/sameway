import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'avatar.dart';
import 'layout.dart';

/// Between-cities ride in search results (I_Results): times, duration,
/// price, seats left, the route with the passenger's part highlighted,
/// the driver and the booking mode.
class SwRideCard extends StatelessWidget {
  const SwRideCard({
    super.key,
    required this.departTime,
    required this.arrival,
    required this.price,
    required this.stops,
    required this.driverName,
    this.seatsLeft,
    this.chosenFrom = 0,
    this.chosenTo,
    this.driverPhoto,
    this.tag,
    this.bookingMode,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
  });

  /// "09:00"
  final String departTime;

  /// "→ 11:20 · 2 h 20"
  final String arrival;

  /// "16 zł"
  final String price;

  /// "2 seats left"
  final String? seatsLeft;

  /// City names in route order. Cities are localised by the caller.
  final List<String> stops;

  /// Index range of the passenger's part of the route (inclusive).
  final int chosenFrom;
  final int? chosenTo;
  final String driverName;
  final ImageProvider? driverPhoto;

  /// e.g. `SwTagBadge('Your people', icon: …)`.
  final Widget? tag;

  /// "Instant" / "Ask me"
  final String? bookingMode;
  final bool selected;
  final VoidCallback? onTap;

  /// One sentence for screen readers; defaults to the visible texts merged.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final large = swIsLargeText(context);
    final times = Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      children: [
        Text(departTime,
            style: const TextStyle(fontFamily: swFontFamily, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, color: SwColors.text)),
        Text(arrival,
            style: const TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w500, height: 1.6, color: SwColors.textSecondary)),
      ],
    );
    final priceBlock = Column(
      crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(price,
            style: const TextStyle(fontFamily: swFontFamily, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2, color: SwColors.text)),
        if (seatsLeft != null)
          Text(seatsLeft!,
              style: TextStyle(fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: role.onDark)),
      ],
    );

    final driverRow = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        SwAvatar(name: driverName, image: driverPhoto, excludeFromSemantics: true),
        Text(driverName,
            style: const TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: SwColors.text)),
        ?tag,
      ],
    );

    final modeText = Text(bookingMode ?? '',
        textAlign: large ? TextAlign.start : TextAlign.end,
        style: SwType.caption.copyWith(fontWeight: FontWeight.w500));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (large) ...[times, const SizedBox(height: 6), priceBlock]
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: times), const SizedBox(width: SwSpace.s12), priceBlock],
          ),
        const SizedBox(height: SwSpace.s12),
        _RouteLine(stops: stops, from: chosenFrom, to: chosenTo ?? stops.length - 1, large: large),
        const SizedBox(height: SwSpace.s12),
        if (large) ...[
          // At 200 % the booking mode gets its own line under the driver.
          driverRow,
          if (bookingMode != null) ...[const SizedBox(height: 6), modeText],
        ] else
          // The booking mode keeps its own width (up to 40 %, then wraps);
          // the driver row gets the rest.
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(child: driverRow),
                if (bookingMode != null) ...[
                  const SizedBox(width: SwSpace.s8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
                    child: modeText,
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SwRadius.card),
      side: BorderSide(color: selected ? role.fill : SwColors.line, width: selected ? 1.5 : 1),
    );
    final card = Material(
      color: SwColors.surface2,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(SwSpace.s16), child: content),
      ),
    );
    if (semanticLabel != null) {
      return Semantics(
        button: onTap != null,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: card,
      );
    }
    return MergeSemantics(child: Semantics(selected: selected, child: card));
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.stops, required this.from, required this.to, required this.large});
  final List<String> stops;
  final int from, to;
  final bool large;

  bool _inPart(int i) => i >= from && i <= to;

  TextStyle _style(int i) => TextStyle(
        fontFamily: swFontFamily,
        fontSize: 13,
        height: 1.3,
        fontWeight: (i == from || i == to) ? FontWeight.w700 : FontWeight.w500,
        color: _inPart(i) ? SwColors.text : SwColors.textSecondary,
      );

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    if (large) {
      // At 200 % the names don't fit on one line: wrap them with arrows.
      return Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (var i = 0; i < stops.length; i++) ...[
            if (i > 0) Text('→', style: _style(i).copyWith(color: SwColors.textSecondary, fontWeight: FontWeight.w500)),
            Text(stops[i], style: _style(i)),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < stops.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: SwSpace.s4),
                height: 2,
                color: (_inPart(i - 1) && _inPart(i)) ? role.fill : SwColors.line,
              ),
            ),
          Text(stops[i], style: _style(i)),
        ],
      ],
    );
  }
}
