import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// "Your pickup code" with one box per digit (P_Requested, I_MyBooking).
/// The passenger shows it; the driver types it. Never on the lock screen,
/// in a push payload or in chat: this widget is for in-app screens only.
class SwPickupCode extends StatelessWidget {
  const SwPickupCode({super.key, required this.title, required this.code});

  /// "Your pickup code"
  final String title;

  /// Usually 4 digits.
  final String code;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final digits = code.characters.toList();
    return Semantics(
      container: true,
      // Digits one by one, so "4827" isn't read as a number.
      // l10n-ignore: only punctuation; the words come from [title]
      label: '$title: ${digits.join(' ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(SwSpace.s16),
        decoration: BoxDecoration(
          color: role.tint,
          borderRadius: BorderRadius.circular(SwRadius.card),
          border: Border.all(color: role.tintLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: SwType.groupLabel.copyWith(color: SwColors.text)),
            const SizedBox(height: SwSpace.s12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final d in digits)
                  Container(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SwColors.background,
                      borderRadius: BorderRadius.circular(SwRadius.field),
                      border: Border.all(color: role.fill, width: 2),
                    ),
                    child: Text(d,
                        style: const TextStyle(fontFamily: swFontFamily, fontSize: 22, fontWeight: FontWeight.w800, color: SwColors.text)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
