import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sameway/core/ride_check_in.dart';

/// Guards the mid-ride safety check-in decision logic.
///
/// The failure that matters most here is a FALSE POSITIVE, not a false
/// negative. The passenger app has no background location service, so a locked
/// phone freezes their last fix while the car drives on. If staleness were
/// treated as separation, the prompt would fire on most normal rides, users
/// would learn to dismiss it without reading, and it would be worse than not
/// shipping. Hence the heavy emphasis on `unknown` below.
void main() {
  // Kraków city centre and a point ~1.1 km east of it.
  final here = LatLng(50.0647, 19.9450);
  final near = LatLng(50.0648, 19.9452); // ~20 m — same car
  final far = LatLng(50.0647, 19.9600); // ~1.07 km — not the same car
  final now = DateTime.utc(2026, 8, 6, 12, 0, 0);
  final fresh = now.subtract(const Duration(seconds: 5));
  final stale = now.subtract(kCheckInFreshnessWindow + const Duration(seconds: 1));

  CheckInVerdict verdict({
    LatLng? self,
    DateTime? selfAt,
    LatLng? peer,
    DateTime? peerAt,
  }) =>
      evaluateCheckIn(
        self: self,
        selfAt: selfAt,
        peer: peer,
        peerAt: peerAt,
        now: now,
      );

  group('evaluateCheckIn', () {
    test('both fresh and close together', () {
      expect(
        verdict(self: here, selfAt: fresh, peer: near, peerAt: fresh),
        CheckInVerdict.together,
      );
    });

    test('both fresh and far apart', () {
      expect(
        verdict(self: here, selfAt: fresh, peer: far, peerAt: fresh),
        CheckInVerdict.apart,
      );
    });

    test('stale peer fix is unknown, never apart', () {
      // The backgrounded-passenger case. Distance says "far", but the peer fix
      // is old, so we have no evidence and must not prompt.
      expect(
        verdict(self: here, selfAt: fresh, peer: far, peerAt: stale),
        CheckInVerdict.unknown,
      );
    });

    test('stale self fix is unknown, never apart', () {
      expect(
        verdict(self: here, selfAt: stale, peer: far, peerAt: fresh),
        CheckInVerdict.unknown,
      );
    });

    test('both stale is unknown', () {
      expect(
        verdict(self: here, selfAt: stale, peer: far, peerAt: stale),
        CheckInVerdict.unknown,
      );
    });

    test('missing peer position is unknown', () {
      expect(
        verdict(self: here, selfAt: fresh, peer: null, peerAt: fresh),
        CheckInVerdict.unknown,
      );
    });

    test('missing timestamps are unknown', () {
      expect(
        verdict(self: here, selfAt: null, peer: far, peerAt: null),
        CheckInVerdict.unknown,
      );
    });

    test('a fix exactly at the freshness boundary still counts', () {
      final boundary = now.subtract(kCheckInFreshnessWindow);
      expect(
        verdict(self: here, selfAt: boundary, peer: far, peerAt: boundary),
        CheckInVerdict.apart,
      );
    });

    test('a future-stamped fix counts as fresh, not stale', () {
      // Two devices, two clocks. Skew must not silently disable the check.
      final ahead = now.add(const Duration(seconds: 30));
      expect(
        verdict(self: here, selfAt: fresh, peer: far, peerAt: ahead),
        CheckInVerdict.apart,
      );
    });
  });

  group('RideCheckInTracker', () {
    test('prompts only after kCheckInConsecutive apart readings', () {
      final t = RideCheckInTracker();
      for (var i = 1; i < kCheckInConsecutive; i++) {
        expect(t.observe('ride-1', CheckInVerdict.apart), isFalse,
            reason: 'must not prompt on reading $i');
      }
      expect(t.observe('ride-1', CheckInVerdict.apart), isTrue);
    });

    test('prompts at most once per ride', () {
      final t = RideCheckInTracker();
      for (var i = 0; i < kCheckInConsecutive; i++) {
        t.observe('ride-1', CheckInVerdict.apart);
      }
      // Sustained separation after the user already answered must stay quiet.
      for (var i = 0; i < kCheckInConsecutive * 3; i++) {
        expect(t.observe('ride-1', CheckInVerdict.apart), isFalse);
      }
    });

    test('an unknown reading breaks the streak', () {
      final t = RideCheckInTracker();
      t.observe('ride-1', CheckInVerdict.apart);
      t.observe('ride-1', CheckInVerdict.apart);
      t.observe('ride-1', CheckInVerdict.unknown);
      // Streak restarted, so this is reading 1 of kCheckInConsecutive.
      expect(t.observe('ride-1', CheckInVerdict.apart), isFalse);
    });

    test('a together reading breaks the streak', () {
      final t = RideCheckInTracker();
      t.observe('ride-1', CheckInVerdict.apart);
      t.observe('ride-1', CheckInVerdict.apart);
      t.observe('ride-1', CheckInVerdict.together);
      expect(t.observe('ride-1', CheckInVerdict.apart), isFalse);
    });

    test('no active ride resets the streak', () {
      final t = RideCheckInTracker();
      t.observe('ride-1', CheckInVerdict.apart);
      t.observe('ride-1', CheckInVerdict.apart);
      expect(t.observe(null, CheckInVerdict.apart), isFalse);
      expect(t.observe('ride-1', CheckInVerdict.apart), isFalse);
    });

    test('reset lets a later ride prompt again', () {
      final t = RideCheckInTracker();
      for (var i = 0; i < kCheckInConsecutive; i++) {
        t.observe('ride-1', CheckInVerdict.apart);
      }
      t.reset();
      for (var i = 1; i < kCheckInConsecutive; i++) {
        expect(t.observe('ride-2', CheckInVerdict.apart), isFalse);
      }
      expect(t.observe('ride-2', CheckInVerdict.apart), isTrue);
    });
  });
}
