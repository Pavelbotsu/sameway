import '../../core/api_client.dart';

class RideRequest {
  final String id;
  final String driverID;
  final String passengerID;
  final double pickupLat;
  final double pickupLng;
  final String status;
  // Joined from users + ratings on the backend so the driver UI never has to
  // fall back to "Passenger <uuid prefix>…" placeholder text.
  final String? passengerName;
  final String? passengerPhotoUrl;
  final double? passengerAvgRating;
  final int? passengerRatingCount;
  // Pickup-handshake fields. `pickupCode` is the shared 4-digit code (empty
  // until the row reaches 'accepted'); `pickedUpAt` is non-null once either
  // side confirms via POST /pickup/confirm.
  final String? pickupCode;
  final DateTime? pickedUpAt;
  // Server-stamped ranker tag — see services/ranker. "geometric" by default,
  // "ai-<model>" when AI re-ranked the candidate list, "geometric_fallback"
  // when AI was requested but failed. Null on payloads from older servers.
  final String? matchMethod;
  // Round 2 match labeling. detourAdded* are set only for micro_detour
  // requests: the driver's tile shows "adds ~X m / Y s" before they confirm
  // (the never-silent disclosure).
  final String? matchKind;
  final double? detourAddedM;
  final double? detourAddedS;
  // Where this passenger gets OUT and how far they ride, so the driver can
  // judge a pending request before accepting. Server-computed on read.
  //
  // This is the ON-ROUTE drop-off — the projection of the passenger's
  // destination onto the driver's existing route — not their true final
  // address. All three are null when the passenger declared no destination
  // (match_kind 'corridor_weak'), and on older servers.
  final double? dropoffLat;
  final double? dropoffLng;
  final double? carryM;

  /// True when accepting costs the driver no extra driving. Corridor and
  /// relay matches ride the existing route by construction; only micro_detour
  /// adds distance, and it discloses exactly how much via [detourAddedM].
  bool get isZeroDetour => matchKind != 'micro_detour';

  const RideRequest({
    required this.id,
    required this.driverID,
    required this.passengerID,
    required this.pickupLat,
    required this.pickupLng,
    required this.status,
    this.passengerName,
    this.passengerPhotoUrl,
    this.passengerAvgRating,
    this.passengerRatingCount,
    this.pickupCode,
    this.pickedUpAt,
    this.matchMethod,
    this.matchKind,
    this.detourAddedM,
    this.detourAddedS,
    this.dropoffLat,
    this.dropoffLng,
    this.carryM,
  });

  factory RideRequest.fromJson(Map<String, dynamic> j) => RideRequest(
        id: j['id'] as String,
        driverID: j['driver_id'] as String,
        passengerID: j['passenger_id'] as String,
        pickupLat: (j['pickup_lat'] as num).toDouble(),
        pickupLng: (j['pickup_lng'] as num).toDouble(),
        status: j['status'] as String,
        passengerName: j['passenger_name'] as String?,
        passengerPhotoUrl: j['passenger_photo_url'] as String?,
        passengerAvgRating:
            (j['passenger_avg_rating'] as num?)?.toDouble(),
        passengerRatingCount:
            (j['passenger_rating_count'] as num?)?.toInt(),
        pickupCode: (j['pickup_code'] as String?)?.trim().isEmpty == true
            ? null
            : j['pickup_code'] as String?,
        pickedUpAt: j['picked_up_at'] == null
            ? null
            : DateTime.tryParse(j['picked_up_at'] as String),
        matchMethod: j['match_method'] as String?,
        matchKind: j['match_kind'] as String?,
        detourAddedM: (j['detour_added_m'] as num?)?.toDouble(),
        detourAddedS: (j['detour_added_s'] as num?)?.toDouble(),
        dropoffLat: (j['dropoff_lat'] as num?)?.toDouble(),
        dropoffLng: (j['dropoff_lng'] as num?)?.toDouble(),
        carryM: (j['carry_m'] as num?)?.toDouble(),
      );

  RideRequest copyWith({
    String? status,
    String? pickupCode,
    DateTime? pickedUpAt,
    String? matchMethod,
  }) =>
      RideRequest(
        id: id,
        driverID: driverID,
        passengerID: passengerID,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        status: status ?? this.status,
        passengerName: passengerName,
        passengerPhotoUrl: passengerPhotoUrl,
        passengerAvgRating: passengerAvgRating,
        passengerRatingCount: passengerRatingCount,
        pickupCode: pickupCode ?? this.pickupCode,
        pickedUpAt: pickedUpAt ?? this.pickedUpAt,
        matchMethod: matchMethod ?? this.matchMethod,
        matchKind: matchKind,
        detourAddedM: detourAddedM,
        detourAddedS: detourAddedS,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        carryM: carryM,
      );

