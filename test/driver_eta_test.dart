import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sameway/core/geo.dart';

/// Guards the candidate-list ETA estimate.
///
/// This number is deliberately approximate — the server returns no per-candidate
/// ETA and computing one would add cost to the most frequently polled query in
/// the app — so what matters is that it degrades sensibly rather than that it is
/// precise. In particular it must never claim "0 min".
void main() {
  final krakow = LatLng(50.0647, 19.9450);

  group('estimateDriverEtaMinutes', () {
    test('a driver already at the pickup is 1 min, never 0', () {
      expect(estimateDriverEtaMinutes(krakow, krakow), 1);
    });

    test('a few hundred metres still rounds up to at least 1 min', () {
      final almost = LatLng(50.0647, 19.9480); // ~215 m east
      expect(estimateDriverEtaMinutes(krakow, almost), greaterThanOrEqualTo(1));
    });

    test('scales with distance at the assumed driving speed', () {
      // ~10.7 km east of centre; at 30 km/h that is a bit over 20 min.
      final far = LatLng(50.0647, 20.0950);
      final mins = estimateDriverEtaMinutes(krakow, far);
      final expected = geoDistanceKm(krakow, far) / assumedDriverKmh * 60;
      expect(mins, closeTo(expected, 1));
    });

    test('is symmetric — argument order must not change the answer', () {
      final other = LatLng(50.1000, 20.0000);
      expect(
        estimateDriverEtaMinutes(krakow, other),
        estimateDriverEtaMinutes(other, krakow),
      );
    });

    test('a further driver never reports a shorter ETA', () {
      final near = LatLng(50.0647, 19.9600);
      final far = LatLng(50.0647, 20.0500);
      expect(
        estimateDriverEtaMinutes(krakow, far),
        greaterThanOrEqualTo(estimateDriverEtaMinutes(krakow, near)),
        reason: 'the list sorts and is read by ETA — inversions would mislead',
      );
    });
  });
}
