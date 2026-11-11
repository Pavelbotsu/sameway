import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Mid-ride safety check-in: are the two parties still together?
///
/// While a ride is `in_progress` the passenger is physically in the driver's
/// car, so both apps should be reporting essentially the same position. If they
/// separate, either something benign happened (the ride effectively ended and
/// nobody pressed "drop off") or something is wrong. Either way it is worth
/// asking.
///
/// The data is already there and unused: the backend relays both directions
/// over the existing WebSocket during accepted/in_progress
/// (`passenger_location` / `driver_location`, throttled by MATCH_LIVE_LOC_S).
///
/// ## Why freshness gating is the whole design
///
/// The driver runs an Android foreground service, so their fix stays current
/// with the screen off. **The passenger does not** — passenger location comes
/// only from a foreground `Timer.periodic`. The moment a passenger locks their
/// phone their last-known position freezes while the car keeps moving, which is
/// indistinguishable from a real separation if you only look at distance.
///
/// So a stale fix is never evidence of anything. It yields [CheckInVerdict
/// .unknown], which must not prompt. Getting this backwards would fire the
/// prompt on most normal rides, users would learn to dismiss it reflexively,
/// and the feature would end up worse than not shipping it.
enum CheckInVerdict {
  /// At least one fix is missing or too old to compare. Never prompt.
  unknown,

  /// Both fixes are fresh and close together — the expected state mid-ride.
  together,

  /// Both fixes are fresh and far apart. This is the only state worth asking
  /// about.
  apart,
}

/// A fix older than this is treated as no information at all.
///
/// 90s spans several 10s location ticks, so a couple of dropped pings (tunnel,
/// flaky signal, a GC pause) won't downgrade a healthy ride to `unknown`, while
/// a backgrounded phone crosses it quickly enough that we stop trusting it
/// before the car has travelled far.
const kCheckInFreshnessWindow = Duration(seconds: 90);

/// Separation beyond which two people are not in the same vehicle.
///
/// 500m is far outside GPS error (tens of metres, even in a street canyon) and
/// far beyond any in-car seating distance, but is reached within about half a
/// minute of a car pulling away from someone standing still.
const kCheckInApartKm = 0.5;

/// Consecutive [CheckInVerdict.apart] readings required before prompting.
///
/// At the client's 10s location cadence this is roughly 30s of sustained
/// separation, which filters out single bad fixes without making a real
/// separation slow to notice.
const kCheckInConsecutive = 3;

/// Pure decision function — deliberately free of provider/UI state so it can be
/// tested exhaustively. See `test/ride_check_in_test.dart`.
///
/// [now] is injected rather than read from the clock so freshness is testable.
CheckInVerdict evaluateCheckIn({
  required LatLng? self,
  required DateTime? selfAt,
  required LatLng? peer,
  required DateTime? peerAt,
  required DateTime now,
}) {
  if (self == null || selfAt == null || peer == null || peerAt == null) {
    return CheckInVerdict.unknown;
  }
  if (_isStale(selfAt, now) || _isStale(peerAt, now)) {
    return CheckInVerdict.unknown;
  }
  return geoDistanceKm(self, peer) > kCheckInApartKm
      ? CheckInVerdict.apart
      : CheckInVerdict.together;
}

/// A timestamp from the future (clock skew between the two devices, or a peer
/// fix stamped on arrival while the local clock lags) is treated as fresh
/// rather than stale — it is still the newest thing we have.
bool _isStale(DateTime at, DateTime now) =>
    now.difference(at) > kCheckInFreshnessWindow;

/// Tracks consecutive [CheckInVerdict.apart] readings for a single ride and
/// reports the one moment the prompt should be shown.
///
/// Latching is per ride id: the prompt asks **once**. Someone who answers "yes,
/// all good" while walking away from a car they just left must not be asked
/// again thirty seconds later — a safety prompt that nags is a safety prompt
/// that gets dismissed on reflex.
class RideCheckInTracker {
  int _consecutiveApart = 0;
  String? _promptedForRequestId;

  /// Feeds one observation. Returns true exactly once per ride, on the reading
  /// that completes [kCheckInConsecutive] consecutive `apart` verdicts.
  ///
  /// [requestId] null (no active ride) resets the streak — it is not evidence
  /// of anything, and leaving the count standing would let a streak from one
  /// ride spill into the next.
  bool observe(String? requestId, CheckInVerdict verdict) {
    if (requestId == null) {
      _consecutiveApart = 0;
      return false;
    }
    if (verdict != CheckInVerdict.apart) {
      // `unknown` resets too: a gap in the evidence breaks the streak rather
      // than preserving it, so we only ever prompt on sustained, *observed*
      // separation.
      _consecutiveApart = 0;
      return false;
    }
    _consecutiveApart++;
    if (_consecutiveApart < kCheckInConsecutive) return false;
    if (_promptedForRequestId == requestId) return false;
    _promptedForRequestId = requestId;
    return true;
  }

  /// Call when a ride ends or is cancelled so the next ride starts clean.
  void reset() {
    _consecutiveApart = 0;
    _promptedForRequestId = null;
  }
}