  /// True when this match was re-ranked by the AI layer. Used by UI badges
  /// to differentiate from the geometric default.
  bool get matchedByAI =>
      matchMethod != null && matchMethod!.startsWith('ai-');

  /// True when accepting means driving a small, disclosed detour.
  bool get isMicroDetour => matchKind == 'micro_detour';
}

class RouteResult {
  final String routeWkt;
  final double distanceKm;
  final int notifiedCount;

  RouteResult.fromJson(Map<String, dynamic> j)
      : routeWkt = j['route_wkt'] as String,
        distanceKm = (j['distance_km'] as num).toDouble(),
        notifiedCount = (j['notified_count'] as num).toInt();
}

class PickupRoute {
  final String pickupWkt;
  final double pickupDistanceKm;
  final String continuationWkt;
  final double continuationDistanceKm;
  // Walking leg from the passenger's actual position to the pickup point on
  // the driver's road. Populated for both driver and passenger consumers so
  // the mini-map can show all three legs.
  final String walkWkt;
  final double walkDistanceKm;

  PickupRoute.fromJson(Map<String, dynamic> j)
      : pickupWkt = (j['pickup_wkt'] as String?) ?? '',
        pickupDistanceKm =
            (j['pickup_distance_km'] as num?)?.toDouble() ?? 0,
        continuationWkt = (j['continuation_wkt'] as String?) ?? '',
        continuationDistanceKm =
            (j['continuation_distance_km'] as num?)?.toDouble() ?? 0,
        walkWkt = (j['walk_wkt'] as String?) ?? '',
        walkDistanceKm =
            (j['walk_distance_km'] as num?)?.toDouble() ?? 0;

  bool get isEmpty =>
      pickupWkt.isEmpty && continuationWkt.isEmpty && walkWkt.isEmpty;
}

class DriverRepository {
  final ApiClient _api;
  DriverRepository(this._api);

  Future<RouteResult> setRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double corridorKm,
    required int seats,
    bool preferAI = false,
  }) async {
    final data = await _api.post(
      '/driver/route',
      {
        'origin_lat': originLat,
        'origin_lng': originLng,
        'destination_lat': destLat,
        'destination_lng': destLng,
        'corridor_km': corridorKm,
        'seats': seats,
        'prefer_ai': preferAI,
      },
      auth: true,
    );
    return RouteResult.fromJson(data);
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _api.put('/driver/location', {'lat': lat, 'lng': lng}, auth: true);
  }

  Future<List<RideRequest>> getRequests() async {
    final data = await _api.get('/driver/requests', auth: true);
    return (data as List)
        .map((e) => RideRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus(String status, {double distanceKm = 0}) async {
    await _api.put('/driver/status',
        {'status': status, 'distance_km': distanceKm}, auth: true);
  }

  Future<void> cancelRide(String requestId) async {
    await _api.delete('/driver/ride/$requestId', auth: true);
  }

  /// New pickup code after a lockout (5 wrong tries); returns the code.
  Future<String> regeneratePickupCode(String requestId) async {
    final data = await _api.post(
        '/driver/pickup-code/$requestId/regenerate', {}, auth: true);
    return data['pickup_code'] as String;
  }

  /// Passenger never came. Throws ApiException code `no_show_too_early`
  /// (with waitSeconds) when reported before the wait is over.
  Future<void> reportNoShow(String requestId) async {
    await _api.post('/driver/no-show/$requestId', {}, auth: true);
  }

  Future<void> deleteRoute() async {
    await _api.delete('/driver/route', auth: true);
  }

  Future<void> respond({
    required String requestId,
    required String status,
  }) async {
    await _api.post(
      '/driver/respond',
      {'request_id': requestId, 'status': status},
      auth: true,
    );
  }

  Future<PickupRoute> getPickupRoute(String requestId) async {
    // Now lives at /pickup-route/:id under participant auth — works for both
    // driver and passenger of the row.
    final data = await _api.get('/pickup-route/$requestId', auth: true);
    return PickupRoute.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> confirmPickup({
    required String requestId,
    required String code,
  }) {
    return _api.post(
      '/pickup/confirm',
      {'request_id': requestId, 'code': code},
      auth: true,
    );
  }

  Future<void> dropoff({
    required String requestId,
    double distanceKm = 0,
  }) async {
    await _api.post(
      '/driver/dropoff/$requestId',
      {'distance_km': distanceKm},
      auth: true,
    );
  }

  /// Records a "something is wrong" answer to the mid-ride check-in. The route
  /// is role-agnostic (either party may flag) and the handler enforces
  /// participant-of-the-row.
  Future<void> flagSafety({
    required String requestId,
    required String reason,
  }) async {
    await _api.post(
      '/safety/flag',
      {'request_id': requestId, 'reason': reason},
      auth: true,
    );
  }
}
