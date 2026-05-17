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

  Future<void> goOffline() async {
    await _api.delete('/passenger/active', auth: true);
  }
}
