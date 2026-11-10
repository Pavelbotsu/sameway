import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/analytics.dart';
import '../../core/api_client.dart' show ApiException;
import '../../core/haptics.dart';
import '../../core/ride_check_in.dart';
import '../../core/websocket_client.dart';
import '../driver/driver_repository.dart' show PickupRoute;
import 'passenger_repository.dart';

class RideOffer {
  final String requestId;
  final String driverId;
  final String? driverName;
  final String? driverPhotoUrl;
  final double? driverAvgRating;
  final int? driverRatingCount;
  final String? carMake;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  final double destLat;
  final double destLng;
  final double corridorKm;
  final int seats;
  // Heading-aware match payload (Tier 2). Pickup point lies on the driver's
  // road; walk/drive distances let the UI render an honest ETA.
  final double? pickupLat;
  final double? pickupLng;
  final double? walkDistanceM;
  final double? driverDistanceToPickupM;
  // Server-stamped ranker tag (see services/ranker on the backend). Null on
  // payloads from older servers.
  final String? matchMethod;
  // Round 2: labeled match kind — 'corridor' | 'corridor_weak' |
  // 'partial_relay' | 'micro_detour'. Null on payloads from older servers.
  final String? matchKind;
  // Partial relay: dropoff = the driver's route end the passenger rides to,
  // then continues by transit (stop name/distance) or a fresh search
  // (relayFallback). The passenger opts in BEFORE accepting.
  final double? dropoffLat;
  final double? dropoffLng;
  final String? transitStopName;
  final double? transitStopDistM;
  final bool relayFallback;
  // Micro-detour: the disclosed delta the driver accepts to come to you.
  final double? detourAddedM;
  final double? detourAddedS;

  const RideOffer({
    required this.requestId,
    required this.driverId,
    this.driverName,
    this.driverPhotoUrl,
    this.driverAvgRating,
    this.driverRatingCount,
    this.carMake,
    this.carModel,
    this.carColor,
    this.carPlate,
    required this.destLat,
    required this.destLng,
    required this.corridorKm,
    required this.seats,
    this.pickupLat,
    this.pickupLng,
    this.walkDistanceM,
    this.driverDistanceToPickupM,
    this.matchMethod,
    this.matchKind,
    this.dropoffLat,
    this.dropoffLng,
    this.transitStopName,
    this.transitStopDistM,
    this.relayFallback = false,
    this.detourAddedM,
    this.detourAddedS,
  });

  bool get matchedByAI =>
      matchMethod != null && matchMethod!.startsWith('ai-');
  bool get isPartialRelay => matchKind == 'partial_relay';
  bool get isMicroDetour => matchKind == 'micro_detour';

  String? get carSummary => _carSummary(carColor, carMake, carModel, carPlate);
}

class OutstandingRequest {
  final String requestId;
  final String driverId;
  final String? driverName;
  final double? driverAvgRating;
  final int? driverRatingCount;
  final String? carMake;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  /// Only sent once the ride is accepted.
  final int? driverAge;
  final String status; // 'pending' | 'accepted'
  final DateTime createdAt;

  const OutstandingRequest({
    required this.requestId,
    required this.driverId,
    required this.status,
    required this.createdAt,
    this.driverName,
    this.driverAge,
    this.driverAvgRating,
    this.driverRatingCount,
    this.carMake,
    this.carModel,
    this.carColor,
    this.carPlate,
  });

