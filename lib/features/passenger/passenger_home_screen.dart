import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/map_style_provider.dart';
import '../../core/token_storage.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/widgets/car_edit_sheet.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/language_sheet.dart';
import '../../core/widgets/rating_wait_banner.dart';
import '../../core/widgets/m3_expressive/wave_progress_indicator.dart';
import '../../core/widgets/role_switch_sheet.dart';
import '../driver/driver_home_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../account/account_security_screen.dart';
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
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  PassengerStatus? _prevState;
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
          showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RatingSheet(
              rideRequestId: reqId,
              ratedUserId: driverId,
              ratedUserLabel: 'driver',
              accentColor: AppColors.teal,
            ),
          ).then((rated) {
            if (rated == true) {
              provider.markAwaitingDriverRating(reqId);
            }
          });
        }
      };
      provider.addListener(_ratingListener);
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _driversTimer?.cancel();
    _sheetCtrl.dispose();
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
    if (widget.isGuest) return;
    final provider = context.read<PassengerProvider>();
    final ok = await provider.sendRequestToDriver(driver.driverId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ride request sent!' : (provider.error ?? 'Failed')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
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
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.gpsOff,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          l.gpsOffMessage,
          style:
              const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.later,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
              if (mounted) _initLocation();
            },
            child: Text(l.openSettings,
                style: const TextStyle(
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
    LanguageSheet.show(context);
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
          onShowAccountSecurity: (name, email) {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 200),
                () => _openAccountSecurity(name, email));
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

  void _showRoleSwitchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoleSwitchSheet(
        currentRole: 'passenger',
        onSwitched: () {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
            (_) => false,
          );
        },
      ),
    );
  }

  void _openAccountSecurity(String? name, String? email) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSecurityScreen(
          initialName: name,
          initialEmail: email,
        ),
      ),
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
      builder: (_, p, __) {
        if (p.state == PassengerStatus.offered &&
            _prevState != PassengerStatus.offered) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_sheetCtrl.isAttached && _sheetCtrl.size < 0.55) {
              _sheetCtrl.animateTo(
                0.55,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
        _prevState = p.state;
        return Scaffold(
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
                Consumer<PassengerProvider>(
                  builder: (_, p, __) {
                    final wkt = p.plannedRouteWkt;
                    if (wkt == null || wkt.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final pts = _parseWKT(wkt);
                    if (pts.isEmpty) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: pts,
                          color: AppColors.teal,
                          strokeWidth: 3,
                        ),
                      ],
                    );
                  },
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.isGuest ? null : _showRoleSwitchSheet,
                        child: GlassCard(
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
                              if (!widget.isGuest) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.swap_horiz_rounded,
                                    color: AppColors.textSecondary,
                                    size: 16),
                              ],
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
                                  minWidth: 48, minHeight: 48),
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
                                  minWidth: 48, minHeight: 48),
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

            if (p.awaitingRatingRequestId != null)
              Positioned(
                top: MediaQuery.of(context).viewPadding.top + 8,
                left: 0,
                right: 0,
                child: RatingWaitBanner(
                  otherPartyLabel: 'driver',
                  onDismiss: () => p.clearAwaitingRating(),
                ),
              ),

            DraggableScrollableSheet(
              controller: _sheetCtrl,
              initialChildSize: 0.28,
              minChildSize: 0.07,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.28, 0.55],
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
                  if (!widget.isGuest) {
                    context
                        .read<PassengerProvider>()
                        .clearSearchDestination();
                  }
                  _fetchNearbyDrivers();
                },
              ),
            ),
          ],
        ),
      );
      },
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
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(
                          axisAlignment: -1,
                          sizeFactor: anim,
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(provider.state),
                        child: switch (provider.state) {
                          PassengerStatus.looking => _LookingCard(
                              currentPos: currentPos,
                              destName: destName,
                              onDestinationSet: onDestinationSet,
                              onClearDestination: onClearDestination,
                              outstandingRequests:
                                  provider.outstandingRequests,
                              onCancelOutstanding: (id) =>
                                  provider.cancelOutstandingRequest(id),
                            ),
                          PassengerStatus.offered => _OfferCard(
                              offer: provider.pendingOffer!,
                              onAccept: () => provider.acceptRide(),
                              onDecline: () => provider.declineRide(),
                            ),
                          PassengerStatus.accepted => _AcceptedCard(
                              requestId: provider.acceptedRequestId,
                              driverName: provider.acceptedDriverName,
                              carSummary: provider.acceptedCarSummary,
                              driverAvgRating:
                                  provider.acceptedDriverAvgRating,
                              driverRatingCount:
                                  provider.acceptedDriverRatingCount,
                              passengerPos: currentPos,
                              driverPos: (provider.peerLat != null &&
                                      provider.peerLng != null)
                                  ? LatLng(
                                      provider.peerLat!, provider.peerLng!)
                                  : null,
                              onCancel: () => provider.cancelRide(),
                            ),
                          PassengerStatus.declined =>
                            const _DeclinedCard(),
                        },
                      ),
                    ),
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
  final List<OutstandingRequest> outstandingRequests;
  final void Function(String requestId) onCancelOutstanding;

  const _LookingCard({
    required this.onDestinationSet,
    required this.onClearDestination,
    required this.outstandingRequests,
    required this.onCancelOutstanding,
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
    final pos = LatLng(s.lat, s.lng);
    widget.onDestinationSet(pos, s.name);
    context.read<PassengerProvider>().setSearchDestination(pos);
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
        // "Searching for drivers heading your way" copy + wave indicator.
        Consumer<PassengerProvider>(
          builder: (_, p, __) {
            if (!p.isSearching || widget.outstandingRequests.isNotEmpty) {
              return const SizedBox.shrink();
            }
            final km = p.plannedDistanceKm;
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.travel_explore_rounded,
                            color: AppColors.teal, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Searching for drivers heading your way…',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (km != null && km > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${km.toStringAsFixed(1)} km route · '
                        "we'll notify you when one is found.",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const WaveProgressIndicator(height: 4),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.outstandingRequests.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...widget.outstandingRequests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OutstandingRequestTile(
                req: r,
                onCancel: () => widget.onCancelOutstanding(r.requestId),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const _Co2MiniCard(),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _OutstandingRequestTile extends StatelessWidget {
  final OutstandingRequest req;
  final VoidCallback onCancel;
  const _OutstandingRequestTile({required this.req, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final hasRating = (req.driverRatingCount ?? 0) > 0 &&
        req.driverAvgRating != null;
    final isPending = req.status == 'pending';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppColors.teal.withValues(alpha: 0.35)
              : AppColors.success.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.teal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            req.driverName?.trim().isNotEmpty == true
                                ? req.driverName!
                                : 'Driver',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFC857), size: 13),
                          const SizedBox(width: 2),
                          Text(
                            '${req.driverAvgRating!.toStringAsFixed(1)}'
                            ' (${req.driverRatingCount})',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (req.carSummary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        req.carSummary!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isPending
                    ? Icons.access_time_rounded
                    : Icons.check_circle_rounded,
                size: 14,
                color: isPending ? AppColors.teal : AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                isPending
                    ? 'Waiting for driver…'
                    : 'Driver accepted',
                style: TextStyle(
                  color: isPending ? AppColors.teal : AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isPending)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            const WaveProgressIndicator(height: 4),
          ],
        ],
      ),
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
    final loading = _co2 == null;
    final co2Display = (_co2 ?? 12.3).toStringAsFixed(1);
    final tripsDisplay = _trips ?? 4;
    return Skeletonizer(
      enabled: loading,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1F10),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.eco_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$co2Display kg CO₂ saved',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (loading || (_trips != null && _trips! > 0))
              Text(
                '$tripsDisplay trip${tripsDisplay == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  final RideOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  RideOffer get offer => widget.offer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                  Text(
                    l.rideOffer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (offer.driverName?.trim().isNotEmpty == true)
                              ? offer.driverName!
                              : 'Driver ${offer.driverId.substring(0, 8)}…',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((offer.driverRatingCount ?? 0) > 0 &&
                          offer.driverAvgRating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC857), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${offer.driverAvgRating!.toStringAsFixed(1)} (${offer.driverRatingCount})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (offer.carSummary != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.directions_car_rounded,
                            color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            offer.carSummary!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${offer.corridorKm.toStringAsFixed(1)} ${l.corridorLabel} · '
                    '${offer.seats} ${offer.seats == 1 ? l.seatLabel : l.seatsLabel}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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
                  onPressed: widget.onDecline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.error, width: 1.5),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l.decline,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ScaleTransition(
                scale: _pulse,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(l.accept,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AcceptedCard extends StatefulWidget {
  final String? requestId;
  final String? driverName;
  final String? carSummary;
  final double? driverAvgRating;
  final int? driverRatingCount;
  final LatLng? passengerPos;
  final LatLng? driverPos;
  final VoidCallback? onCancel;
  const _AcceptedCard({
    this.requestId,
    this.driverName,
    this.carSummary,
    this.driverAvgRating,
    this.driverRatingCount,
    this.passengerPos,
    this.driverPos,
    this.onCancel,
  });

  @override
  State<_AcceptedCard> createState() => _AcceptedCardState();
}

class _AcceptedCardState extends State<_AcceptedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bloomCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<double> _ring;
  final MapController _miniMapCtrl = MapController();

  @override
  void didUpdateWidget(covariant _AcceptedCard old) {
    super.didUpdateWidget(old);
    if (widget.passengerPos != old.passengerPos ||
        widget.driverPos != old.driverPos) {
      _fitMiniMap();
    }
  }

  void _fitMiniMap() {
    final a = widget.passengerPos;
    final b = widget.driverPos;
    if (a == null || b == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _miniMapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([a, b]),
            padding: const EdgeInsets.all(36),
          ),
        );
      } catch (_) {}
    });
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  @override
  void initState() {
    super.initState();
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMiniMap());
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _bloomCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _rotation = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _bloomCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    // Single expanding success-ring "ping" behind the icon, fading out by 1.0.
    _ring = CurvedAnimation(
      parent: _bloomCtrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    );
    _bloomCtrl.forward();
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasRating = (widget.driverRatingCount ?? 0) > 0 &&
        widget.driverAvgRating != null;
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ping ring (fires once on mount).
              AnimatedBuilder(
                animation: _ring,
                builder: (_, __) {
                  final t = _ring.value;
                  final size = 52 + 44 * t;
                  return IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.success
                              .withValues(alpha: 0.45 * (1 - t)),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Bloom check icon (scale + slight rotate).
              RotationTransition(
                turns: _rotation,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l.rideAccepted,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.driverName != null &&
            widget.driverName!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l.driverLabel}: ${widget.driverName}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasRating) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC857), size: 14),
                const SizedBox(width: 2),
                Text(
                  '${widget.driverAvgRating!.toStringAsFixed(1)} (${widget.driverRatingCount})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (widget.carSummary != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car_rounded,
                  color: AppColors.textSecondary, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.carSummary!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (widget.passengerPos != null && widget.driverPos != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                mapController: _miniMapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(
                    (widget.passengerPos!.latitude +
                            widget.driverPos!.latitude) /
                        2,
                    (widget.passengerPos!.longitude +
                            widget.driverPos!.longitude) /
                        2,
                  ),
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sameway.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          widget.passengerPos!,
                          widget.driverPos!,
                        ],
                        strokeWidth: 2,
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.passengerPos!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      Marker(
                        point: widget.driverPos!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.directions_car_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_haversineKm(widget.passengerPos!, widget.driverPos!).toStringAsFixed(1)} km away',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          l.driverNotified,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        if (widget.requestId != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    rideRequestId: widget.requestId!,
                    otherPartyName: l.driverLabel,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: Text(l.messageDriver,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (widget.onCancel != null) ...[
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
                    title: Text(l.cancelRideQ,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    content: Text(
                      l.cancelRideMessagePassenger,
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.keepRide,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.cancel,
                            style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) widget.onCancel!();
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(l.cancel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final void Function(String? name, String? email) onShowAccountSecurity;
  final VoidCallback onSignOut;

  const _AccountSheet({
    required this.role,
    required this.isGuest,
    required this.scrollController,
    required this.onSwitchRole,
    required this.onShowLanguage,
    required this.onShowMapStyle,
    required this.onShowAccountSecurity,
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
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? l.testNotificationSent
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
            if (!widget.isGuest) ...[
              Skeletonizer(
                enabled: _co2Saved == null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                          'You saved ${(_co2Saved ?? 18.7).toStringAsFixed(1)} kg CO₂',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_tripsCount ?? 6} trip${(_tripsCount ?? 6) == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.manage_accounts_rounded,
                label: l.accountSecurity,
                onTap: () =>
                    widget.onShowAccountSecurity(_userName, _userEmail),
              ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.history_rounded,
                label: l.tripHistory,
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
              label: l.mapStyle,
              onTap: widget.onShowMapStyle,
            ),
            _SheetTile(
              icon: Icons.local_offer_rounded,
              label: l.promotionsAndRewards,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PromotionsScreen()));
              },
            ),
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.search_rounded,
                label: l.findPlannedTrips,
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
                label: l.myCar,
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
                label: l.testNotification,
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
          Text(
            AppLocalizations.of(context).mapStyle,
            style: const TextStyle(
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

