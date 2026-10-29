import 'dart:async';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/analytics.dart';
import '../../core/geo.dart';
import '../../core/haptics.dart';
import '../../core/location_service.dart';
import '../../core/ride_check_in.dart';
import '../../core/websocket_client.dart';
import 'driver_repository.dart';

class PassengerMatchInfo {
  final String? name;
  final double? avgRating;
  final int? ratingCount;
  const PassengerMatchInfo({this.name, this.avgRating, this.ratingCount});

  bool get hasRating => (ratingCount ?? 0) > 0 && avgRating != null;
}

class PeerLatLng {
  final double lat;
  final double lng;

  /// When this fix was received. The mid-ride check-in refuses to compare
  /// positions unless both are recent — a passenger whose phone is locked stops
  /// reporting, and a frozen position is not evidence that they left the car.
  final DateTime at;

  PeerLatLng(this.lat, this.lng, {DateTime? at}) : at = at ?? DateTime.now();
}

class DriverProvider extends ChangeNotifier {
  final DriverRepository _repo;
  final WebSocketClient _ws;

  RouteResult? activeRoute;
  List<RideRequest> requests = [];
  bool isLoading = false;
  String? error;
  // Live corridor counters, updated by the `corridor_stats` WS event after
  // every backend corridor run (route set, movement re-run, passenger-appear
  // trigger). totalNotified is server-cumulative for the current route, so
  // it can be assigned directly — never summed client-side.
  int totalNotified = 0;
  int candidatesFound = 0;
  int activePendingCount = 0;
  String? acceptedRequestId;
  String? acceptedPassengerName;
  double? acceptedPassengerAvgRating;
  int? acceptedPassengerRatingCount;
  final Map<String, PassengerMatchInfo> passengerInfo = {};
  final Map<String, PeerLatLng> passengerLocations = {};
  WsState wsState = WsState.disconnected;
  int unreadMessages = 0;
  LatLng? destinationPos;
  String? awaitingRatingRequestId;
  String? pendingRatingRequestId;
  String? pendingRatingPassengerId;
  Timer? _ratingWaitTimeout;

  PickupRoute? pickupRoute;
  LatLng? _lastPickupComputedAt;
  DateTime _lastPickupComputeTime =
      DateTime.fromMillisecondsSinceEpoch(0);

  // ── Mid-ride safety check-in ─────────────────────────────────────────────
  // Set when a passenger currently in this driver's car has been provably far
  // away for ~30s. The home screen watches it and opens RideCheckInSheet.
  // See core/ride_check_in.dart for why freshness gating is the whole design.
  //
  // Per-request trackers, not one: a driver can carry several passengers, and
  // one of them getting out must not consume the other's streak or its
  // already-asked latch.
  //
  // Prompts queue rather than overwrite: two trackers can latch in the same
  // tick, and each has already spent its once-per-ride prompt.
  bool checkInPrompt = false;
  final List<String> _checkInQueue = [];
  final Map<String, RideCheckInTracker> _checkIns = {};

  /// Pops the next queued request that is still in_progress, or null. Rides
  /// that ended while waiting in the queue are dropped.
  String? takeCheckInPrompt() {
    String? next;
    while (_checkInQueue.isNotEmpty && next == null) {
      final id = _checkInQueue.removeAt(0);
      if (requests.any((r) => r.id == id && r.status == 'in_progress')) {
        next = id;
      }
    }
    checkInPrompt = _checkInQueue.isNotEmpty;
    return next;
  }

  /// Evaluates every ride currently in_progress. Rides still in `accepted` are
  /// skipped: before pickup the two being apart is the expected state — that
  /// separation is exactly the walk-to-pickup leg.
  void _evaluateCheckIn() {
    for (final r in requests) {
      if (r.status != 'in_progress') {
        _checkIns[r.id]?.reset();
        continue;
      }
      final loc = passengerLocations[r.id];
      final verdict = evaluateCheckIn(
        // Reuses the fix updateLocation already records for the speed EMA.
        // _lastMyPosTime is epoch-initialised, so it is only meaningful once
        // _lastMyPos is non-null — pass null together with it.
        self: _lastMyPos,
        selfAt: _lastMyPos == null ? null : _lastMyPosTime,
        peer: loc == null ? null : LatLng(loc.lat, loc.lng),
        peerAt: loc?.at,
        now: DateTime.now(),
      );
      final tracker =
          _checkIns.putIfAbsent(r.id, () => RideCheckInTracker());
      if (tracker.observe(r.id, verdict)) {
        _checkInQueue.add(r.id);
        checkInPrompt = true;
        Analytics.logEvent('ride_check_in_prompted', {'role': 'driver'});
        notifyListeners();
      }
    }
  }