  factory OutstandingRequest.fromJson(Map<String, dynamic> j) {
    return OutstandingRequest(
      requestId: j['request_id'] as String,
      driverId: j['driver_id'] as String,
      status: (j['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      driverName: j['driver_name'] as String?,
      driverAge: (j['driver_age'] as num?)?.toInt(),
      driverAvgRating: (j['driver_avg_rating'] as num?)?.toDouble(),
      driverRatingCount: (j['driver_rating_count'] as num?)?.toInt(),
      carMake: j['car_make'] as String?,
      carModel: j['car_model'] as String?,
      carColor: j['car_color'] as String?,
      carPlate: j['car_plate'] as String?,
    );
  }

  String? get carSummary => _carSummary(carColor, carMake, carModel, carPlate);
}

String? _carSummary(String? color, String? make, String? model, String? plate) {
  final parts = <String>[];
  final headParts = [color ?? '', make ?? '', model ?? '']
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (headParts.isNotEmpty) parts.add(headParts.join(' '));
  final platePart = (plate ?? '').trim();
  if (platePart.isNotEmpty) parts.add(platePart);
  return parts.isEmpty ? null : parts.join(' · ');
}

enum PassengerStatus { looking, offered, accepted, inRide, declined }

/// One-off things the passenger should be told about (shown as snackbars by
/// the home screen). The ride state itself is already in [PassengerStatus].
enum PassengerNotice {
  /// The driver issued a new pickup code after a lockout.
  pickupCodeReset,
  /// The driver reported that the passenger didn't show up.
  cancelledNoShow,
  /// The accepted ride expired without a pickup.
  cancelledTimeout,
  /// The driver ended their route before the pickup.
  cancelledDriverEnded,
  /// The passenger's location is outside every service area.
  outsideServiceArea,
}

/// Outcome of submitting a pickup code.
class PickupAttempt {
  final bool ok;
  /// Wrong code; this many tries remain before the code locks.
  final int? attemptsLeft;
  /// Too many wrong codes — the driver must issue a new one.
  final bool locked;
  /// Any other failure (network, server), for friendlyError.
  final Object? error;
  const PickupAttempt._({this.ok = false, this.attemptsLeft, this.locked = false, this.error});
  static const success = PickupAttempt._(ok: true);
}

/// The passenger-facing match lifecycle (Round 2 §6):
///   searching → candidatesAvailable → offerReceived → requested → matched →
///   inProgress
/// Derived from existing signals ([PassengerStatus], the pending offer, the
/// outstanding-request list, and the likely-match count from the nearby
/// list) rather than stored — the backend already carries all of it.
enum MatchUiState {
  idle, // no destination set — not in the match flow at all
  searching,
  candidatesAvailable,
  offerReceived,
  requested,
  matched,
  inProgress,
}

class PassengerProvider extends ChangeNotifier {
  final PassengerRepository _repo;
  final WebSocketClient _ws;

  PassengerStatus state = PassengerStatus.looking;
  RideOffer? pendingOffer;
  String? acceptedRequestId;
  String? acceptedDriverId;
  String? acceptedDriverName;
  /// Driver's age, shared by the server only once the ride is accepted.
  int? acceptedDriverAge;
  double? acceptedDriverAvgRating;
  int? acceptedDriverRatingCount;
  String? acceptedCarSummary;
  // License plate broken out so the AcceptedCard can render it on a plate
  // chip (Phase 1.1) — distinct from carSummary which mixes color/make/model.
  String? acceptedCarPlate;
  // Driver's profile photo URL — populated by accept WS / acceptRide so the
  // AcceptedCard can render the same UserAvatar (Phase 1.3c).
  String? acceptedDriverPhotoUrl;
  double? peerLat;
  double? peerLng;
  // When the peer fix above arrived. Required by the mid-ride check-in: a stale
  // position is no evidence at all, so distance alone must never be trusted.
  DateTime? peerAt;

  // ── Mid-ride safety check-in ─────────────────────────────────────────────
  // Set true once per ride when this passenger and their driver have been
  // provably apart for ~30s while the ride is in_progress. The home screen
  // watches it and opens RideCheckInSheet. See core/ride_check_in.dart.
  bool checkInPrompt = false;
  LatLng? _selfPos;
  DateTime? _selfAt;
  final RideCheckInTracker _checkIn = RideCheckInTracker();

  void clearCheckInPrompt() {
    if (!checkInPrompt) return;
    checkInPrompt = false;
    notifyListeners();
  }

  /// Called wherever a ride ends, alongside the existing peer-location clears,
  /// so a streak or a "already asked" latch can never leak into the next ride.
  void _resetCheckIn() {
    _checkIn.reset();
    checkInPrompt = false;
  }

  /// Re-evaluates togetherness after either side's position moves. Only runs
  /// while in_progress — before pickup the two being apart is the normal case
  /// (that is the whole point of the walk-to-pickup leg).
  void _evaluateCheckIn() {
    if (state != PassengerStatus.inRide) {
      _checkIn.observe(null, CheckInVerdict.unknown);
      return;
    }
    final verdict = evaluateCheckIn(
      self: _selfPos,
      selfAt: _selfAt,
      peer: (peerLat != null && peerLng != null)
          ? LatLng(peerLat!, peerLng!)
          : null,
      peerAt: peerAt,
      now: DateTime.now(),
    );
    if (_checkIn.observe(acceptedRequestId, verdict)) {
      checkInPrompt = true;
      Analytics.logEvent('ride_check_in_prompted', {'role': 'passenger'});
      notifyListeners();
    }
  }

  /// Flags the ride server-side after a "something is wrong" answer. Never
  /// throws: the caller's next step is opening the SOS sheet, and a failed
  /// bookkeeping write must not stand between a frightened user and that.
  Future<void> flagSafety(String reason) async {
    final reqId = acceptedRequestId;
    if (reqId == null) return;
    try {
      await _repo.flagSafety(requestId: reqId, reason: reason);
    } catch (_) {/* best effort — SOS is the real escalation */}
  }
  // Pickup point — projection of the passenger onto the driver's road.
  // Surfaced when the WS `ride_request`/`driver_response` payload carries it
  // and used by the accepted card to render a flag marker + walk polyline.
  double? pickupLat;
  double? pickupLng;
  double? walkDistanceM;
  // Real road route for the mini-map. Fetched lazily on accept; null until
  // the GET completes or stays null on OSRM failure (UI falls back to a
  // straight line between driver and pickup point).
  PickupRoute? pickupRoute;
  List<OutstandingRequest> outstandingRequests = [];
  WsState wsState = WsState.disconnected;
  int unreadMessages = 0;
  String? error;
  String? pendingRatingRequestId;
  String? pendingRatingDriverId;
  String? awaitingRatingRequestId;
  Timer? _ratingWaitTimeout;

  LatLng? destinationPos;
  String? plannedRouteWkt;
  double? plannedDistanceKm;
  bool isSearching = false;

  // Count of nearby drivers the server flagged likely_match (same-way hint).
  // Fed by the home screen after each nearby-drivers fetch; drives the
  // candidatesAvailable UI state.
  int likelyMatchCount = 0;

  // True between a partial-relay dropoff (relay_leg2_search WS event) and
  // the next offer: the banner shows "looking for your next leg" instead of
  // the generic searching copy.
  bool relayLeg2Search = false;

  void setNearbyLikelyCount(int n) {
    if (likelyMatchCount == n) return;
    likelyMatchCount = n;
    notifyListeners();
  }

  /// Single source of truth for the match-state banner. Priority order runs
  /// from "furthest along" backwards so a stale lower state never masks a
  /// live ride.
  MatchUiState get matchUiState {
    if (state == PassengerStatus.inRide) return MatchUiState.inProgress;
    if (state == PassengerStatus.accepted) return MatchUiState.matched;
    if (pendingOffer != null ||
        outstandingRequests.any((r) => r.status == 'offered')) {
      return MatchUiState.offerReceived;
    }
    if (outstandingRequests.any((r) => r.status == 'pending')) {
      return MatchUiState.requested;
    }
    if (!isSearching) return MatchUiState.idle;
    if (likelyMatchCount > 0) return MatchUiState.candidatesAvailable;
    return MatchUiState.searching;
  }

  Future<void> setSearchDestination(LatLng dest, {bool preferAI = false}) async {
    destinationPos = dest;
    isSearching = true;
    notifyListeners();
    try {
      final data = await _repo.search(
        destLat: dest.latitude,
        destLng: dest.longitude,
        preferAI: preferAI,
      );
      plannedRouteWkt = (data['route_wkt'] as String?) ?? '';
      plannedDistanceKm = (data['distance_km'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void clearSearchDestination() {
    destinationPos = null;
    plannedRouteWkt = null;
    plannedDistanceKm = null;
    isSearching = false;
    relayLeg2Search = false;
    notifyListeners();
  }
  StreamSubscription? _wsSub;
  StreamSubscription? _wsStateSub;

  void markAwaitingDriverRating(String requestId) {
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

  PassengerProvider(this._repo, this._ws);

  // Several paths call notifyListeners() after an await — declineRide waits two
  // seconds before clearing the banner, _fetchPickupRoute waits on the network.
  // If the user logs out or switches role in that window the provider is gone,
  // and notifyListeners() on a disposed ChangeNotifier throws. That lands in
  // PlatformDispatcher.onError, which main.dart reports to Crashlytics as
  // FATAL — a crash report for what is really just a late callback.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  void connectWS(String token) {
    _ws.connect(token);
    _wsStateSub ??= _ws.state.listen((s) {
      wsState = s;
      notifyListeners();
      if (s == WsState.connected) {
        // Re-sync outstanding state on (re)connect so the UI catches anything
        // that happened while we were offline.
        loadOutstandingRequests();
      }
    });
    _wsSub ??= _ws.messages.listen(_onMessage);
    // Initial load (in case state stream doesn't fire 'connected' before first frame).
    loadOutstandingRequests();
  }

  /// Feeds one WebSocket frame through the normal handler. Tests only.
  @visibleForTesting
  void handleMessageForTest(Map<String, dynamic> msg) => _onMessage(msg);

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final p = (msg['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

    if (type == 'chat_message') {
      unreadMessages++;
      notifyListeners();
    } else if (type == 'ride_done') {
      pendingRatingRequestId = p['request_id'] as String?;
      pendingRatingDriverId = p['driver_id'] as String?;
      acceptedRequestId = null;
      acceptedDriverId = null;
      pendingOffer = null;
      peerLat = null;
      peerLng = null;
      peerAt = null;
      _resetCheckIn();
      state = PassengerStatus.looking;
      notifyListeners();
    } else if (type == 'pickup_code_reset') {
      if (!_disposed) _notices.add(PassengerNotice.pickupCodeReset);
    } else if (type == 'ride_cancelled') {
      // The backend tags why: 'driver_passed' means the ETA-window logic
      // expired the match because the driver drove past the pickup.
      if (p['cancelled_by'] == 'driver_passed') {
        Analytics.logEvent('ride_expired_passed', {'role': 'passenger'});
      }
      final wasAccepted = p['request_id'] == acceptedRequestId;
      if (!_disposed && p['cancelled_by'] == 'no_show') {
        _notices.add(PassengerNotice.cancelledNoShow);
      } else if (!_disposed && wasAccepted && p['cancelled_by'] == 'timeout') {
        // Offers also time out silently; only an accepted ride is worth
        // telling the passenger about.
        _notices.add(PassengerNotice.cancelledTimeout);
      } else if (!_disposed && p['cancelled_by'] == 'driver_ended') {
        _notices.add(PassengerNotice.cancelledDriverEnded);
      }
      acceptedRequestId = null;
      acceptedDriverId = null;
      pendingOffer = null;
      peerLat = null;
      peerLng = null;
      peerAt = null;
      _resetCheckIn();
      state = PassengerStatus.looking;
      // Also drop any matching outstanding entry.
      final reqId = p['request_id'] as String?;
      if (reqId != null) {
        outstandingRequests =
            outstandingRequests.where((r) => r.requestId != reqId).toList();
      }
      notifyListeners();
    } else if (type == 'ride_request') {
      pendingOffer = RideOffer(
        driverPhotoUrl: p['driver_photo_url'] as String?,
        requestId: p['request_id'] as String? ?? '',
        driverId: p['driver_id'] as String? ?? '',
        driverName: p['driver_name'] as String?,
        driverAvgRating: (p['driver_avg_rating'] as num?)?.toDouble(),
        driverRatingCount: (p['driver_rating_count'] as num?)?.toInt(),
        carMake: p['car_make'] as String?,
        carModel: p['car_model'] as String?,
        carColor: p['car_color'] as String?,
        carPlate: p['car_plate'] as String?,
        destLat: (p['destination_lat'] as num?)?.toDouble() ?? 0,
        destLng: (p['destination_lng'] as num?)?.toDouble() ?? 0,
        corridorKm: (p['corridor_km'] as num?)?.toDouble() ?? 0,
        seats: (p['seats'] as num?)?.toInt() ?? 0,
        pickupLat: (p['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (p['pickup_lng'] as num?)?.toDouble(),
        walkDistanceM: (p['walk_distance_m'] as num?)?.toDouble(),
        driverDistanceToPickupM:
            (p['driver_distance_to_pickup_m'] as num?)?.toDouble(),
        matchMethod: p['match_method'] as String?,
        matchKind: p['match_kind'] as String?,
        dropoffLat: (p['dropoff_lat'] as num?)?.toDouble(),
        dropoffLng: (p['dropoff_lng'] as num?)?.toDouble(),
        transitStopName: p['transit_stop_name'] as String?,
        transitStopDistM: (p['transit_stop_dist_m'] as num?)?.toDouble(),
        relayFallback: p['relay_fallback'] == true,
        detourAddedM: (p['detour_added_m'] as num?)?.toDouble(),
        detourAddedS: (p['detour_added_s'] as num?)?.toDouble(),
      );
      relayLeg2Search = false; // a concrete offer supersedes leg-2 waiting
      state = PassengerStatus.offered;
      notifyListeners();
    } else if (type == 'relay_leg2_search') {
      // Partial-relay dropoff: leg 1 done, we're now looking for the next
      // leg from here. Destination is still set server-side, so the search
      // continues; the banner switches to "looking for your next leg".
      relayLeg2Search = true;
      isSearching = true;
      Analytics.logEvent('relay_leg2_search_started', {'role': 'passenger'});
      notifyListeners();
    } else if (type == 'driver_response') {
      final reqId = p['request_id'] as String?;
      final status = p['status'] as String?;
      if (reqId == null) return;
      if (status == 'accepted') {
        // Promote this request to accepted, drop the rest from the list.
        acceptedRequestId = reqId;
        acceptedDriverId = p['driver_id'] as String?;
        acceptedDriverName = p['driver_name'] as String?;
        acceptedDriverAge = (p['driver_age'] as num?)?.toInt();
        acceptedDriverAvgRating = (p['driver_avg_rating'] as num?)?.toDouble();
        acceptedDriverRatingCount =
            (p['driver_rating_count'] as num?)?.toInt();
        acceptedCarSummary = _carSummary(
          p['car_color'] as String?,
          p['car_make'] as String?,
          p['car_model'] as String?,
          p['car_plate'] as String?,
        );
        acceptedCarPlate = (p['car_plate'] as String?)?.trim();
        acceptedDriverPhotoUrl = (p['driver_photo_url'] as String?)?.trim();
        // Pickup geometry: the corridor handshake stashed it from the offer at
        // accept time, so only overwrite when this payload actually carries it
        // — never null out a good value.
        pickupLat = (p['pickup_lat'] as num?)?.toDouble() ?? pickupLat;
        pickupLng = (p['pickup_lng'] as num?)?.toDouble() ?? pickupLng;
        walkDistanceM = (p['walk_distance_m'] as num?)?.toDouble() ?? walkDistanceM;
        outstandingRequests = const [];
        state = PassengerStatus.accepted;
        notifyListeners();
        _fetchPickupRoute(reqId);
      } else if (status == 'declined') {
        outstandingRequests =
            outstandingRequests.where((r) => r.requestId != reqId).toList();
        notifyListeners();
      }
    } else if (type == 'driver_location') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == acceptedRequestId) {
        peerLat = (p['lat'] as num?)?.toDouble();
        peerLng = (p['lng'] as num?)?.toDouble();
        // Stamped on arrival, not from the payload: the relay carries no
        // timestamp, and arrival time is what "how current is this" means here.
        peerAt = DateTime.now();
        _evaluateCheckIn();
        notifyListeners();
      }
    } else if (type == 'pickup_confirmed') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == acceptedRequestId) {
        state = PassengerStatus.inRide;
        notifyListeners();
      }
    } else if (type == 'rating_submitted') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == awaitingRatingRequestId) {
        clearAwaitingRating();
      }
    }
  }

  Future<PickupAttempt> confirmPickup(String code) async {
    final reqId = acceptedRequestId;
    if (reqId == null) return const PickupAttempt._(error: 'no accepted ride');
    try {
      await _repo.confirmPickup(requestId: reqId, code: code);
      // Optimistic local flip — the WS event will land too and is a no-op.
      state = PassengerStatus.inRide;
      notifyListeners();
      Haptics.confirm();
      return PickupAttempt.success;
    } on ApiException catch (e) {
      Haptics.reject();
      if (e.code == 'pickup_locked') return const PickupAttempt._(locked: true);
      if (e.code == 'wrong_code') {
        return PickupAttempt._(attemptsLeft: e.attemptsLeft);
      }
      return PickupAttempt._(error: e);
    } catch (e) {
      Haptics.reject();
      return PickupAttempt._(error: e);
    }
  }

  final _notices = StreamController<PassengerNotice>.broadcast();
  Stream<PassengerNotice> get notices => _notices.stream;

  /// True when several consecutive location pings have failed. A passenger
  /// whose location never reaches the server is invisible to the corridor
  /// match while their UI still says "searching".
  bool locationSyncFailing = false;
  int _locationFailures = 0;

  /// The server refuses the location because it is outside the service
  /// areas. Not a sync failure: the passenger is told once, not warned.
  bool outsideServiceArea = false;
  static const _locationFailureThreshold = 3;

  Future<void> updateLocation(double lat, double lng) async {
    // Recorded before the round trip: this is our own GPS fix, and its
    // freshness has nothing to do with whether the POST succeeded.
    _selfPos = LatLng(lat, lng);
    _selfAt = DateTime.now();
    _evaluateCheckIn();
    try {
      await _repo.updateLocation(lat, lng);
      outsideServiceArea = false;
      if (locationSyncFailing) {
        _locationFailures = 0;
        locationSyncFailing = false;
        notifyListeners();
      }
    } catch (e) {
      if (e is ApiException && e.code == 'outside_service_area') {
        if (!outsideServiceArea && !_disposed) {
          outsideServiceArea = true;
          _notices.add(PassengerNotice.outsideServiceArea);
          notifyListeners();
        }
        return;
      }
      _locationFailures++;
      if (_locationFailures >= _locationFailureThreshold && !locationSyncFailing) {
        locationSyncFailing = true;
        notifyListeners();
      }
    }
  }

  /// Nearby drivers for the map overlay. Thin pass-through so the screen goes
  /// through the repository (timeouts, 401 handling) instead of raw http.
  Future<List<Map<String, dynamic>>> nearbyDrivers({
    required double lat,
    required double lng,
    double? destLat,
    double? destLng,
  }) {
    return _repo.nearbyDrivers(
      lat: lat,
      lng: lng,
      destLat: destLat,
      destLng: destLng,
    );
  }

  /// Fetches match-advice (why am I not matching + tips). Best-effort; returns
  /// null on any error so the UI just hides the tips.
  Future<Map<String, dynamic>?> fetchMatchAdvice() async {
    try {
      return await _repo.matchAdvice();
    } catch (_) {
      return null;
    }
  }

  Future<void> loadOutstandingRequests() async {
    try {
      final raw = await _repo.getMyRequests();
      outstandingRequests =
          raw.map(OutstandingRequest.fromJson).toList(growable: false);
      // If the server reports an accepted row, hydrate the accepted UI from it.
      final accepted = outstandingRequests
          .where((r) => r.status == 'accepted')
          .toList(growable: false);
      if (accepted.isNotEmpty && acceptedRequestId == null) {
        final a = accepted.first;
        acceptedRequestId = a.requestId;
        acceptedDriverId = a.driverId;
        acceptedDriverName = a.driverName;
        acceptedDriverAge = a.driverAge;
        acceptedDriverAvgRating = a.driverAvgRating;
        acceptedDriverRatingCount = a.driverRatingCount;
        acceptedCarSummary = a.carSummary;
        state = PassengerStatus.accepted;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> sendRequestToDriver(String driverId) async {
    try {
      await _repo.requestDriver(driverId);
      // Logged only after the backend confirmed the request row exists.
      Analytics.logEvent('ride_request_created', {'role': 'passenger'});
      await loadOutstandingRequests();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelOutstandingRequest(String requestId) async {
    final prev = outstandingRequests;
    outstandingRequests =
        outstandingRequests.where((r) => r.requestId != requestId).toList();
    notifyListeners();
    try {
      await _repo.cancelOutstandingRequest(requestId);
    } catch (e) {
      // Roll back optimistic removal on failure.
      outstandingRequests = prev;
      error = e.toString();
      notifyListeners();
    }
  }

  // Accepting a driver's broadcast offer no longer confirms the ride — it only
  // *requests* it. The backend promotes the offer to 'pending' (awaiting the
  // driver's confirm) and notifies the driver. We drop back to the looking
  // state and surface the request in the "waiting for the driver" outstanding
  // list. The driver's confirm arrives as a driver_response(accepted) WS event,
  // which promotes us to the accepted state (see _onMessage).
  Future<void> acceptRide() async {
    if (pendingOffer == null) return;
    Haptics.confirm();
    try {
      await _repo.respond(
          requestId: pendingOffer!.requestId, status: 'accepted');
      // The offer came from the ETA-window corridor matching; accepting it
      // is the passenger-side "match accepted" moment (driver confirms later).
      Analytics.logEvent('match_accepted', {'role': 'passenger'});
      // Stash the offer's pickup geometry so it survives into the accepted
      // state — the driver's confirm event doesn't re-send it.
      pickupLat = pendingOffer!.pickupLat;
      pickupLng = pendingOffer!.pickupLng;
      walkDistanceM = pendingOffer!.walkDistanceM;
      pendingOffer = null;
      state = PassengerStatus.looking;
      notifyListeners();
      await loadOutstandingRequests();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Fetches the three-leg road route in the background and stores it on
  /// `pickupRoute`. Failure is silent — the mini-map falls back to a straight
  /// line if `pickupRoute` stays null.
  Future<void> _fetchPickupRoute(String requestId) async {
    try {
      final r = await _repo.getPickupRoute(requestId);
      if (acceptedRequestId != requestId) return; // user moved on
      pickupRoute = r.isEmpty ? null : r;
      notifyListeners();
    } catch (_) {/* silent — straight-line fallback */}
  }

  Future<void> cancelRide() async {
    if (acceptedRequestId == null) return;
    Haptics.tap();
    try {
      await _repo.cancelRide(acceptedRequestId!);
      acceptedRequestId = null;
      acceptedDriverId = null;
      pendingOffer = null;
      peerLat = null;
      peerLng = null;
      peerAt = null;
      _resetCheckIn();
      pickupLat = null;
      pickupLng = null;
      walkDistanceM = null;
      pickupRoute = null;
      state = PassengerStatus.looking;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> declineRide() async {
    if (pendingOffer == null) return;
    Haptics.tap();
    try {
      await _repo.respond(
          requestId: pendingOffer!.requestId, status: 'declined');
      pendingOffer = null;
      state = PassengerStatus.declined;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      state = PassengerStatus.looking;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> goOffline() async {
    try {
      await _repo.goOffline();
    } catch (_) {}
    clearSearchDestination();
  }

  void clearPendingRating() {
    pendingRatingRequestId = null;
    pendingRatingDriverId = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  /// Stops listening to the shared WebSocket without closing it.
  ///
  /// The socket is shared with [DriverProvider] (see main.dart), so a provider
  /// leaving the screen must NOT disconnect it — that would tear down the
  /// other role's event stream. It also must not keep listening: after a role
  /// switch both providers would otherwise stay subscribed and each handle
  /// every message, double-counting things like the unread-chat badge.
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
    _notices.close();
    super.dispose();
  }
}
