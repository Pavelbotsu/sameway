import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/geo.dart';
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
  const PeerLatLng(this.lat, this.lng);
}

class DriverProvider extends ChangeNotifier {
  final DriverRepository _repo;
  final WebSocketClient _ws;

  RouteResult? activeRoute;
  List<RideRequest> requests = [];
  bool isLoading = false;
  String? error;
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

  StreamSubscription? _wsSub;
  StreamSubscription? _wsStateSub;

  DriverProvider(this._repo, this._ws);

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
        passengerLocations[reqId] = PeerLatLng(lat, lng);
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
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      activeRoute = await _repo.setRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        corridorKm: corridorKm,
        seats: seats,
      );
      destinationPos = LatLng(destLat, destLng);
      await loadRequests();
    } catch (e) {
      error = e.toString();
    } finally {
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
    try {
      await _repo.respond(
        requestId: requestId,
        status: accepted ? 'accepted' : 'declined',
      );
      if (accepted) {
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
    acceptedRequestId = null;
    acceptedPassengerName = null;
    acceptedPassengerAvgRating = null;
    acceptedPassengerRatingCount = null;
    passengerInfo.clear();
    passengerLocations.clear();
    requests = [];
    activeRoute = null;
    destinationPos = null;
    _clearPickupRoute();
    unreadMessages = 0;
    notifyListeners();
  }

  // Drops a single ride from local state without touching the active route or
  // the driver's other passengers. Used by the per-passenger ride_done handler.
  void _surgicalRemoveRide(String requestId) {
    requests = requests.where((r) => r.id != requestId).toList();
    passengerInfo.remove(requestId);
    passengerLocations.remove(requestId);
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
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> dropoff(String requestId, {double distanceKm = 0}) async {
    try {
      await _repo.dropoff(requestId: requestId, distanceKm: distanceKm);
      // The ride_done WS event will arrive and trigger _surgicalRemoveRide
      // and the rating sheet — no local optimistic patch needed here.
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
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
    try {
      await _repo.updateLocation(lat, lng);
    } catch (_) {}
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsStateSub?.cancel();
    _ratingWaitTimeout?.cancel();
    _incomingRequests.close();
    _ws.disconnect();
    super.dispose();
  }
}
