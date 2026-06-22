import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_localizations.dart';

/// Full-map overlay for "pick a point on the map" mode. The user pans the map
/// under a fixed centre pin; the caller reads `mapController.camera.center` on
/// confirm. Designed to be dropped in as a direct child of the map [Stack],
/// ABOVE the bottom sheet, so the action bar floats over it.
///
/// It rides just above the [sheetController]'s top edge (same trick as
/// [MapRecenterButton]) so the Confirm/Cancel bar stays visible when the sheet
/// is shrunk for picking.
class MapDestinationPicker extends StatefulWidget {
  final DraggableScrollableController sheetController;
  final double initialSheetSize;
  final Color accent;

  /// Instruction shown at the top (e.g. "Move the map to your destination").
  final String title;

  /// Confirm button label (e.g. "Set destination here").
  final String confirmLabel;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const MapDestinationPicker({
    super.key,
    required this.sheetController,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.accent = AppColors.teal,
    this.initialSheetSize = 0.3,
  });

  @override
  State<MapDestinationPicker> createState() => _MapDestinationPickerState();
}

class _MapDestinationPickerState extends State<MapDestinationPicker> {
  double _sheetPixels = 0;

  @override
  void initState() {
    super.initState();
    widget.sheetController.addListener(_onSheetChanged);
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
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final fallback = media.size.height * widget.initialSheetSize;
    final sheetTop = _sheetPixels > 0 ? _sheetPixels : fallback;

    return Stack(
      children: [
        // Fixed centre pin. IgnorePointer so the map pans underneath it.
        // Offset up by half its height so the tip points at the map centre,
        // which is what camera.center returns.
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Icon(
                Icons.location_on_rounded,
                color: widget.accent,
                size: 46,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
        ),

        // Top instruction pill.
        Positioned(
          top: media.viewPadding.top + 70,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, color: widget.accent, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Confirm / Cancel bar, floating just above the (shrunk) sheet.
        Positioned(
          left: 16,
          right: 16,
          bottom: sheetTop + 14,
          child: Row(
            children: [
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppColors.surface.withValues(alpha: 0.96),
                  ),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: widget.onConfirm,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      widget.confirmLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
