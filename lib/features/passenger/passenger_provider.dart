import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/websocket_client.dart';
import 'passenger_repository.dart';

class RideOffer {
  final String requestId;
  final String driverId;
  final double destLat;
  final double destLng;
  final double corridorKm;
  final int seats;

  const RideOffer({
    required this.requestId,
    required this.driverId,
    required this.destLat,
    required this.destLng,
    required this.corridorKm,
    required this.seats,
  });
}

enum PassengerStatus { looking, offered, accepted, declined }

class PassengerProvider extends ChangeNotifier {
  final PassengerRepository _repo;
  final WebSocketClient _ws;

  PassengerStatus state = PassengerStatus.looking;
  RideOffer? pendingOffer;
  String? error;
  StreamSubscription? _wsSub;

  PassengerProvider(this._repo, this._ws);

  void connectWS(String token) {
    _ws.connect(token);
    _wsSub = _ws.messages.listen((msg) {
      if (msg['type'] == 'ride_request') {
        final p = msg['payload'] as Map<String, dynamic>;
        pendingOffer = RideOffer(
          requestId: p['request_id'] as String? ?? '',
          driverId: p['driver_id'] as String? ?? '',
          destLat: (p['destination_lat'] as num?)?.toDouble() ?? 0,
          destLng: (p['destination_lng'] as num?)?.toDouble() ?? 0,
          corridorKm: (p['corridor_km'] as num?)?.toDouble() ?? 0,
          seats: (p['seats'] as num?)?.toInt() ?? 0,
        );
        state = PassengerStatus.offered;
        notifyListeners();
      }
    });
  }

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await _repo.updateLocation(lat, lng);
    } catch (_) {}
  }

  Future<void> acceptRide() async {
    if (pendingOffer == null) return;
    try {
      await _repo.respond(
          requestId: pendingOffer!.requestId, status: 'accepted');
      state = PassengerStatus.accepted;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> declineRide() async {
    if (pendingOffer == null) return;
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
