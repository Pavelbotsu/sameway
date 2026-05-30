import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/language_provider.dart';
import '../../core/map_style_provider.dart';
import '../../core/token_storage.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/widgets/car_edit_sheet.dart';
import '../../core/widgets/glass_card.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../chat/chat_screen.dart';
import '../onboarding/role_selection_screen.dart';
import '../promotions/promotions_screen.dart';
import '../trips/trip_history_screen.dart';
import '../trips/trip_search_sheet.dart';
import '../../core/widgets/rating_sheet.dart';
import 'passenger_provider.dart';

class PassengerHomeScreen extends StatefulWidget {
  final bool isGuest;
  const PassengerHomeScreen({super.key, this.isGuest = false});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _mapController = MapController();
  LatLng? _myPos;
  Timer? _locationTimer;
  Timer? _driversTimer;
  List<_NearbyDriverInfo> _nearbyDrivers = [];
  _NearbyDriverInfo? _selectedDriver;
  LatLng? _destPos;
  String _destName = '';
  late VoidCallback _ratingListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PassengerProvider>();
      await _initLocation();
      if (!widget.isGuest) {
        final token = await TokenStorage().getToken();
        if (token != null && mounted) {
          provider.connectWS(token);
        }
      }
      _locationTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sendLocation(),
      );
      _driversTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchNearbyDrivers(),
      );
      _fetchNearbyDrivers();

      _ratingListener = () {
        if (provider.pendingRatingRequestId != null &&
            provider.pendingRatingDriverId != null &&
            mounted) {
          final reqId = provider.pendingRatingRequestId!;
          final driverId = provider.pendingRatingDriverId!;
          provider.clearPendingRating();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RatingSheet(
              rideRequestId: reqId,
              ratedUserId: driverId,
              ratedUserLabel: 'driver',
              accentColor: AppColors.teal,
            ),
          );
        }
      };
      provider.addListener(_ratingListener);
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _driversTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNearbyDrivers() async {
    if (_myPos == null) return;
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/passenger/nearby-drivers'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': _myPos!.latitude,
          'longitude': _myPos!.longitude,
          'radius_km': 10.0,
          if (_destPos != null) ...{
            'dest_lat': _destPos!.latitude,
            'dest_lng': _destPos!.longitude,
            'dest_radius_km': 1.0,
          },
        }),
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _nearbyDrivers = list
              .map((e) => _NearbyDriverInfo.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _requestRide(_NearbyDriverInfo driver) async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/passenger/request-driver'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'driver_id': driver.driverId}),
      );
      if (!mounted) return;
      final ok = resp.statusCode == 200;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Ride request sent!'
            : (jsonDecode(resp.body) as Map)['error'] as String? ??
                'Failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {}
  }

  void _showDriverInfo(_NearbyDriverInfo driver) {
    setState(() => _selectedDriver = driver);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DriverInfoSheet(
        driver: driver,
        onRequest: () {
          Navigator.pop(context);
          _requestRide(driver);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedDriver = null);
    });
  }

  void _showDestinationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DestinationSheet(
        nearbyPos: _myPos,
        onSelected: (pos, name) {
          setState(() {
            _destPos = pos;
            _destName = name;
          });
          _fetchNearbyDrivers();
        },
      ),
    );
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) _showGpsDisabledDialog();
      return;
    }
    try {
      final pos = await _determinePosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      _mapController.move(latlng, 14);
      if (!widget.isGuest) {
        await context
            .read<PassengerProvider>()
            .updateLocation(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'GPS is off',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Location services are required to show your position on the map. Please enable GPS and try again.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
              if (mounted) _initLocation();
            },
            child: const Text('Open Settings',
                style: TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      if (!widget.isGuest) {
        await context
            .read<PassengerProvider>()
            .updateLocation(pos.latitude, pos.longitude);
      }
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

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LanguageSheet(),
    );
  }

  void _showMapStyleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MapStyleSheet(),
    );
  }

  void _showTripSearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TripSearchSheet(currentPos: _myPos),
    );
  }

  void _showPromotions() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PromotionsScreen()));
  }

  void _showAccountSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _AccountSheet(
          role: 'passenger',
          isGuest: widget.isGuest,
          scrollController: scrollController,
          currentPos: _myPos,
          onSwitchRole: _switchRole,
          onShowLanguage: () {
            Navigator.pop(context);
            Future.delayed(
                const Duration(milliseconds: 200), _showLanguageSheet);
          },
          onShowMapStyle: () {
            Navigator.pop(context);
            Future.delayed(
                const Duration(milliseconds: 200), _showMapStyleSheet);
          },
          onSignOut: _logout,
        ),
      ),
    );
  }

  void _switchRole() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    if (widget.isGuest) {
      if (!mounted) return;
      _switchRole();
      return;
    }
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Consumer<PassengerProvider>(
      builder: (_, p, __) => Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: _PassengerNavBar(
          unreadMessages: p.unreadMessages,
          isGuest: widget.isGuest,
          onShowChat: (p.state == PassengerStatus.accepted &&
                  p.acceptedRequestId != null)
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        rideRequestId: p.acceptedRequestId!,
                        otherPartyName: 'Driver',
                      ),
                    ),
                  )
              : null,
          onShowTrips: _showTripSearch,
          onShowPromotions: _showPromotions,
          onShowAccount: _showAccountSheet,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myPos ?? const LatLng(50.0647, 19.9450),
                initialZoom: 14,
              ),
              children: [
                Consumer<MapStyleProvider>(
                  builder: (_, mapStyle, __) => TileLayer(
                    urlTemplate: mapStyle.urlTemplate,
                    userAgentPackageName: 'com.example.sameway',
                  ),
                ),
                if (_selectedDriver != null &&
                    _selectedDriver!.routeWkt.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _parseWKT(_selectedDriver!.routeWkt),
                        color: AppColors.primary.withValues(alpha: 0.55),
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                if (_nearbyDrivers.isNotEmpty)
                  MarkerLayer(
                    markers: _nearbyDrivers
                        .map((d) => Marker(
                              point: d.origin,
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showDriverInfo(d),
                                child: _DriverMarker(),
                              ),
                            ))
                        .toList(),
                  ),
                if (_destPos != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _destPos!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.teal,
                          size: 40,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded,
                                color: AppColors.teal, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              l.passenger,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.isGuest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l.guest,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        borderRadius: 14,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _showLanguageSheet,
                              icon: const Icon(Icons.translate_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              tooltip: 'Language',
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: _showAccountSheet,
                              icon: const Icon(
                                  Icons.manage_accounts_rounded,
                                  color: AppColors.textSecondary,
                                  size: 22),
                              tooltip: 'Account',
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!widget.isGuest &&
                _nearbyDrivers.isEmpty &&
                p.state == PassengerStatus.looking)
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).size.height * 0.32,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.directions_car_outlined,
                            color: AppColors.teal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No drivers nearby',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Try adjusting your destination or check back soon.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            DraggableScrollableSheet(
              initialChildSize: 0.28,
              minChildSize: 0.07,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.28],
              builder: (_, scrollController) => _StatusPanel(
                provider: p,
                scrollController: scrollController,
                isGuest: widget.isGuest,
                currentPos: _myPos,
                destName: _destName.isEmpty ? null : _destName,
                onDestinationSet: (pos, name) {
                  setState(() {
                    _destPos = pos;
                    _destName = name;
                  });
                  _fetchNearbyDrivers();
                },
                onClearDestination: () {
                  setState(() {
                    _destPos = null;
                    _destName = '';
                  });
                  _fetchNearbyDrivers();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 20),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final PassengerProvider provider;
  final bool isGuest;
  final LatLng? currentPos;
  final String? destName;
  final ScrollController scrollController;
  final void Function(LatLng pos, String name) onDestinationSet;
  final VoidCallback onClearDestination;

  const _StatusPanel({
    required this.provider,
    required this.scrollController,
    required this.onDestinationSet,
    required this.onClearDestination,
    this.isGuest = false,
    this.currentPos,
    this.destName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: isGuest
                  ? const _GuestPassengerCard()
                  : switch (provider.state) {
                      PassengerStatus.looking => _LookingCard(
                          currentPos: currentPos,
                          destName: destName,
                          onDestinationSet: onDestinationSet,
                          onClearDestination: onClearDestination,
                        ),
                      PassengerStatus.offered => _OfferCard(
                          offer: provider.pendingOffer!,
                          onAccept: () => provider.acceptRide(),
                          onDecline: () => provider.declineRide(),
                        ),
                      PassengerStatus.accepted => _AcceptedCard(
                          requestId: provider.acceptedRequestId,
                          onCancel: () => provider.cancelRide(),
                        ),
                      PassengerStatus.declined => const _DeclinedCard(),
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? badge;
  final VoidCallback? onTap;

  const _NavIconBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (onTap != null ? color : AppColors.textSecondary)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon,
                          color: onTap != null
                              ? color
                              : AppColors.textSecondary,
                          size: 22),
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
}

class _PassengerNavBar extends StatelessWidget {
  final int unreadMessages;
  final bool isGuest;
  final VoidCallback? onShowChat;
  final VoidCallback onShowTrips;
  final VoidCallback onShowPromotions;
  final VoidCallback onShowAccount;

  const _PassengerNavBar({
    required this.unreadMessages,
    required this.isGuest,
    required this.onShowTrips,
    required this.onShowPromotions,
    required this.onShowAccount,
    this.onShowChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        children: [
          _NavIconBtn(
            icon: Icons.forum_rounded,
            label: 'Chat',
            color: AppColors.teal,
            badge: unreadMessages > 0 ? unreadMessages : null,
            onTap: onShowChat,
          ),
          _NavIconBtn(
            icon: Icons.search_rounded,
            label: 'Find Trips',
            color: AppColors.teal,
            onTap: isGuest ? null : onShowTrips,
          ),
          _NavIconBtn(
            icon: Icons.local_offer_rounded,
            label: 'Offers',
            color: AppColors.teal,
            onTap: onShowPromotions,
          ),
          _NavIconBtn(
            icon: Icons.manage_accounts_rounded,
            label: 'Account',
            color: AppColors.teal,
            onTap: onShowAccount,
          ),
        ],
      ),
    );
  }
}

class _LookingCard extends StatefulWidget {
  final LatLng? currentPos;
  final String? destName;
  final void Function(LatLng pos, String name) onDestinationSet;
  final VoidCallback onClearDestination;

  const _LookingCard({
    required this.onDestinationSet,
    required this.onClearDestination,
    this.currentPos,
    this.destName,
  });

  @override
  State<_LookingCard> createState() => _LookingCardState();
}

class _LookingCardState extends State<_LookingCard> {
  final _ctrl = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void didUpdateWidget(_LookingCard old) {
    super.didUpdateWidget(old);
    if (widget.destName != old.destName) {
      if (widget.destName == null) {
        _ctrl.clear();
        setState(() => _suggestions = []);
      } else if (_ctrl.text.isEmpty) {
        _ctrl.text = widget.destName!.split(',').first.trim();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(v));
  }

  Future<void> _fetch(String query) async {
    setState(() => _loading = true);
    try {
      final origin = widget.currentPos;
      final bbox = origin != null
          ? '&viewbox=${origin.longitude - 0.5},${origin.latitude - 0.5}'
            ',${origin.longitude + 0.5},${origin.latitude + 0.5}&bounded=1'
          : '';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=0$bbox',
      );
      final resp = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'sameway-app'},
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() => _suggestions = list
            .map((e) => _PlaceSuggestion(
                  name: e['display_name'] as String,
                  lat: double.parse(e['lat'] as String),
                  lng: double.parse(e['lon'] as String),
                ))
            .toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _select(_PlaceSuggestion s) {
    _ctrl.text = s.name.split(',').first.trim();
    setState(() => _suggestions = []);
    widget.onDestinationSet(LatLng(s.lat, s.lng), s.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasDestination = widget.destName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.lookingForRides,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!hasDestination)
                    Text(
                      l.lookingDesc,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Where do you want to go?',
            hintStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasDestination ? AppColors.teal : AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasDestination ? AppColors.teal : AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.teal, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.location_on_rounded,
                color: AppColors.teal, size: 18),
            suffixIcon: hasDestination
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _suggestions = []);
                      widget.onClearDestination();
                    },
                  )
                : _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.teal),
                        ),
                      )
                    : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppColors.teal, size: 16),
                  title: Text(s.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        const _Co2MiniCard(),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Co2MiniCard extends StatefulWidget {
  const _Co2MiniCard();

  @override
  State<_Co2MiniCard> createState() => _Co2MiniCardState();
}

class _Co2MiniCardState extends State<_Co2MiniCard> {
  double? _co2;
  int? _trips;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/auth/stats'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _co2 = (data['co2_saved_kg'] as num?)?.toDouble() ?? 0;
          _trips = (data['trips_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_co2 == null) {
      return Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.border,
        child: Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_co2!.toStringAsFixed(1)} kg CO₂ saved',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_trips != null && _trips! > 0)
            Text(
              '$_trips trip${_trips! == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
        ],
      ),
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
  final String? requestId;
  final VoidCallback? onCancel;
  const _AcceptedCard({this.requestId, this.onCancel});

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
        const SizedBox(height: 14),
        if (requestId != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    rideRequestId: requestId!,
                    otherPartyName: 'Driver',
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text('Message Driver',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (onCancel != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Cancel ride?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    content: const Text(
                      'Your driver will be notified.',
                      style: TextStyle(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep ride',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onCancel!();
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel ride',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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

class _GuestPassengerCard extends StatelessWidget {
  const _GuestPassengerCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.explore_rounded,
              color: AppColors.teal, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          l.exploringAsGuest,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.signInFindDesc,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _GuestSignInSheet(role: 'passenger'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l.signInToFindRides,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AccountSheet extends StatefulWidget {
  final String role;
  final bool isGuest;
  final ScrollController scrollController;
  final LatLng? currentPos;
  final VoidCallback onSwitchRole;
  final VoidCallback onShowLanguage;
  final VoidCallback onShowMapStyle;
  final VoidCallback onSignOut;

  const _AccountSheet({
    required this.role,
    required this.isGuest,
    required this.scrollController,
    required this.onSwitchRole,
    required this.onShowLanguage,
    required this.onShowMapStyle,
    required this.onSignOut,
    this.currentPos,
  });

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  bool _sending = false;
  double? _co2Saved;
  int? _tripsCount;
  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) {
      _loadStats();
      _loadIdentity();
    }
  }

  Future<void> _loadIdentity() async {
    final storage = TokenStorage();
    var name = await storage.getName();
    var email = await storage.getEmail();
    if ((name == null || email == null) && mounted) {
      try {
        final jwt = await storage.getToken();
        if (jwt == null) return;
        final resp = await http.get(
          Uri.parse('$kApiBase/auth/profile'),
          headers: {'Authorization': 'Bearer $jwt'},
        );
        if (resp.statusCode == 200 && mounted) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          name = data['name'] as String?;
          email = data['email'] as String?;
          await storage.save(
            token: jwt,
            role: widget.role,
            userId: (await storage.getUserId()) ?? '',
            name: name,
            email: email,
          );
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _userName = name; _userEmail = email; });
  }

  Future<void> _loadStats() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/auth/stats'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _co2Saved = (data['co2_saved_kg'] as num?)?.toDouble() ?? 0;
          _tripsCount = (data['trips_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sending = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/auth/test-notification'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (!mounted) return;
      final ok = resp.statusCode == 200;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Test notification sent! Check your device.'
            : (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok && mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Network error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = widget.role == 'driver' ? AppColors.primary : AppColors.teal;
    final roleLabel = widget.role == 'driver' ? l.driver : l.passenger;

    final initials = _userName != null && _userName!.isNotEmpty
        ? _userName!.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : (widget.isGuest ? '?' : roleLabel[0].toUpperCase());

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isGuest) ...[
                        Text(
                          l.exploreAsGuest,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.continueAsGuest,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ] else ...[
                        Text(
                          _userName ?? roleLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_userEmail != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _userEmail!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!widget.isGuest && _co2Saved == null)
              Shimmer.fromColors(
                baseColor: AppColors.surface,
                highlightColor: AppColors.border,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (!widget.isGuest && _co2Saved != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded,
                        color: AppColors.success, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You saved ${_co2Saved!.toStringAsFixed(1)} kg CO₂',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${_tripsCount ?? 0} trip${(_tripsCount ?? 0) == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.manage_accounts_rounded,
                label: 'Account & Security',
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _AccountManagementSheet(
                    userName: _userName,
                    userEmail: _userEmail,
                    onNameUpdated: (n) => setState(() => _userName = n),
                  ),
                ),
              ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.history_rounded,
                label: 'Trip History',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TripHistoryScreen()),
                  );
                },
              ),
            _SheetTile(
              icon: Icons.swap_horiz_rounded,
              label: l.switchRole,
              onTap: () {
                Navigator.pop(context);
                widget.onSwitchRole();
              },
            ),
            _SheetTile(
              icon: Icons.translate_rounded,
              label: l.language,
              onTap: widget.onShowLanguage,
            ),
            _SheetTile(
              icon: Icons.map_rounded,
              label: 'Map Style',
              onTap: widget.onShowMapStyle,
            ),
            _SheetTile(
              icon: Icons.local_offer_rounded,
              label: 'Promotions & Rewards',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PromotionsScreen()));
              },
            ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.search_rounded,
                label: 'Find Planned Trips',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => TripSearchSheet(currentPos: widget.currentPos),
                  );
                },
              ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.directions_car_rounded,
                label: 'My Car',
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const CarEditSheet(),
                ),
              ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.notifications_active_rounded,
                label: 'Test Notification',
                trailing: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary),
                      )
                    : null,
                onTap: _sending ? () {} : _sendTestNotification,
              ),
            const SizedBox(height: 4),
            const Divider(color: AppColors.border),
            const SizedBox(height: 4),
            _SheetTile(
              icon: Icons.logout_rounded,
              label: l.signOut,
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                widget.onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AccountManagementSheet extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final void Function(String name) onNameUpdated;

  const _AccountManagementSheet({
    required this.onNameUpdated,
    this.userName,
    this.userEmail,
  });

  @override
  State<_AccountManagementSheet> createState() =>
      _AccountManagementSheetState();
}

class _AccountManagementSheetState extends State<_AccountManagementSheet> {
  late final TextEditingController _nameCtrl;
  bool _savingName = false;
  bool _showPasswordForm = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      final storage = TokenStorage();
      final jwt = await storage.getToken();
      if (jwt == null) return;
      final resp = await http.put(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name}),
      );
      if (resp.statusCode == 200 && mounted) {
        await storage.save(
          token: jwt,
          role: (await storage.getRole()) ?? '',
          userId: (await storage.getUserId()) ?? '',
          name: name,
        );
        if (!mounted) return;
        widget.onNameUpdated(name);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _savingName = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Account & Security',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.userEmail ?? '—',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (widget.userEmail != null) {
                        Clipboard.setData(
                            ClipboardData(text: widget.userEmail!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email copied'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.copy_rounded,
                        color: AppColors.textSecondary, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _savingName ? null : _saveName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _savingName
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 4),
            _SheetTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              onTap: () =>
                  setState(() => _showPasswordForm = !_showPasswordForm),
            ),
            if (_showPasswordForm) ...[
              const SizedBox(height: 8),
              const _ChangePasswordForm(),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _saving = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/auth/change-password'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _currentCtrl.text,
          'new_password': _newCtrl.text,
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      } else {
        final msg =
            (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed';
        setState(() => _error = msg);
      }
    } catch (_) {
      setState(() => _error = 'Network error');
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(TextEditingController ctrl, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_currentCtrl, 'Current password'),
        _field(_newCtrl, 'New password'),
        _field(_confirmCtrl, 'Confirm new password'),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
          const SizedBox(height: 8),
        ],
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Text('Update Password'),
        ),
      ],
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final currentCode = langProvider.locale.languageCode;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Language / Мова',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          _LangOption(
            label: 'English',
            code: 'en',
            selected: currentCode == 'en',
            onTap: () {
              context.read<LanguageProvider>().setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _LangOption(
            label: 'Українська',
            code: 'uk',
            selected: currentCode == 'uk',
            onTap: () {
              context.read<LanguageProvider>().setLocale(const Locale('uk'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              code == 'en' ? '🇬🇧' : '🇺🇦',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? Colors.white : AppColors.textSecondary,
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MapStyleSheet extends StatelessWidget {
  const _MapStyleSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapStyleProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Map Style',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          _MapOption(
            label: 'Standard',
            icon: Icons.map_rounded,
            style: MapStyle.osm,
            selected: provider.style == MapStyle.osm,
          ),
          const SizedBox(height: 10),
          _MapOption(
            label: 'Satellite',
            icon: Icons.satellite_alt_rounded,
            style: MapStyle.satellite,
            selected: provider.style == MapStyle.satellite,
          ),
          const SizedBox(height: 10),
          _MapOption(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            style: MapStyle.dark,
            selected: provider.style == MapStyle.dark,
          ),
        ],
      ),
    );
  }
}

