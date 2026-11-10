// Two-party end-to-end ride against the local backend, shared by
// integration_test/two_device_ride_test.dart (runs on the emulator) and
// tool/ride_counterpart_test.dart (runs on the host). Start both at the same
// time with the same RUN id. The first side to register the driver account
// becomes the driver, the other the passenger. They only coordinate through
// the backend (WebSocket events, nearby-drivers and chat), like two phones.
//
// Flow: driver sets a real (OSRM) route in Kraków → passenger finds the
// driver via nearby-drivers, stands on the published route and requests
// (or accepts the corridor offer) → driver accepts → driver sends the pickup
// code over chat → passenger confirms it → driver drops off → both rate.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:sameway/core/websocket_client.dart';
import 'package:sameway/features/auth/auth_repository.dart';

const run = String.fromEnvironment('RUN', defaultValue: 'local');
const password = 'two-device-123';
const driverEmail = 'drv-$run@example.com';
const passengerEmail = 'pax-$run@example.com';
const driverName = 'Drv$run';
const carPlate = 'KR 2DEV';

// Kraków: Old Town → east. Real roads, routed by the backend's OSRM.
const origin = (lat: 50.0614, lng: 19.9383);
const destination = (lat: 50.0700, lng: 19.9950);

const waitLong = Duration(minutes: 3);

/// Buffers every WebSocket frame so a step can wait for an event that may
/// already have arrived.
class Inbox {
  Inbox(WebSocketClient ws) {
    _sub = ws.messages.listen(_frames.add);
  }
  final _frames = <Map<String, dynamic>>[];
  late final StreamSubscription<Map<String, dynamic>> _sub;

