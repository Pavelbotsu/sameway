import '../../core/api_client.dart';

class PassengerRepository {
  final ApiClient _api;
  PassengerRepository(this._api);

  Future<void> updateLocation(double lat, double lng) async {
    await _api.put(
      '/passenger/location',
      {'lat': lat, 'lng': lng},
      auth: true,
    );
  }

  Future<void> respond({
    required String requestId,
    required String status,
  }) async {
    await _api.post(
      '/passenger/respond',
      {'request_id': requestId, 'status': status},
      auth: true,
    );
  }

  Future<void> cancelRide(String requestId) async {
    await _api.delete('/passenger/ride/$requestId', auth: true);
  }

  Future<void> goOffline() async {
    await _api.delete('/passenger/active', auth: true);
  }

  Future<Map<String, dynamic>> search({
    required double destLat,
    required double destLng,
  }) {
    return _api.post(
      '/passenger/search',
      {'dest_lat': destLat, 'dest_lng': destLng},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> requestDriver(String driverId) async {
    return _api.post(
      '/passenger/request-driver',
      {'driver_id': driverId},
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final data = await _api.get('/passenger/my-requests', auth: true);
    if (data is! List) return const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> cancelOutstandingRequest(String requestId) async {
    await _api.delete('/passenger/request/$requestId', auth: true);
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
}