class _MapOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final MapStyle style;
  final bool selected;

  const _MapOption({
    required this.label,
    required this.icon,
    required this.style,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<MapStyleProvider>().setStyle(style);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.teal : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _GuestSignInSheet extends StatelessWidget {
  final String role;
  const _GuestSignInSheet({required this.role});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = role == 'driver' ? AppColors.primary : AppColors.teal;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.lock_outline_rounded, color: color, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            l.signInToContinue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.signInFindDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(role: role),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l.signInRegister,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NearbyDriverInfo {
  final String driverId;
  final String driverName;
  final LatLng origin;
  final LatLng destination;
  final double corridorKm;
  final int seats;
  final String carMake;
  final String carModel;
  final String carColor;
  final String carPlate;
  final String routeWkt;

  const _NearbyDriverInfo({
    required this.driverId,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.corridorKm,
    required this.seats,
    required this.carMake,
    required this.carModel,
    required this.carColor,
    required this.carPlate,
    required this.routeWkt,
  });

  factory _NearbyDriverInfo.fromJson(Map<String, dynamic> j) =>
      _NearbyDriverInfo(
        driverId: j['driver_id'] as String,
        driverName: j['driver_name'] as String? ?? 'Driver',
        origin: LatLng(
          (j['origin_lat'] as num).toDouble(),
          (j['origin_lng'] as num).toDouble(),
        ),
        destination: LatLng(
          (j['dest_lat'] as num).toDouble(),
          (j['dest_lng'] as num).toDouble(),
        ),
        corridorKm: (j['corridor_km'] as num).toDouble(),
        seats: (j['seats'] as num).toInt(),
        carMake: j['car_make'] as String? ?? '',
        carModel: j['car_model'] as String? ?? '',
        carColor: j['car_color'] as String? ?? '',
        carPlate: j['car_plate'] as String? ?? '',
        routeWkt: j['route_wkt'] as String? ?? '',
      );

  String get carSummary {
    final parts = [carColor, carMake, carModel].where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'No car info' : parts.join(' ');
  }
}

// ── Driver info bottom sheet ──────────────────────────────────────────────────

class _DriverInfoSheet extends StatefulWidget {
  final _NearbyDriverInfo driver;
  final VoidCallback onRequest;

  const _DriverInfoSheet({required this.driver, required this.onRequest});

  @override
  State<_DriverInfoSheet> createState() => _DriverInfoSheetState();
}

class _DriverInfoSheetState extends State<_DriverInfoSheet> {
  String? _destAddress;

  @override
  void initState() {
    super.initState();
    placemarkFromCoordinates(
      widget.driver.destination.latitude,
      widget.driver.destination.longitude,
    ).then((places) {
      if (!mounted || places.isEmpty) return;
      final p = places.first;
      setState(() => _destAddress =
          [p.street, p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.isNotEmpty)
              .take(2)
              .join(', '));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.drive_eta_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.driverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${driver.seats} seat${driver.seats == 1 ? '' : 's'} · ${driver.corridorKm.toStringAsFixed(1)} km corridor',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            label: 'Destination',
            value: _destAddress ??
                '${driver.destination.latitude.toStringAsFixed(4)}, ${driver.destination.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.directions_car_rounded,
            color: AppColors.primary,
            label: 'Car',
            value: driver.carSummary,
          ),
          if (driver.carPlate.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.badge_rounded,
              color: AppColors.teal,
              label: 'Plate',
              value: driver.carPlate,
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: widget.onRequest,
              icon: const Icon(Icons.hail_rounded, size: 20),
              label: const Text('Request this ride',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Destination search sheet ──────────────────────────────────────────────────

class _PlaceSuggestion {
  final String name;
  final double lat;
  final double lng;
  const _PlaceSuggestion({required this.name, required this.lat, required this.lng});
}

class _DestinationSheet extends StatefulWidget {
  final LatLng? nearbyPos;
  final void Function(LatLng pos, String name) onSelected;

  const _DestinationSheet({required this.nearbyPos, required this.onSelected});

  @override
  State<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<_DestinationSheet> {
  final _ctrl = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(v));
  }

  Future<void> _fetch(String query) async {
    setState(() => _loading = true);
    try {
      final origin = widget.nearbyPos;
      final bbox = origin != null
          ? '&viewbox=${origin.longitude - 0.5},${origin.latitude - 0.5}'
            ',${origin.longitude + 0.5},${origin.latitude + 0.5}&bounded=1'
          : '';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=0$bbox',
      );
      final resp = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'sameway-app'},
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() => _suggestions = list
            .map((e) => _PlaceSuggestion(
                  name: e['display_name'] as String,
                  lat: double.parse(e['lat'] as String),
                  lng: double.parse(e['lon'] as String),
                ))
            .toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _select(_PlaceSuggestion s) {
    Navigator.pop(context);
    widget.onSelected(LatLng(s.lat, s.lng), s.name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
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
          const Text(
            'Where do you want to go?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Only drivers whose route passes near your destination will be shown.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search address…',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.teal, width: 1.5),
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.teal),
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.teal, size: 18),
                    title: Text(
                      s.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _select(s),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
