import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/haptics.dart';
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
  });

  bool get matchedByAI =>
      matchMethod != null && matchMethod!.startsWith('ai-');

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
  final String status; // 'pending' | 'accepted'
  final DateTime createdAt;

  const OutstandingRequest({
    required this.requestId,
    required this.driverId,
    required this.status,
    required this.createdAt,
    this.driverName,
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

class PassengerProvider extends ChangeNotifier {
  final PassengerRepository _repo;
  final WebSocketClient _ws;

  PassengerStatus state = PassengerStatus.looking;
  RideOffer? pendingOffer;
  String? acceptedRequestId;
  String? acceptedDriverId;
  String? acceptedDriverName;
  double? acceptedDriverAvgRating;
  int? acceptedDriverRatingCount;
  String? acceptedCarSummary;
  // License plate broken out so the AcceptedCard can render it on a plate
  // chip (Phase 1.1) — distinct from carSummary which mixes color/make/model.
  String? acceptedCarPlate;
  // Driver's profile photo URL — populated by accept WS / acceptRide so the
  // AcceptedCard can render the same UserAvatar (Phase 1.3c).
  String? acceptedDriverPhotoUrl;
  // Pickup handshake: the 4-digit code the server attached to this ride.
  // Cleared on entering inRide/looking; populated from the driver_response WS
  // payload or from /passenger/my-requests on reconnect.
  String? acceptedPickupCode;
  double? peerLat;
  double? peerLng;
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
      acceptedPickupCode = null;
      pendingOffer = null;
      peerLat = null;
      peerLng = null;
      state = PassengerStatus.looking;
      notifyListeners();
    } else if (type == 'ride_cancelled') {
      acceptedRequestId = null;
      acceptedDriverId = null;
      acceptedPickupCode = null;
      pendingOffer = null;
      peerLat = null;
      peerLng = null;
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
      );
      state = PassengerStatus.offered;
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
        final code = (p['pickup_code'] as String?)?.trim();
        acceptedPickupCode = (code == null || code.isEmpty) ? null : code;
        // Pickup geometry carried on the driver_response payload — used by
        // the mini-map to render the flag marker + walk leg before the
        // road-route fetch returns.
        pickupLat = (p['pickup_lat'] as num?)?.toDouble();
        pickupLng = (p['pickup_lng'] as num?)?.toDouble();
        walkDistanceM = (p['walk_distance_m'] as num?)?.toDouble();
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
        notifyListeners();
      }
    } else if (type == 'pickup_confirmed') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == acceptedRequestId) {
        state = PassengerStatus.inRide;
        acceptedPickupCode = null; // No longer needed; ride is in progress.
        notifyListeners();
      }
    } else if (type == 'rating_submitted') {
      final reqId = p['request_id'] as String?;
      if (reqId != null && reqId == awaitingRatingRequestId) {
        clearAwaitingRating();
      }
    }
  }

  Future<bool> confirmPickup(String code) async {
    final reqId = acceptedRequestId;
    if (reqId == null) return false;
    try {
      await _repo.confirmPickup(requestId: reqId, code: code);
      // Optimistic local flip — the WS event will land too and is a no-op.
      state = PassengerStatus.inRide;
      acceptedPickupCode = null;
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

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await _repo.updateLocation(lat, lng);
    } catch (_) {}
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

  Future<void> acceptRide() async {
    if (pendingOffer == null) return;
    Haptics.confirm();
    try {
      await _repo.respond(
          requestId: pendingOffer!.requestId, status: 'accepted');
      acceptedRequestId = pendingOffer!.requestId;
      acceptedDriverId = pendingOffer!.driverId;
      acceptedDriverName = pendingOffer!.driverName;
      acceptedDriverAvgRating = pendingOffer!.driverAvgRating;
      acceptedDriverRatingCount = pendingOffer!.driverRatingCount;
      acceptedCarSummary = pendingOffer!.carSummary;
      acceptedCarPlate = pendingOffer!.carPlate;
      acceptedDriverPhotoUrl = pendingOffer!.driverPhotoUrl;
      pickupLat = pendingOffer!.pickupLat;
      pickupLng = pendingOffer!.pickupLng;
      walkDistanceM = pendingOffer!.walkDistanceM;
      state = PassengerStatus.accepted;
      notifyListeners();
      _fetchPickupRoute(pendingOffer!.requestId);
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

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsStateSub?.cancel();
    _ratingWaitTimeout?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}
