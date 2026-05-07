

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  var _latitude = "";
  var _longitude = "";
  var _altitude = "";
  var _speed = "";
  var _accuracy = "";
  var _address = "Tap the button to get your location";

  bool _isLoading = false;
  String? _errorMessage;
  LatLng? _currentLatLng;
  final MapController _mapController = MapController();

  Future<void> _updatePosition() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Position pos = await _determinePosition();

      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);

      final place = placemarks.isNotEmpty ? placemarks[0] : null;
      final address = [
        place?.name,
        place?.street,
        place?.locality,
        place?.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _latitude = pos.latitude.toStringAsFixed(6);
        _longitude = pos.longitude.toStringAsFixed(6);
        _altitude = '${pos.altitude.toStringAsFixed(1)} m';
        _speed = '${pos.speed.toStringAsFixed(2)} m/s';
        _accuracy = '±${pos.accuracy.toStringAsFixed(1)} m';
        _address = address.isNotEmpty ? address : 'Address unavailable';
        _currentLatLng = latLng;
        _isLoading = false;
      });

      // Animate map to new position
      _mapController.move(latLng, 15.0);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them in settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied. Please enable them in app settings.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D27),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLatLng ?? const LatLng(50.0647, 19.9450), // Kraków default
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.location_app',
                      maxZoom: 19,
                    ),
                    if (_currentLatLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLatLng!,
                            width: 60,
                            height: 60,
                            child: const _PulsingMarker(),
                          ),
                        ],
                      ),
                  ],
                ),

                // Attribution
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),

                // Loading overlay
                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Info panel
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF1A1D27),
              child: Column(
                children: [
                  // Address bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF2A2D3A), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place,
                            color: Color(0xFF4ECDC4), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.4), width: 1),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ),

                  // Stats grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _InfoTile(
                              icon: Icons.my_location,
                              label: 'Latitude',
                              value: _latitude.isEmpty ? '--' : _latitude),
                          _InfoTile(
                              icon: Icons.my_location,
                              label: 'Longitude',
                              value: _longitude.isEmpty ? '--' : _longitude),
                          _InfoTile(
                              icon: Icons.terrain,
                              label: 'Altitude',
                              value: _altitude.isEmpty ? '--' : _altitude),
                          _InfoTile(
                              icon: Icons.speed,
                              label: 'Speed',
                              value: _speed.isEmpty ? '--' : _speed),
                          _InfoTile(
                              icon: Icons.gps_fixed,
                              label: 'Accuracy',
                              value: _accuracy.isEmpty ? '--' : _accuracy,
                              fullWidth: false),
                        ],
                      ),
                    ),
                  ),

                  // Button
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updatePosition,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.gps_fixed, size: 18),
                        label: Text(
                          _isLoading ? 'Locating...' : 'Get My Location',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          foregroundColor: const Color(0xFF0F1117),
                          disabledBackgroundColor:
                              const Color(0xFF4ECDC4).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing marker shown at the user's location
class _PulsingMarker extends StatefulWidget {
  const _PulsingMarker();

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          Container(
            width: 50 * _animation.value,
            height: 50 * _animation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4ECDC4).withOpacity(0.3 * (1 - _animation.value + 0.4)),
              border: Border.all(
                color: const Color(0xFF4ECDC4).withOpacity(0.5),
                width: 1.5,
              ),
            ),
          ),
          // Center dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4ECDC4),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ECDC4).withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single stat tile in the info grid
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2D3A), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4ECDC4), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}