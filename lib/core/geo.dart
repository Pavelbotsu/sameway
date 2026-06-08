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
