import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_localizations.dart';

/// Small floating "center the map on me" button anchored to the bottom-right of
/// the map. It tracks the [DraggableScrollableController] of the home screen's
/// bottom sheet so it always floats just above the sheet's top edge and slides
/// with it as the user drags the sheet up and down.
///
/// Must be placed as a direct child of the map [Stack] — it returns a
/// [Positioned] so the Stack can lay it out. (It listens to the controller, so
/// it rebuilds on every drag frame to keep its `bottom` offset in sync.)
class MapRecenterButton extends StatefulWidget {
  /// Controller of the [DraggableScrollableSheet] the button should ride above.
  final DraggableScrollableController sheetController;

  /// `initialChildSize` of that sheet — used only for the very first frame,
  /// before the controller has attached and can report real pixels.
  final double initialSheetSize;

  /// Tint for the icon (teal for passengers, primary for drivers).
  final Color accentColor;

  final VoidCallback onPressed;

  const MapRecenterButton({
    super.key,
    required this.sheetController,
    required this.onPressed,
    this.accentColor = AppColors.teal,
    this.initialSheetSize = 0.55,
  });

  @override
  State<MapRecenterButton> createState() => _MapRecenterButtonState();
}

class _MapRecenterButtonState extends State<MapRecenterButton> {
  // Current sheet height in pixels; 0 means "not measured yet, use fallback".
  double _sheetPixels = 0;

  @override
  void initState() {
    super.initState();
    widget.sheetController.addListener(_onSheetChanged);
    // The controller only has real pixel values after the sheet has laid out,
    // so seed once the first frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSheetChanged());
  }

  void _onSheetChanged() {
    if (!mounted || !widget.sheetController.isAttached) return;
    final px = widget.sheetController.pixels;
    if (px != _sheetPixels) setState(() => _sheetPixels = px);
  }

  @override
  void dispose() {
    widget.sheetController.removeListener(_onSheetChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Before the controller reports real pixels, approximate from the screen
    // height so the button still starts in roughly the right spot.
    final fallback =
        MediaQuery.of(context).size.height * widget.initialSheetSize;
    final sheetTop = _sheetPixels > 0 ? _sheetPixels : fallback;

    return Positioned(
      right: 16,
      bottom: sheetTop + 14,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.96),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onPressed,
          child: Tooltip(
            message: AppLocalizations.of(context).myLocation,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.my_location_rounded,
                color: widget.accentColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
