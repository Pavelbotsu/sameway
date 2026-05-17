import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/token_storage.dart';
import '../../core/widgets/glass_card.dart';
import '../auth/auth_provider.dart';
import '../onboarding/role_selection_screen.dart';
import 'driver_provider.dart';
import 'driver_repository.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _mapController = MapController();
  LatLng? _myPos;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocation();
      final token = await TokenStorage().getToken();
      if (token != null && mounted) {
        context.read<DriverProvider>().connectWS(token);
      }
      _locationTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _sendLocation());
    });
  }

  Future<void> _initLocation() async {
    try {
      final pos = await _determinePosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      _mapController.move(latlng, 14);
      await context.read<DriverProvider>().updateLocation(
            pos.latitude,
            pos.longitude,
          );
    } catch (_) {}
  }

  Future<void> _sendLocation() async {
    if (_myPos == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      await context
          .read<DriverProvider>()
          .updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<Position> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location disabled');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  void _showSetRouteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetRouteSheet(
        originPos: _myPos,
        onSubmit: (destLat, destLng, corridorKm, seats) {
          if (_myPos == null) return;
          context.read<DriverProvider>().setRoute(
                originLat: _myPos!.latitude,
                originLng: _myPos!.longitude,
                destLat: destLat,
                destLng: destLng,
                corridorKm: corridorKm,
                seats: seats,
              );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  List<LatLng> _parseWKT(String wkt) {
    try {
      final inner = wkt
          .replaceAll('LINESTRING(', '')
          .replaceAll('LINESTRING (', '')
          .replaceAll(')', '');
      return inner.split(',').map((pair) {
        final parts = pair.trim().split(' ');
        return LatLng(double.parse(parts[1]), double.parse(parts[0]));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Consumer<DriverProvider>(
            builder: (_, driver, __) {
              final routePoints = driver.activeRoute != null
                  ? _parseWKT(driver.activeRoute!.routeWkt)
                  : <LatLng>[];
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _myPos ?? const LatLng(50.0647, 19.9450),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.sameway',
                  ),
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: AppColors.primary,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (_myPos != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _myPos!,
                          width: 56,
                          height: 56,
                          child: _MyLocationMarker(color: AppColors.primary),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      borderRadius: 16,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.drive_eta_rounded,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Driver',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GlassCard(
                      padding: const EdgeInsets.all(10),
                      borderRadius: 14,
                      child: GestureDetector(
                        onTap: _logout,
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<DriverProvider>(
              builder: (_, driver, __) => _BottomPanel(
                driver: driver,
                onSetRoute: _showSetRouteSheet,
                onDeleteRoute: () => driver.deleteRoute(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final DriverProvider driver;
  final VoidCallback onSetRoute;
  final VoidCallback onDeleteRoute;
  const _BottomPanel({
    required this.driver,
    required this.onSetRoute,
    required this.onDeleteRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (driver.activeRoute != null) ...[
            _RouteActiveCard(
              route: driver.activeRoute!,
              onDelete: onDeleteRoute,
            ),
            const SizedBox(height: 16),
            if (driver.requests.isNotEmpty)
              _RequestsList(requests: driver.requests),
          ] else ...[
            const Text(
              'Ready to share your route?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set your destination and find passengers heading your way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: driver.isLoading ? null : onSetRoute,
                icon: driver.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_road_rounded, size: 20),
                label: Text(driver.isLoading ? 'Setting route…' : 'Set Route'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteActiveCard extends StatelessWidget {
  final RouteResult route;
  final VoidCallback onDelete;
  const _RouteActiveCard({required this.route, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Route active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${route.distanceKm.toStringAsFixed(1)} km · '
                  '${route.notifiedCount} passenger${route.notifiedCount == 1 ? '' : 's'} notified',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final List<RideRequest> requests;
  const _RequestsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride requests (${requests.length})',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...requests.map((r) => _RequestTile(request: r)),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final RideRequest request;
  const _RequestTile({required this.request});

  Color get _statusColor {
    return switch (request.status) {
      'accepted' => AppColors.success,
      'declined' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  IconData get _statusIcon {
    return switch (request.status) {
      'accepted' => Icons.check_circle_rounded,
      'declined' => Icons.cancel_rounded,
      _ => Icons.schedule_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Passenger ${request.passengerID.substring(0, 8)}…',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              request.status,
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRouteSheet extends StatefulWidget {
  final LatLng? originPos;
  final void Function(
    double destLat,
    double destLng,
    double corridorKm,
    int seats,
  ) onSubmit;

  const _SetRouteSheet({required this.originPos, required this.onSubmit});

  @override
  State<_SetRouteSheet> createState() => _SetRouteSheetState();
}

class _SetRouteSheetState extends State<_SetRouteSheet> {
  final _dest = TextEditingController();
  double _corridor = 2.0;
  int _seats = 1;
  bool _geocoding = false;
  String? _error;

  Future<void> _submit() async {
    if (_dest.text.trim().isEmpty) {
      setState(() => _error = 'Enter a destination');
      return;
    }
    setState(() {
      _geocoding = true;
      _error = null;
    });
    try {
      final locations = await locationFromAddress(_dest.text.trim());
      if (locations.isEmpty) {
        setState(() {
          _error = 'Address not found';
          _geocoding = false;
        });
        return;
      }
      final loc = locations.first;
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmit(loc.latitude, loc.longitude, _corridor, _seats);
    } catch (e) {
      setState(() {
        _error = 'Could not find address';
        _geocoding = false;
      });
    }
  }

  @override
  void dispose() {
    _dest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Set your route',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _dest,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Destination address',
                prefixIcon: Icon(Icons.location_on_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Corridor radius',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${_corridor.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: _corridor,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.border,
              onChanged: (v) => setState(() => _corridor = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Available seats',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const Spacer(),
                _Counter(
                  value: _seats,
                  min: 1,
                  max: 6,
                  onChanged: (v) => setState(() => _seats = v),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _geocoding ? null : _submit,
                child: _geocoding
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Find Passengers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Counter({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CounterBtn(
          icon: Icons.remove,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _CounterBtn(
          icon: Icons.add,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CounterBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.card : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MyLocationMarker extends StatefulWidget {
  final Color color;
  const _MyLocationMarker({required this.color});

  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 50 * _pulse.value,
            height: 50 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color
                  .withValues(alpha: 0.2 * (1.4 - _pulse.value)),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
