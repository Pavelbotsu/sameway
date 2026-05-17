import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/websocket_client.dart';
import 'driver_repository.dart';

class DriverProvider extends ChangeNotifier {
  final DriverRepository _repo;
  final WebSocketClient _ws;

  RouteResult? activeRoute;
  List<RideRequest> requests = [];
  bool isLoading = false;
  String? error;
  StreamSubscription? _wsSub;

  DriverProvider(this._repo, this._ws);

  void connectWS(String token) {
    _ws.connect(token);
    _wsSub = _ws.messages.listen((msg) {
      if (msg['type'] == 'ride_response') {
        loadRequests();
      }
    });
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

  Future<void> deleteRoute() async {
    try {
      await _repo.deleteRoute();
      activeRoute = null;
      requests = [];
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
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
    _ws.disconnect();
    super.dispose();
  }
}
