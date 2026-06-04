import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/language_provider.dart';
import '../../core/map_style_provider.dart';
import '../../core/token_storage.dart';
import '../../core/widgets/car_edit_sheet.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/rating_sheet.dart';
import '../../core/widgets/rating_wait_banner.dart';
import '../../core/widgets/role_switch_sheet.dart';
import '../passenger/passenger_home_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../account/account_security_screen.dart';
import '../onboarding/role_selection_screen.dart';
import 'driver_provider.dart';
import 'widgets/driver_bottom_panel.dart';
import '../promotions/promotions_screen.dart';
import '../trips/trip_history_screen.dart';
import '../trips/trip_planner_sheet.dart';
import '../trips/trip_search_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  final bool isGuest;
  const DriverHomeScreen({super.key, this.isGuest = false});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _mapController = MapController();
  LatLng? _myPos;
  Timer? _locationTimer;
  String? _lastNotifiedRequestId;
  late VoidCallback _providerListener;
  late VoidCallback _ratingListener;
  StreamSubscription<PassengerMatchInfo>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _providerListener = () {
      final provider = context.read<DriverProvider>();
      final newId = provider.acceptedRequestId;
      if (newId != null && newId != _lastNotifiedRequestId) {
        _lastNotifiedRequestId = newId;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A passenger accepted your ride offer!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ));
        }
      }
    };
    _ratingListener = () {
      final provider = context.read<DriverProvider>();
      if (provider.pendingRatingRequestId != null &&
          provider.pendingRatingPassengerId != null &&
          mounted) {
        final reqId = provider.pendingRatingRequestId!;
        final passengerId = provider.pendingRatingPassengerId!;
        provider.clearPendingRating();
        showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => RatingSheet(
            rideRequestId: reqId,
            ratedUserId: passengerId,
            ratedUserLabel: 'passenger',
            accentColor: AppColors.primary,
          ),
        ).then((rated) {
          if (rated == true) {
            provider.markAwaitingPassengerRating(reqId);
          }
        });
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocation();
      if (!widget.isGuest) {
        final token = await TokenStorage().getToken();
        if (token != null && mounted) {
          context.read<DriverProvider>().connectWS(token);
        }
      }
      if (mounted) {
        final provider = context.read<DriverProvider>();
        provider.addListener(_providerListener);
        provider.addListener(_ratingListener);
        _incomingSub = provider.incomingRequests.listen((info) {
          if (!mounted) return;
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
          final name = (info.name?.trim().isNotEmpty == true)
              ? info.name!
              : 'A passenger';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$name sent you a ride request'),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ));
        });
      }
      _locationTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _sendLocation());
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
        await context.read<DriverProvider>().updateLocation(
              pos.latitude,
              pos.longitude,
            );
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
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLocation() async {
    if (_myPos == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latlng);
      if (!widget.isGuest) {
        await context
            .read<DriverProvider>()
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  void _showSetRouteSheet() {
    if (widget.isGuest) {
      _showGuestSignInPrompt();
      return;
    }
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

  void _showGuestSignInPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestSignInSheet(role: 'driver'),
    );
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

  void _showPlanTripSheet() {
    if (widget.isGuest) {
      _showGuestSignInPrompt();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TripPlannerSheet(currentPos: _myPos),
    );
  }

  void _showFindTripsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TripSearchSheet(currentPos: _myPos),
    );
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
        builder: (_, scrollController) => _AccountSheet(
          scrollController: scrollController,
          role: 'driver',
          isGuest: widget.isGuest,
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
        currentRole: 'driver',
        onSwitched: () {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
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
    final provider = context.read<DriverProvider>();
    provider.removeListener(_providerListener);
    provider.removeListener(_ratingListener);
    _incomingSub?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: _DriverNavBar(
        isGuest: widget.isGuest,
        onSetRoute: _showSetRouteSheet,
        onPlanTrip: _showPlanTripSheet,
        onFindTrips: _showFindTripsSheet,
        onShowAccount: _showAccountSheet,
      ),
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
                  Consumer<MapStyleProvider>(
                    builder: (_, mapStyle, __) => TileLayer(
                      urlTemplate: mapStyle.urlTemplate,
                      userAgentPackageName: 'com.example.sameway',
                    ),
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
                            const Icon(Icons.drive_eta_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              l.driver,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (!widget.isGuest) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.swap_horiz_rounded,
                                  color: AppColors.textSecondary, size: 16),
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
                            icon: const Icon(Icons.manage_accounts_rounded,
                                color: AppColors.textSecondary, size: 22),
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

          // Bottom panel
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.07,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.28],
            builder: (_, scrollController) => Consumer<DriverProvider>(
              builder: (_, driver, __) => DriverBottomPanel(
                driver: driver,
                scrollController: scrollController,
                isGuest: widget.isGuest,
                myPos: _myPos,
                onSetRoute: _showSetRouteSheet,
                onPlanTrip: _showPlanTripSheet,
                onFindTrips: _showFindTripsSheet,
                onDeleteRoute: () => driver.deleteRoute(),
              ),
            ),
          ),

          // Rating-wait banner overlay
          Consumer<DriverProvider>(
            builder: (_, driver, __) {
              if (driver.awaitingRatingRequestId == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: MediaQuery.of(context).viewPadding.top + 8,
                left: 0,
                right: 0,
                child: RatingWaitBanner(
                  otherPartyLabel: 'passenger',
                  onDismiss: () => driver.clearAwaitingRating(),
                ),
              );
            },
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
  final VoidCallback? onTap;

  const _NavIconBtn({
    required this.icon,
    required this.label,
    required this.color,
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        (onTap != null ? color : AppColors.textSecondary)
                            .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: onTap != null ? color : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DriverNavBar extends StatelessWidget {
  final bool isGuest;
  final VoidCallback onSetRoute;
  final VoidCallback onPlanTrip;
  final VoidCallback onFindTrips;
  final VoidCallback onShowAccount;

  const _DriverNavBar({
    required this.isGuest,
    required this.onSetRoute,
    required this.onPlanTrip,
    required this.onFindTrips,
    required this.onShowAccount,
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
            icon: Icons.add_road_rounded,
            label: 'Route',
            color: AppColors.primary,
            onTap: onSetRoute,
          ),
          _NavIconBtn(
            icon: Icons.event_available_rounded,
            label: 'Plan',
            color: AppColors.primary,
            onTap: isGuest ? null : onPlanTrip,
          ),
          _NavIconBtn(
            icon: Icons.search_rounded,
            label: 'Find',
            color: AppColors.primary,
            onTap: onFindTrips,
          ),
          _NavIconBtn(
            icon: Icons.manage_accounts_rounded,
            label: 'Account',
            color: AppColors.primary,
            onTap: onShowAccount,
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

  List<_PlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;
  LatLng? _selectedLatLng;

  void _onDestChanged(String v) {
    _selectedLatLng = null;
    _debounce?.cancel();
    if (v.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(v);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _loadingSuggestions = true);
    try {
      final origin = widget.originPos;
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
    if (mounted) setState(() => _loadingSuggestions = false);
  }

  void _selectSuggestion(_PlaceSuggestion s) {
    _dest.text = s.name;
    _selectedLatLng = LatLng(s.lat, s.lng);
    setState(() => _suggestions = []);
    _debounce?.cancel();
  }

  Future<void> _submit() async {
    if (_dest.text.trim().isEmpty) {
      setState(() => _error = 'Enter a destination');
      return;
    }
    setState(() {
      _geocoding = true;
      _error = null;
    });

    if (_selectedLatLng != null) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmit(
          _selectedLatLng!.latitude, _selectedLatLng!.longitude, _corridor, _seats);
      return;
    }

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
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            Text(
              l.setYourRoute,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _dest,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15),
              onChanged: _onDestChanged,
              decoration: InputDecoration(
                hintText: l.destination,
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _loadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            if (_suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return InkWell(
                        onTap: () => _selectSuggestion(s),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.place_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
                Text(
                  l.corridorRadius,
                  style: const TextStyle(
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
                Text(
                  l.availableSeats,
                  style: const TextStyle(
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
                    : Text(l.findPassengers),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String name;
  final double lat;
  final double lng;
  const _PlaceSuggestion(
      {required this.name, required this.lat, required this.lng});
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

class _AccountSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String role;
  final bool isGuest;
  final LatLng? currentPos;
  final VoidCallback onSwitchRole;
  final VoidCallback onShowLanguage;
  final VoidCallback onShowMapStyle;
  final void Function(String? name, String? email) onShowAccountSecurity;
  final VoidCallback onSignOut;

  const _AccountSheet({
    required this.scrollController,
    required this.role,
    required this.isGuest,
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
          _co2Saved = (data['co2_saved_kg'] as num).toDouble();
          _tripsCount = (data['trips_count'] as num).toInt();
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
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        controller: widget.scrollController,
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
          const SizedBox(height: 12),
          Skeletonizer(
            enabled: _co2Saved == null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(_co2Saved ?? 24.6).toStringAsFixed(1)} kg CO₂ saved',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_tripsCount ?? 8} shared trip${(_tripsCount ?? 8) == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          if (!widget.isGuest)
            _SheetTile(
              icon: Icons.manage_accounts_rounded,
              label: l.accountSecurity,
              onTap: () => widget.onShowAccountSecurity(_userName, _userEmail),
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
          if (!widget.isGuest) ...[
            _SheetTile(
              icon: Icons.event_available_rounded,
              label: l.planATrip,
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => TripPlannerSheet(currentPos: widget.currentPos),
                );
              },
            ),
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
          ],
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
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
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
                  color: AppColors.primary, size: 20),
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
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 20),
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
            l.signInShareDesc,
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