  void _resetCheckIn(String requestId) {
    _checkIns.remove(requestId);
    _checkInQueue.remove(requestId);
    checkInPrompt = _checkInQueue.isNotEmpty;
  }

  /// Full teardown (route deleted, driving day ended, role switched).
  void _resetAllCheckIns() {
    _checkIns.clear();
    _checkInQueue.clear();
    checkInPrompt = false;
  }

  /// Records a "something is wrong" answer. Never throws — the caller's next
  /// step is the SOS sheet, and a failed bookkeeping write must not block it.
  Future<void> flagSafety(String requestId, String reason) async {
    try {
      await _repo.flagSafety(requestId: requestId, reason: reason);
    } catch (_) {/* best effort — SOS is the real escalation */}
  }

  /// True when several consecutive location pings have failed. The backend
  /// stops matching a driver whose last fix has aged out, so this drives a
  /// visible warning rather than letting the driver sit there invisible.
  bool locationSyncFailing = false;
  int _locationFailures = 0;
  static const _locationFailureThreshold = 3;

  // Rolling EMA of observed speed (km/h), computed from successive
  // updateLocation() samples. Used for the ETA badge.
  double? rollingAvgSpeedKmh;
  LatLng? _lastMyPos;
  DateTime _lastMyPosTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _maybeRefreshPickupRoute(
      String requestId, LatLng passengerPos) async {
    if (requestId != acceptedRequestId) return;
    final now = DateTime.now();
    final tooSoon =
        now.difference(_lastPickupComputeTime) < const Duration(seconds: 30);
    final movedFar = _lastPickupComputedAt == null ||
        geoDistanceKm(_lastPickupComputedAt!, passengerPos) > 0.5;
    if (pickupRoute != null && tooSoon) return;
    if (pickupRoute != null && !movedFar) return;
    _lastPickupComputeTime = now;
    _lastPickupComputedAt = passengerPos;
    try {
      final r = await _repo.getPickupRoute(requestId);
      if (acceptedRequestId == requestId) {
        pickupRoute = r.isEmpty ? null : r;
        notifyListeners();
      }
    } catch (_) {}
  }

  double? distanceToDestinationKm(LatLng? myPos) {
    if (myPos == null || destinationPos == null) return null;
    return geoDistanceKm(myPos, destinationPos!);
  }

  void markAwaitingPassengerRating(String requestId) {
    awaitingRatingRequestId = requestId;
    _ratingWaitTimeout?.cancel();
    _ratingWaitTimeout = Timer(
      const Duration(seconds: 30),
      clearAwaitingRating,
    );
    notifyListeners();
  }

  void clearAwaitingRating() {
    if (awaitingRatingRequestId == null) return;
    awaitingRatingRequestId = null;
    _ratingWaitTimeout?.cancel();
    _ratingWaitTimeout = null;
    notifyListeners();
  }

  void clearPendingRating() {
    pendingRatingRequestId = null;
    pendingRatingPassengerId = null;
    notifyListeners();
  }

  final _incomingRequests = StreamController<PassengerMatchInfo>.broadcast();

  // Emits when a new passenger-initiated `passenger_request` WS arrives. UI
  // subscribes to surface a SnackBar + haptic.
  Stream<PassengerMatchInfo> get incomingRequests => _incomingRequests.stream;

  // Emits when the background location service could not start for a new
  // route. The driver then drops out of matching as soon as the screen locks,
  // so the home screen tells them to keep the app open instead of failing
  // silently (the old behaviour).
  final _backgroundLocationFailed = StreamController<void>.broadcast();
  Stream<void> get backgroundLocationFailed => _backgroundLocationFailed.stream;

  StreamSubscription? _wsSub;
  StreamSubscription? _wsStateSub;

  DriverProvider(this._repo, this._ws);

  // Guards notifyListeners() against firing after disposal. Several paths
  // notify after an await (network calls in setRoute/_maybeRefreshPickupRoute);
  // if the user switches role in that window, notifying a disposed
  // ChangeNotifier throws and main.dart's PlatformDispatcher.onError reports it
  // to Crashlytics as a fatal crash.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  PassengerMatchInfo? infoFor(String requestId) => passengerInfo[requestId];

