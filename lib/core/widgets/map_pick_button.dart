import 'package:flutter/material.dart';

/// The location pin that opens the map picker, wrapped in a soft tinted circle
/// so it reads as a tappable button rather than a decorative icon.
///
/// Used as the `prefixIcon` of the driver and passenger location fields. Pair
/// it with `prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48)`
/// on the `InputDecoration` so the field height stays compact.
class MapPickButton extends StatelessWidget {
  /// Tint applied to both the pin and its circular background (teal for the
  /// passenger flow, primary for the driver flow).
  final Color accent;
  final String tooltip;
  final VoidCallback onPressed;

  const MapPickButton({
    super.key,
    required this.accent,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 6),
      child: Material(
        color: accent.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.location_on_rounded, color: accent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