  Future<Map<String, dynamic>> next(String type,
      {bool Function(Map<String, dynamic> p)? where,
      Duration timeout = waitLong}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (var i = 0; i < _frames.length; i++) {
        final f = _frames[i];
        if (f['type'] != type) continue;
        final p = (f['payload'] as Map?)?.cast<String, dynamic>() ?? {};
        if (where == null || where(p)) {
          _frames.removeAt(i);
          return p;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw TimeoutException('no "$type" event within $timeout');
  }

  Future<void> close() => _sub.cancel();
}

/// Optional: 'passenger' makes this side skip the race for the driver role
/// (so the other side is the driver). Empty = first to register drives.
const forcedRole = String.fromEnvironment('ROLE');

/// Defines the ride test. The caller sets up the binding first. [secure]
/// replaces the Keystore-backed token store (the host has none).
void rideTest({SecretStore secure = const PlatformSecretStore()}) {
  final storage = TokenStorage(secure: secure);
  final api = ApiClient(storage);
  final repo = AuthRepository(api);

  test('two devices complete a ride through the backend', () async {
    await storage.clear();
    // Claim the driver role; the second device gets 409 and is the passenger.
    AuthResult me;
    var isDriver = forcedRole != 'passenger';
    try {
      if (!isDriver) throw const ApiException('passenger by ROLE', statusCode: 409);
      me = await repo.register(
        name: driverName, email: driverEmail, password: password,
        role: 'driver', acceptTerms: true, ageConfirmed: true,
        birthDate: DateTime(1990, 1, 1),
      );
    } on ApiException catch (e) {
      expect(e.statusCode, 409, reason: 'unexpected register failure: $e');
      isDriver = false;
      me = await repo.register(
        name: 'Pax$run', email: passengerEmail, password: password,
        role: 'passenger', acceptTerms: true, ageConfirmed: true,
        birthDate: DateTime(1990, 1, 1),
      );
    }
    await storage.save(token: me.token, role: me.role, userId: me.userId);
    // ignore: avoid_print
    print('TWO-DEVICE role=${isDriver ? 'driver' : 'passenger'} run=$run');

    final ws = WebSocketClient();
    final inbox = Inbox(ws);
    final connected = ws.state.firstWhere((s) => s == WsState.connected);
    ws.connect(me.token);
    await connected.timeout(const Duration(seconds: 15));

    try {
      if (isDriver) {
        await _driver(api, inbox);
      } else {
        await _passenger(api, inbox);
      }
    } finally {
      await inbox.close();
      ws.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _driver(ApiClient api, Inbox inbox) async {
  await api.put('/auth/profile', {
    'car_make': 'Skoda', 'car_model': 'Octavia', 'car_color': 'Grey',
    'car_plate': carPlate,
  }, auth: true);
  await api.post('/auth/driver-declaration', {
    'licence': true, 'insurance': true, 'roadworthy': true, 'cost_sharing': true,
  }, auth: true);
  await api.post('/driver/route', {
    'origin_lat': origin.lat, 'origin_lng': origin.lng,
    'destination_lat': destination.lat, 'destination_lng': destination.lng,
    'corridor_km': 1.0, 'seats': 2,
  }, auth: true);

  // Parked at the start; keep the position fresh like the app's 10 s timer.
  Future<void> ping() => api.put(
      '/driver/location', {'lat': origin.lat, 'lng': origin.lng},
      auth: true);
  await ping();
  final pinger = Timer.periodic(const Duration(seconds: 15), (_) => ping());

  try {
    final request = await inbox.next('passenger_request');
    final requestId = request['request_id'] as String;
    final passengerId = request['passenger_id'] as String;
    // Privacy: before accepting, the driver sees a first name only.
    expect(request['passenger_name'], 'Pax$run');

    final accept = await api.post('/driver/respond',
        {'request_id': requestId, 'status': 'accepted'}, auth: true);
    final code = accept['pickup_code'] as String;
    expect(code, matches(RegExp(r'^\d{4}$')));

    // "Tell the passenger the code" — over the in-app chat.
    final conv = await api.post('/chat/conversations', {'peer_id': passengerId},
        auth: true);
    await api.post('/chat/send', {
      'conversation_id': conv['conversation_id'],
      'content': 'Pickup code: $code',
    }, auth: true);

    await inbox.next('pickup_confirmed',
        where: (p) => p['request_id'] == requestId);
    await api.post('/driver/dropoff/$requestId', {'distance_km': 4.0},
        auth: true);
    await inbox.next('ride_done', where: (p) => p['request_id'] == requestId);
    await api.post('/ratings', {
      'rated_id': passengerId, 'ride_request_id': requestId, 'stars': 5,
      'comment': 'two-device test',
    }, auth: true);
  } finally {
    pinger.cancel();
    await api.delete('/driver/route', auth: true);
  }
}

Future<void> _passenger(ApiClient api, Inbox inbox) async {
  // Start near the driver's origin so nearby-drivers finds them.
  await api.put('/passenger/location',
      {'lat': origin.lat + 0.002, 'lng': origin.lng}, auth: true);

  Map<String, dynamic>? driver;
  final deadline = DateTime.now().add(waitLong);
  while (driver == null && DateTime.now().isBefore(deadline)) {
    final list = await api.postRaw('/passenger/nearby-drivers', {
      'latitude': origin.lat + 0.002, 'longitude': origin.lng,
      'radius_km': 10,
    }, auth: true) as List;
    for (final d in list.cast<Map>()) {
      if (d['driver_name'] == driverName) {
        driver = d.cast<String, dynamic>();
      }
    }
    if (driver == null) await Future<void>.delayed(const Duration(seconds: 3));
  }
  expect(driver, isNotNull, reason: 'driver never appeared in nearby-drivers');
  final driverId = driver!['driver_id'] as String;
  // Privacy: no plate before a ride is accepted.
  expect(driver.containsKey('car_plate'), isFalse);

  // Stand on the driver's published route, half way along.
  final pts = RegExp(r'(-?\d+\.?\d*) (-?\d+\.?\d*)')
      .allMatches(driver['route_wkt'] as String)
      .map((m) => (lng: double.parse(m[1]!), lat: double.parse(m[2]!)))
      .toList();
  expect(pts.length, greaterThan(1));
  final spot = pts[pts.length ~/ 2];
  await api.put('/passenger/location', {'lat': spot.lat, 'lng': spot.lng},
      auth: true);

  // The corridor push may offer this ride on its own; otherwise ask for it.
  String requestId;
  try {
    final offer = await inbox.next('ride_request',
        timeout: const Duration(seconds: 6));
    requestId = offer['request_id'] as String;
    await api.post('/passenger/respond',
        {'request_id': requestId, 'status': 'accepted'}, auth: true);
  } on TimeoutException {
    final res = await api.post('/passenger/request-driver',
        {'driver_id': driverId}, auth: true);
    requestId = res['request_id'] as String;
  }

  final response = await inbox.next('driver_response',
      where: (p) => p['request_id'] == requestId);
  expect(response['status'], 'accepted');
  // Once accepted the passenger needs the plate to find the car.
  expect(response['car_plate'], carPlate);
  // Age is shared once the ride is agreed (never before).
  expect(response['driver_age'], isA<int>());

  final msg = await inbox.next('chat_message');
  final code = RegExp(r'\b\d{4}\b').firstMatch(msg['content'] as String)![0]!;
  final confirm = await api.post('/pickup/confirm',
      {'request_id': requestId, 'code': code}, auth: true);
  expect(confirm['ok'], isTrue);

  await inbox.next('ride_done', where: (p) => p['request_id'] == requestId);
  await api.post('/ratings', {
    'rated_id': driverId, 'ride_request_id': requestId, 'stars': 5,
  }, auth: true);
}
