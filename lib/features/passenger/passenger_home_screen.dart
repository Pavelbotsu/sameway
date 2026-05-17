import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/token_storage.dart';
import '../../core/widgets/glass_card.dart';
import '../auth/auth_provider.dart';
import '../onboarding/role_selection_screen.dart';
import 'passenger_provider.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
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
        context.read<PassengerProvider>().connectWS(token);
      }
      _locationTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sendLocation(),
      );
    });
  }

  Future<void> _initLocation() async {
    try {
      final pos = await _determinePosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      _mapController.move(latlng, 14);
      await context
          .read<PassengerProvider>()
          .updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      await context
          .read<PassengerProvider>()
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
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _logout() async {
    final passenger = context.read<PassengerProvider>();
    final auth = context.read<AuthProvider>();
    await passenger.goOffline();
    await auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
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
          FlutterMap(
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
              if (_myPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPos!,
                      width: 56,
                      height: 56,
                      child: _MyLocationMarker(color: AppColors.teal),
                    ),
                  ],
                ),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      borderRadius: 16,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded,
                              color: AppColors.teal, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Passenger',
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

          // Bottom status panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<PassengerProvider>(
              builder: (_, p, __) => _StatusPanel(provider: p),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final PassengerProvider provider;
  const _StatusPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
          switch (provider.state) {
            PassengerStatus.looking => const _LookingCard(),
            PassengerStatus.offered => _OfferCard(
                offer: provider.pendingOffer!,
                onAccept: () => provider.acceptRide(),
                onDecline: () => provider.declineRide(),
              ),
            PassengerStatus.accepted => const _AcceptedCard(),
            PassengerStatus.declined => const _DeclinedCard(),
          },
        ],
      ),
    );
  }
}

class _LookingCard extends StatelessWidget {
  const _LookingCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.search_rounded,
              color: AppColors.teal, size: 26),
        ),
        const SizedBox(height: 14),
        const Text(
          'Looking for rides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'ll notify you when a driver with a matching route is nearby.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final RideOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.drive_eta_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ride offer!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Driver ${offer.driverId.substring(0, 8)}… · '
                    '${offer.corridorKm.toStringAsFixed(1)} km corridor · '
                    '${offer.seats} seat${offer.seats == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.error, width: 1.5),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Accept',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AcceptedCard extends StatelessWidget {
  const _AcceptedCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          'Ride accepted!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your driver has been notified. Stay at your location.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DeclinedCard extends StatelessWidget {
  const _DeclinedCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 26),
        ),
        const SizedBox(height: 14),
        const Text(
          'Offer declined',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Looking for the next available ride…',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
      ],
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
