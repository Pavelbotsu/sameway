import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Average pedestrian speed in km/h, used to convert walk distance to minutes
/// for the passenger pickup pill.
const walkSpeedKmh = 5.0;

/// Assumed driver speed in km/h when the passenger UI needs an ETA but
/// doesn't have the driver's live rolling average.
const assumedDriverKmh = 30.0;

/// Convert a distance in metres to a minute estimate floored at 1 min.
int minutesAt(double distanceM, double speedKmh) {
  if (speedKmh <= 0) return 1;
  final mins = distanceM / 1000.0 / speedKmh * 60.0;
  return mins < 1 ? 1 : mins.round();
}

/// Great-circle distance in kilometres between two LatLng points.
/// Uses the Haversine formula with the WGS-84 mean Earth radius.
double geoDistanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
  final lat1 = a.latitude * math.pi / 180.0;
  final lat2 = b.latitude * math.pi / 180.0;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Shortest distance in kilometres from [point] to the [route] polyline.
///
/// Because a driver keeps their own route (no detour to suit the passenger),
/// the passenger is effectively dropped at the closest point on that route to
/// their destination and walks the rest. This returns exactly that remaining
/// walk: the minimum distance from the destination to any segment of the
/// route. Returns 0 for an empty route.
double distanceToRouteKm(LatLng point, List<LatLng> route) {
  if (route.isEmpty) return 0;
  if (route.length == 1) return geoDistanceKm(point, route.first);
  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final d = _distanceToSegmentKm(point, route[i], route[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

/// Distance (km) from point [p] to the segment [a]→[b]. Projects onto a local
/// equirectangular plane centred on [a] — accurate at the short ranges a walk
/// estimate cares about.
double _distanceToSegmentKm(LatLng p, LatLng a, LatLng b) {
  const r = 6371000.0; // metres
  final lat0 = a.latitude * math.pi / 180.0;
  double mx(LatLng q) =>
      (q.longitude - a.longitude) * math.pi / 180.0 * math.cos(lat0) * r;
  double my(LatLng q) => (q.latitude - a.latitude) * math.pi / 180.0 * r;

  final px = mx(p), py = my(p);
  final bx = mx(b), by = my(b);
  final segLenSq = bx * bx + by * by;
  var t = segLenSq == 0 ? 0.0 : (px * bx + py * by) / segLenSq;
  t = t.clamp(0.0, 1.0);
  final dx = px - bx * t, dy = py - by * t;
  return math.sqrt(dx * dx + dy * dy) / 1000.0;
}
