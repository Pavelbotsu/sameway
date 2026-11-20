import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Snap sizes for the map screens' draggable sheet, in one place
/// (today they are duplicated in the home screens; Phase 4 moves them here).
class SwSheetSizes {
  const SwSheetSizes({required this.min, required this.initial, required this.max, this.snaps = const []});
  final double min, initial, max;
  final List<double> snaps;

  /// Map screens (P_Home, D_Home and the ride states on top of the map).
  static const map = SwSheetSizes(min: 0.26, initial: 0.55, max: 0.92);
}

/// Sheet body: surface 1, 20 px top corners, a grab handle, an optional
/// title (22/700). Scrolls when the content is taller than the screen
/// (200 % text). Use [showSwBottomSheet] for modal sheets.
class SwBottomSheet extends StatelessWidget {
  const SwBottomSheet({super.key, required this.child, this.title, this.padding});
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SwRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SwGrabHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: padding ?? const EdgeInsets.fromLTRB(SwSpace.screen, SwSpace.s8, SwSpace.screen, SwSpace.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null) ...[
                      Semantics(
                        header: true,
                        child: Text(title!, style: SwType.sheetTitle.copyWith(color: SwColors.text)),
                      ),
                      const SizedBox(height: SwSpace.s16),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 36×4 handle at the top of every sheet. Decorative: sheets close with
/// the system back gesture, the scrim or their own button.
class SwGrabHandle extends StatelessWidget {
  const SwGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: SwColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
    );
  }
}

/// Modal v3 sheet over a scrim (no shadow).
Future<T?> showSwBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: SwColors.scrim,
    elevation: 0,
    builder: (ctx) => SwBottomSheet(title: title, child: builder(ctx)),
  );
}
