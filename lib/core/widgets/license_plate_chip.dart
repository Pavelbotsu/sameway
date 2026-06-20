import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Pseudo-plate chip — yellow-ish background, tabular monospaced text, black
/// border. The shape evokes a European-style license plate so a passenger
/// walking to the pickup can quickly compare what they see on the car to
/// what's rendered on their phone.
///
/// Kept small enough to live inline (e.g. in the car info row) but legible at
/// arm's length.
class LicensePlateChip extends StatelessWidget {
  final String plate;
  final double height;

  const LicensePlateChip({
    super.key,
    required this.plate,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    if (plate.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF4D03F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1F1F1F), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.0),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        plate.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
