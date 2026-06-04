import '../../core/api_client.dart';

class RideRequest {
  final String id;
  final String driverID;
  final String passengerID;
  final double pickupLat;
  final double pickupLng;
  final String status;

  RideRequest.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        driverID = j['driver_id'] as String,
        passengerID = j['passenger_id'] as String,
        pickupLat = (j['pickup_lat'] as num).toDouble(),
        pickupLng = (j['pickup_lng'] as num).toDouble(),
        status = j['status'] as String;
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
}
