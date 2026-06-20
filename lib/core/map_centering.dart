import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Centers the map on [pos], but shifts the camera target south so the marker
/// renders in the middle of the *visible* map area — the area not covered by
/// the bottom DraggableScrollableSheet. `sheetCoverFraction` is how much of
/// the screen the sheet occupies (matches `initialChildSize`).
///
/// Without this shift, the marker would render at the screen's geometric
/// center, which is now behind the sheet.
void centerOnUserAdjustedForSheet({
  required BuildContext context,
  required MapController mapController,
  required LatLng pos,
  double zoom = 14,
  double sheetCoverFraction = 0.55,
}) {
  final h = MediaQuery.of(context).size.height;
  // We want the marker at the vertical midpoint of the visible map area
  // (the top 1 - sheetCoverFraction of the screen). The map's geographic
  // center always sits at the screen center, so shift the camera target
  // south by (sheetCoverFraction / 2) of screen height.
  final shiftPx = h * sheetCoverFraction * 0.5;
  // Web Mercator pixels-per-meter at this latitude and zoom.
  final metersPerPx =
      156543.03 * math.cos(pos.latitude * math.pi / 180) / math.pow(2, zoom);
  final latOffset = (shiftPx * metersPerPx) / 111320.0;
  mapController.move(
    LatLng(pos.latitude - latOffset, pos.longitude),
    zoom,
  );
}
