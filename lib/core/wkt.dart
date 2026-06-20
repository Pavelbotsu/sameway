import 'package:latlong2/latlong.dart';

/// Parses a `LINESTRING(lng lat, …)` (PostGIS / OSRM WKT) into a list of
/// `LatLng`. Returns an empty list on any parse error so the caller can
/// fall back to a straight line without a try/catch at every render site.
///
/// Tolerates either `LINESTRING(...)` or `LINESTRING (...)` (with space).
/// Single-point or malformed strings return `[]`.
List<LatLng> parseLineStringWKT(String wkt) {
  if (wkt.isEmpty) return const [];
  try {
    final inner = wkt
        .replaceAll('LINESTRING(', '')
        .replaceAll('LINESTRING (', '')
        .replaceAll(')', '');
    return inner.split(',').map((pair) {
      final parts = pair.trim().split(' ');
      return LatLng(double.parse(parts[1]), double.parse(parts[0]));
    }).toList();
  } catch (_) {
    return const [];
  }
}
