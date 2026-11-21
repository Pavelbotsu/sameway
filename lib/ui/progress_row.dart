import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Title, value and a role-coloured bar ("Fuel covered · 24 of 65 zł":
/// what the booked seats cover of the fuel; I_DriverPrice, I_PriceHow,
/// I_DriverManage).
class SwProgressRow extends StatelessWidget {
  const SwProgressRow({
    super.key,
    required this.title,
    required this.valueText,
    required this.fraction,
  });

  /// "Fuel covered"
  final String title;

  /// "24 of 65 zł"
  final String valueText;

  /// 0…1
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final f = fraction.clamp(0.0, 1.0);
    return Semantics(
      label: title,
      value: valueText,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SwColors.surface2,
          borderRadius: BorderRadius.circular(SwRadius.card),
          border: Border.all(color: SwColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: SwSpace.s12,
              children: [
                Text(title, style: SwType.body.copyWith(color: SwColors.text, fontWeight: FontWeight.w600)),
                Text(valueText, style: SwType.body.copyWith(color: SwColors.text, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: SwColors.surface3)),
                  FractionallySizedBox(
                    widthFactor: f,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: role.fill, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
