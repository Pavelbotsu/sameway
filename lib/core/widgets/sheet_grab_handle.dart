import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The visual pill at the top of a `DraggableScrollableSheet` — drag-aware.
///
/// The previous implementation was a plain `Container` decoration which the
/// sheet couldn't see as a draggable surface (the sheet's drag-via-scroll
/// only fires when the gesture starts inside the scrollable child). Users
/// instinctively try to grab the visual pill; this widget makes that gesture
/// work by translating vertical drags directly into `controller.jumpTo`.
///
/// On drag end the sheet snaps to the nearest entry in [snapSizes] (or to
/// `minChildSize` / `maxChildSize` if no snap list was supplied), matching
/// the look-and-feel of the normal scroll-induced drag.
class SheetGrabHandle extends StatelessWidget {
  final DraggableScrollableController controller;
  final double minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;

  const SheetGrabHandle({
    super.key,
    required this.controller,
    required this.minChildSize,
    required this.maxChildSize,
    this.snapSizes,
  });

  void _handleDrag(DragUpdateDetails d, double screenHeight) {
    if (!controller.isAttached) return;
    // Positive dy = finger moved down = collapse the sheet (shrink size).
    final delta = d.delta.dy / screenHeight;
    final next = (controller.size - delta).clamp(minChildSize, maxChildSize);
    controller.jumpTo(next);
  }

  void _handleDragEnd(DragEndDetails _) {
    if (!controller.isAttached) return;
    final stops = <double>[
      minChildSize,
      ...?snapSizes,
      maxChildSize,
    ];
    final size = controller.size;
    double nearest = stops.first;
    double bestDist = (size - nearest).abs();
    for (final s in stops) {
      final d = (size - s).abs();
      if (d < bestDist) {
        bestDist = d;
        nearest = s;
      }
    }
    controller.animateTo(
      nearest,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return GestureDetector(
      // Translucent so the gesture is picked up across the padded hit area
      // — without this only the 4-px visual bar would receive touch events.
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) => _handleDrag(d, h),
      onVerticalDragEnd: _handleDragEnd,
      child: SizedBox(
        // 28-px hit area is the iOS / Material default for a drag handle.
        // Keeps the visual look small but makes the touch target generous.
        height: 28,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