  void connectWS(String token) {
    _ws.connect(token);
    _wsStateSub ??= _ws.state.listen((s) {
      wsState = s;
      notifyListeners();
      if (s == WsState.connected) {
        loadRequests();
      }
    });
    _wsSub ??= _ws.messages.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final p = (msg['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

    if (type == 'ride_cancelled' || type == 'passenger_request_cancelled') {
      // 'driver_passed': the ETA-window logic expired this match because the
      // driver drove past the pickup before it went active.
      if (type == 'ride_cancelled' && p['cancelled_by'] == 'driver_passed') {
        Analytics.logEvent('ride_expired_passed', {'role': 'driver'});
      }
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == acceptedRequestId) {
        acceptedRequestId = null;
        acceptedPassengerName = null;
        acceptedPassengerAvgRating = null;
        acceptedPassengerRatingCount = null;
        _clearPickupRoute();
      }
      if (reqId != null) {
        passengerLocations.remove(reqId);
        _resetCheckIn(reqId);
      }
      loadRequests();
    } else if (type == 'ride_response') {
      final reqId = p['request_id'] as String?;
      final name = p['passenger_name'] as String?;
      final avg = (p['passenger_avg_rating'] as num?)?.toDouble();
      final count = (p['passenger_rating_count'] as num?)?.toInt();
      if (reqId != null) {
        passengerInfo[reqId] = PassengerMatchInfo(
          name: name,
          avgRating: avg,
          ratingCount: count,
        );
      }
      if (p['status'] == 'accepted' && reqId != null) {
        acceptedRequestId = reqId;
        acceptedPassengerName = name;
        acceptedPassengerAvgRating = avg;
        acceptedPassengerRatingCount = count;
        final loc = passengerLocations[reqId];
        if (loc != null) {
          _maybeRefreshPickupRoute(reqId, LatLng(loc.lat, loc.lng));
        }
      }
      loadRequests();
    } else if (type == 'passenger_request') {
      final reqId = p['request_id'] as String?;
      final info = PassengerMatchInfo(
        name: p['passenger_name'] as String?,
        avgRating: (p['passenger_avg_rating'] as num?)?.toDouble(),
        ratingCount: (p['passenger_rating_count'] as num?)?.toInt(),
      );
      if (reqId != null) {
        passengerInfo[reqId] = info;
      }
      _incomingRequests.add(info);
      loadRequests();
    } else if (type == 'passenger_location') {
      final reqId = p['request_id'] as String?;
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (reqId != null && lat != null && lng != null) {
        // PeerLatLng stamps arrival time itself — the relay carries no
        // timestamp, and arrival is what "how current is this" means here.
        passengerLocations[reqId] = PeerLatLng(lat, lng);
        _evaluateCheckIn();
        notifyListeners();
        if (reqId == acceptedRequestId) {
          _maybeRefreshPickupRoute(reqId, LatLng(lat, lng));
        }
      }
    } else if (type == 'ride_done') {
      final reqId = p['request_id'] as String?;
      final passengerID = p['passenger_id'] as String?;
      if (reqId != null) {
        pendingRatingRequestId = reqId;
        pendingRatingPassengerId = passengerID;
        // Per-passenger drop-off arrived — surgically remove just this ride.
        // Other passengers (in_progress on the same vehicle) and the active
        // route stay. End-of-day cleanup is handled by endRoute below.
        _surgicalRemoveRide(reqId);
      }
    } else if (type == 'pickup_confirmed') {
      final reqId = p['request_id'] as String?;
      if (reqId != null) {
        requests = [
          for (final r in requests)
            r.id == reqId ? r.copyWith(status: 'in_progress') : r,
        ];
        notifyListeners();
      }
    } else if (type == 'rating_submitted') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == awaitingRatingRequestId) {
        clearAwaitingRating();
      }
    } else if (type == 'corridor_stats') {
      candidatesFound = (p['candidates_found'] as num?)?.toInt() ?? 0;
      activePendingCount = (p['active_pending_count'] as num?)?.toInt() ?? 0;
      totalNotified =
          (p['total_notified'] as num?)?.toInt() ?? totalNotified;
      notifyListeners();
    } else if (type == 'chat_message') {
      unreadMessages++;
      notifyListeners();
    }
  }

  Future<void> setRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double corridorKm,
    required int seats,
    bool preferAI = false,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    // Custom trace around the heaviest matching call the client can observe:
    // the backend runs the full corridor match inside POST /driver/route.
    // Trace failures are swallowed — perf tooling must never break the flow.
    final trace = FirebasePerformance.instance.newTrace('ride_matching');
    try {
      await trace.start();
    } catch (_) {}
    try {
      activeRoute = await _repo.setRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        corridorKm: corridorKm,
        seats: seats,
        preferAI: preferAI,
      );
      try {
        trace.setMetric('notified', activeRoute?.notifiedCount ?? 0);
        trace.putAttribute(
            'distance_km', (activeRoute?.distanceKm ?? 0).toStringAsFixed(1));
      } catch (_) {}
      // Seed the live counters from the route-set response; the
      // corridor_stats WS event that follows carries the authoritative
      // cumulative value and overwrites this.
      totalNotified = activeRoute?.notifiedCount ?? 0;
      candidatesFound = totalNotified;
      activePendingCount = 0;
      destinationPos = LatLng(destLat, destLng);
      // Keep the position flowing once the screen goes off. The in-app timer
      // still covers the foreground; if the service can't start, warn the
      // driver rather than let them vanish from matching unnoticed.
      if (!await LocationService.start() && !_disposed) {
        _backgroundLocationFailed.add(null);
      }
      await loadRequests();
    } catch (e) {
      error = e.toString();
    } finally {
      try {
        await trace.stop();
      } catch (_) {}
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRequests() async {
    try {
      requests = await _repo.getRequests();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> respondToRequest(String requestId,
      {required bool accepted}) async {
    // Tactile cue fires at function entry so user feels feedback the
    // instant they tap Accept/Decline — before the network round-trip.
    if (accepted) {
      Haptics.confirm();
    } else {
      Haptics.tap();
    }
    try {
      await _repo.respond(
        requestId: requestId,
        status: accepted ? 'accepted' : 'declined',
      );
      if (accepted) {
        // Seat is actually reserved backend-side on this accept.
        Analytics.logEvent('seat_claimed', {'role': 'driver'});
        final info = passengerInfo[requestId];
        acceptedRequestId = requestId;
        acceptedPassengerName = info?.name;
        acceptedPassengerAvgRating = info?.avgRating;
        acceptedPassengerRatingCount = info?.ratingCount;
        final loc = passengerLocations[requestId];
        if (loc != null) {
          _maybeRefreshPickupRoute(requestId, LatLng(loc.lat, loc.lng));
        }
      } else {
        passengerInfo.remove(requestId);
        passengerLocations.remove(requestId);
      }
      await loadRequests();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearUnread() {
    unreadMessages = 0;
    notifyListeners();
  }

  Future<void> cancelRide(String requestId) async {
    Haptics.tap();
    try {
      await _repo.cancelRide(requestId);
      acceptedRequestId = null;
      acceptedPassengerName = null;
      acceptedPassengerAvgRating = null;
      acceptedPassengerRatingCount = null;
      passengerInfo.remove(requestId);
      passengerLocations.remove(requestId);
      _clearPickupRoute();
      await loadRequests();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> completeRide(double distanceKm) async {
    try {
      await _repo.updateStatus('done', distanceKm: distanceKm);
      _localCleanupOnDone();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void _localCleanupOnDone() {
    // Driving day over — stop the background location service. Leaving it
    // running would keep an ongoing notification up and drain battery for a
    // driver who is no longer offering rides.
    LocationService.stop();
    acceptedRequestId = null;
    acceptedPassengerName = null;
    acceptedPassengerAvgRating = null;
    acceptedPassengerRatingCount = null;
    passengerInfo.clear();
    passengerLocations.clear();
    _resetAllCheckIns();
    requests = [];
    activeRoute = null;
    destinationPos = null;
    _clearPickupRoute();
    unreadMessages = 0;
    totalNotified = 0;
    candidatesFound = 0;
    activePendingCount = 0;
    notifyListeners();
  }

  // Drops a single ride from local state without touching the active route or
  // the driver's other passengers. Used by the per-passenger ride_done handler.
  void _surgicalRemoveRide(String requestId) {
    requests = requests.where((r) => r.id != requestId).toList();
    passengerInfo.remove(requestId);
    passengerLocations.remove(requestId);
    _resetCheckIn(requestId);
    if (acceptedRequestId == requestId) {
      // Promote whoever's left to the singleton "current accepted" slot so
      // the SnackBar/_lastNotifiedRequestId logic in driver_home_screen
      // keeps working without a deeper refactor.
      final next = requests
          .where((r) => r.status == 'accepted' || r.status == 'in_progress')
          .toList();
      if (next.isEmpty) {
        acceptedRequestId = null;
        acceptedPassengerName = null;
        acceptedPassengerAvgRating = null;
        acceptedPassengerRatingCount = null;
        _clearPickupRoute();
      } else {
        final r = next.last;
        acceptedRequestId = r.id;
        acceptedPassengerName = r.passengerName;
        acceptedPassengerAvgRating = r.passengerAvgRating;
        acceptedPassengerRatingCount = r.passengerRatingCount;
      }
    }
    notifyListeners();
  }

  Future<bool> confirmPickup(String requestId, String code) async {
    try {
      await _repo.confirmPickup(requestId: requestId, code: code);
      // Optimistically flip local state; the WS confirm event will land too.
      requests = [
        for (final r in requests)
          r.id == requestId ? r.copyWith(status: 'in_progress') : r,
      ];
      notifyListeners();
      Haptics.confirm();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      Haptics.reject();
      return false;
    }
  }

  Future<bool> dropoff(String requestId, {double distanceKm = 0}) async {
    try {
      await _repo.dropoff(requestId: requestId, distanceKm: distanceKm);
      // The ride_done WS event will arrive and trigger _surgicalRemoveRide
      // and the rating sheet — no local optimistic patch needed here.
      Haptics.confirm();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      Haptics.reject();
      return false;
    }
  }

  void _clearPickupRoute() {
    pickupRoute = null;
    _lastPickupComputedAt = null;
    _lastPickupComputeTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> deleteRoute() async {
    try {
      await _repo.deleteRoute();
      // No active route → nothing to stay visible for.
      await LocationService.stop();
      activeRoute = null;
      requests = [];
      acceptedRequestId = null;
      acceptedPassengerName = null;
      acceptedPassengerAvgRating = null;
      acceptedPassengerRatingCount = null;
      passengerInfo.clear();
      passengerLocations.clear();
      destinationPos = null;
      _clearPickupRoute();
      unreadMessages = 0;
      totalNotified = 0;
      candidatesFound = 0;
      activePendingCount = 0;
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    final now = DateTime.now();
    final newPos = LatLng(lat, lng);
    if (_lastMyPos != null) {
      final dtSec =
          now.difference(_lastMyPosTime).inMilliseconds / 1000.0;
      if (dtSec >= 5) {
        final km = geoDistanceKm(_lastMyPos!, newPos);
        final kmh = km / (dtSec / 3600.0);
        final clamped = kmh.clamp(5.0, 130.0);
        rollingAvgSpeedKmh = rollingAvgSpeedKmh == null
            ? clamped
            : (0.3 * clamped) + (0.7 * rollingAvgSpeedKmh!);
      }
    }
    _lastMyPos = newPos;
    _lastMyPosTime = now;
    // Before the round trip: this is our own GPS fix, and how current it is has
    // nothing to do with whether the POST succeeded.
    _evaluateCheckIn();
    try {
      await _repo.updateLocation(lat, lng);
      if (locationSyncFailing) {
        _locationFailures = 0;
        locationSyncFailing = false;
        notifyListeners();
      }
    } catch (_) {
      // Never silent past a few in a row. The backend drops a driver from
      // matching once their last fix ages out, so persistently failing pings
      // mean the driver is invisible to passengers while their UI still looks
      // perfectly normal — the single most confusing failure mode in the app.
      _locationFailures++;
      if (_locationFailures >= _locationFailureThreshold && !locationSyncFailing) {
        locationSyncFailing = true;
        notifyListeners();
      }
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  /// Stops listening to the shared WebSocket without closing it. See
  /// [PassengerProvider.detachWS] — the socket belongs to both providers.
  void detachWS() {
    _wsSub?.cancel();
    _wsSub = null;
    _wsStateSub?.cancel();
    _wsStateSub = null;
  }

  @override
  void dispose() {
    _disposed = true;
    detachWS();
    _ratingWaitTimeout?.cancel();
    _incomingRequests.close();
    _backgroundLocationFailed.close();
    super.dispose();
  }
}
