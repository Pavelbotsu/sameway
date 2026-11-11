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
import '../../core/error_handling.dart';
import '../../core/fcm_service.dart';
import '../../core/feature_flags.dart';
import '../../core/geo.dart';
import '../../core/haptics.dart';
import '../../core/app_localizations.dart';
import '../../core/map_centering.dart';
import '../../core/map_style_provider.dart';
import '../../core/place_search.dart';
import '../../core/widgets/map_attribution.dart';
import '../../core/matching_preference_provider.dart';
import '../../core/token_storage.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/widgets/ai_match_chip.dart';
import '../../core/widgets/map_pick_button.dart';
import '../../core/widgets/animated_map_marker.dart';
import '../../core/widgets/ai_matching_toggle_tile.dart';
import '../../core/widgets/bug_report_sheet.dart';
import '../../core/widgets/car_edit_sheet.dart';
import '../../core/widgets/connectivity_pill.dart';
import '../../core/widgets/license_plate_chip.dart';
import '../../core/widgets/map_destination_picker.dart';
import '../../core/widgets/map_recenter_button.dart';
import '../../core/widgets/match_state_banner.dart';
import '../../core/widgets/pre_permission_sheet.dart';
import '../../core/widgets/sos_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/sheet_grab_handle.dart';
import '../../core/widgets/test_ai_tile.dart';
import '../../core/widgets/walk_to_pickup_banner.dart';
import '../../core/wkt.dart';
import '../onboarding/onboarding_screen.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/language_sheet.dart';
import '../../core/widgets/rating_wait_banner.dart';
import '../../core/widgets/ride_check_in_sheet.dart';
import '../../core/widgets/m3_expressive/wave_progress_indicator.dart';
import '../../core/widgets/role_switch_sheet.dart';
import '../driver/driver_home_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../account/account_security_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/conversations_screen.dart';
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

class _PassengerHomeScreenState extends State<PassengerHomeScreen>
    with WidgetsBindingObserver {
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
  // True while the user is picking a destination by panning the map under the
  // centre pin (entered from the destination field's location button).
  bool _pickingDest = false;

  /// Captured here rather than read in [dispose].
  ///
  /// By the time `State.dispose()` runs, `StatefulElement.unmount()` has already
  /// marked the element defunct and nulled its inherited-element map, so
  /// `context.read<T>()` throws — an assert ("Looking up a deactivated widget's
  /// ancestor is unsafe") in debug, `ProviderNotFoundException` in release.
  /// Either way `dispose()` aborts before `super.dispose()`, the exception
  /// escapes `_InactiveElements._unmountAll`, and every element still queued
  /// for unmount is left half torn down — which is what surfaced as the
  /// `InheritedElement` assertion storm on role switch.
  ///
  /// Non-`final`: `didChangeDependencies` may run more than once.
  late PassengerProvider _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<PassengerProvider>();
  }

  /// A plain method rather than a closure stored in a `late` field: the field
  /// was assigned inside the post-frame callback that registered it, so a screen
  /// torn down before that frame landed made [dispose] throw
  /// `LateInitializationError`, corrupting teardown the same way [_provider]
  /// describes. Dart gives instance-method tear-offs value equality, so
  /// `removeListener(_onRatingPending)` still matches the `addListener` call.
  void _onRatingPending() {
    final provider = _provider;
    if (provider.pendingRatingRequestId == null ||
        provider.pendingRatingDriverId == null ||
        !mounted) {
      return;
    }
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

  /// Mid-ride safety check-in. Same shape as [_onRatingPending]: clear the
  /// provider flag BEFORE showing, so a rebuild mid-sheet can't re-open it.
  void _onCheckInPrompt() {
    final provider = _provider;
    if (!provider.checkInPrompt || !mounted) return;
    provider.clearCheckInPrompt();
    RideCheckInSheet.show(
      context,
      otherPartyLabel: AppLocalizations.of(context).driver,
      lat: _myPos?.latitude,
      lng: _myPos?.longitude,
      driverName: provider.acceptedDriverName,
      plate: provider.acceptedCarPlate,
      onNeedHelp: provider.flagSafety,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // Mirrors the driver-side interval; active_passengers rows are filtered
      // on `updated_at > NOW() - 10 minutes` in the corridor query, but a
      // tighter ping also keeps the reverse-trigger match responsive.
      _locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendLocation(),
      );
      // The server pushes `nearby_changed` when drivers around change; the
      // timer is only a fallback (lost socket, missed event).
      _driversTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _fetchNearbyDrivers(),
      );
      _nearbySub = provider.nearbyChanged.listen((_) => _onNearbyChanged());
      _fetchNearbyDrivers();

      provider.addListener(_onRatingPending);
      provider.addListener(_onCheckInPrompt);
      _noticeSub = provider.notices.listen(_onNotice);
    });
  }

  StreamSubscription<PassengerNotice>? _noticeSub;

  void _onNotice(PassengerNotice notice) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final (text, color) = switch (notice) {
      PassengerNotice.pickupCodeReset => (l.pickupCodeResetNotice, AppColors.teal),
      PassengerNotice.cancelledNoShow => (l.rideCancelledNoShow, AppColors.error),
      PassengerNotice.cancelledTimeout => (l.rideCancelledTimeout, AppColors.error),
      PassengerNotice.cancelledDriverEnded =>
        (l.rideCancelledDriverEnded, AppColors.error),
      PassengerNotice.outsideServiceArea =>
        (l.outsideServiceArea, AppColors.teal),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  /// False while the app is in the background. The nearby-drivers poll only
  /// feeds the map, and it is the heaviest query the server runs, so it is
  /// skipped while nobody can see the result. Location updates keep going:
  /// they keep the passenger matchable.
  bool _inForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final was = _inForeground;
    _inForeground = state == AppLifecycleState.resumed;
    // Back on screen: refresh at once instead of waiting for the next tick.
    if (_inForeground && !was) _fetchNearbyDrivers();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _driversTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _noticeSub?.cancel();
    _nearbySub?.cancel();
    // The rating listener was never removed. PassengerProvider is root-scoped
    // and outlives this screen, so every navigation away and back stacked
    // another listener holding a dead BuildContext — the rating sheet fired
    // once per past visit and eventually threw on an unmounted context.
    //
    // Uses the captured _provider, never context.read: see the field's doc.
    _provider.removeListener(_onRatingPending);
    _provider.removeListener(_onCheckInPrompt);
    // Detach from the shared socket, but do NOT disconnect it — DriverProvider
    // uses the same one.
    _provider.detachWS();
    _sheetCtrl.dispose();
    super.dispose();
  }

  /// Guards against overlapping polls. The timer fires every 10s but this call
  /// hits the heaviest PostGIS query in the app; without the guard a slow
  /// response let requests pile up on top of each other.
  bool _fetchingNearby = false;

  StreamSubscription<void>? _nearbySub;
  DateTime? _lastNearbyFetch;

  /// Refresh on a server hint, but at most every 5 s: several drivers moving
  /// at once shouldn't turn into a burst of requests.
  void _onNearbyChanged() {
    final last = _lastNearbyFetch;
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _fetchNearbyDrivers();
  }

  Future<void> _fetchNearbyDrivers() async {
    if (_myPos == null || _fetchingNearby || !_inForeground) return;
    _fetchingNearby = true;
    _lastNearbyFetch = DateTime.now();
    try {
      // Via the repository/ApiClient rather than a raw http.post: that path had
      // no timeout at all and skipped the 401 → session-expiry handling, so an
      // expired token here just failed silently forever.
      final list = await context.read<PassengerProvider>().nearbyDrivers(
            lat: _myPos!.latitude,
            lng: _myPos!.longitude,
            destLat: _destPos?.latitude,
            destLng: _destPos?.longitude,
          );
      if (!mounted) return;
      setState(() {
        _nearbyDrivers = list.map(_NearbyDriverInfo.fromJson).toList();
      });
      // The provider owns the match-state machine; feed it the count of
      // algorithm-endorsed (likely_match) drivers, not raw proximity.
      if (!widget.isGuest) {
        context.read<PassengerProvider>().setNearbyLikelyCount(
            _nearbyDrivers.where((d) => d.likelyMatch).length);
      }
    } catch (_) {
      // Transient: the next tick retries. Session expiry is already surfaced
      // globally by ApiClient.
    } finally {
      _fetchingNearby = false;
    }
  }

  Future<void> _requestRide(_NearbyDriverInfo driver) async {
    if (widget.isGuest) return;
    final provider = context.read<PassengerProvider>();
    final ok = await provider.sendRequestToDriver(driver.driverId);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.rideRequestSent : (provider.error ?? l.requestFailed)),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Row keys for the candidate list, so a map-marker tap can scroll the
  /// matching row into view. Keyed by driver id and reused across rebuilds.
  final Map<String, GlobalKey> _candidateRowKeys = {};

  /// Marker tap: select, raise the sheet, and scroll the list to the row.
  /// The mirror of [_onCandidateRowTap].
  void _onDriverMarkerTap(_NearbyDriverInfo driver) {
    Haptics.light();
    setState(() => _selectedDriver = driver);
    if (_sheetCtrl.isAttached && _sheetCtrl.size < 0.55) {
      _sheetCtrl.animateTo(0.55,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
    // After the frame the sheet has laid out at its new height, so the row's
    // context exists and ensureVisible can measure it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _candidateRowKeys[driver.driverId]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    });
  }

  /// Row tap: select and centre the map on that driver. The mirror of
  /// [_onDriverMarkerTap]; both write the same `_selectedDriver`.
  void _onCandidateRowTap(_NearbyDriverInfo driver) {
    Haptics.light();
    setState(() => _selectedDriver = driver);
    final fraction = _sheetCtrl.isAttached ? _sheetCtrl.size : 0.55;
    centerOnUserAdjustedForSheet(
      context: context,
      mapController: _mapController,
      pos: driver.origin,
      sheetCoverFraction: fraction,
    );
  }

  void _showDriverInfo(_NearbyDriverInfo driver) {
    setState(() => _selectedDriver = driver);
    // Intentionally NOT clearing `_selectedDriver` when the sheet dismisses:
    // users dismiss it to peek at the map and then want to come back to the
    // driver they were viewing. The selection persists until they tap a
    // different driver or change destination. A floating chip on the map
    // ([_SelectedDriverChip] below) lets them re-open the info sheet.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DriverInfoSheet(
        driver: driver,
        destination: _destPos,
        onRequest: () {
          Navigator.pop(context);
          _requestRide(driver);
        },
      ),
    );
  }

  /// Match-state banner tap: raise the bottom sheet to the detail that
  /// matches the state (offer card / request list / accepted card all live
  /// in the sheet). Already-raised sheet goes to full height.
  void _onMatchBannerTap() {
    Haptics.light();
    if (!_sheetCtrl.isAttached) return;
    final target = _sheetCtrl.size >= 0.5 ? 0.85 : 0.55;
    _sheetCtrl.animateTo(target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  /// Re-centers the map on the user, accounting for however far the bottom
  /// sheet is currently dragged so the marker lands in the middle of the
  /// *visible* map area rather than behind the sheet. Falls back to a fresh
  /// location fetch if we don't have a fix yet.
  Future<void> _recenterOnUser() async {
    Haptics.light();
    if (_myPos == null) {
      await _initLocation();
      return;
    }
    final fraction = _sheetCtrl.isAttached ? _sheetCtrl.size : 0.55;
    centerOnUserAdjustedForSheet(
      context: context,
      mapController: _mapController,
      pos: _myPos!,
      sheetCoverFraction: fraction,
    );
  }

  // ── Pick-destination-on-map mode ───────────────────────────────────────────

  /// Enter map-pick mode: shrink the sheet to ~30% so the map is exposed, and
  /// centre on a sensible start point. The fixed centre pin (MapDestinationPicker)
  /// then tracks the map centre; confirm reads it back.
  void _enterDestPickMode() {
    setState(() => _pickingDest = true);
    final start = _destPos ?? _myPos;
    if (start != null) {
      _mapController.move(start, _mapController.camera.zoom);
    }
    if (_sheetCtrl.isAttached) {
      _sheetCtrl.animateTo(0.3,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _confirmDestPick() async {
    Haptics.light();
    final center = _mapController.camera.center;
    final name = await _reverseGeocode(center);
    if (!mounted) return;
    setState(() => _pickingDest = false);
    _applyDestination(center, name);
    if (_sheetCtrl.isAttached) {
      _sheetCtrl.animateTo(0.55,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  void _cancelDestPick() {
    setState(() => _pickingDest = false);
    if (_sheetCtrl.isAttached) {
      _sheetCtrl.animateTo(0.55,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  /// Apply a chosen destination — the shared path for both the search-suggestion
  /// tap and the map pick: store it, drop any solo-focused driver, kick off the
  /// search + nearby refresh.
  void _applyDestination(LatLng pos, String name) {
    setState(() {
      _destPos = pos;
      _destName = name;
      _selectedDriver = null;
    });
    if (!widget.isGuest) {
      final preferAI = context.read<MatchingPreferenceProvider>().useAI;
      context
          .read<PassengerProvider>()
          .setSearchDestination(pos, preferAI: preferAI);
    }
    _fetchNearbyDrivers();
  }

  /// Reverse-geocode a pinned point into a short label, falling back to
  /// coordinates when the lookup fails.
  Future<String> _reverseGeocode(LatLng p) async {
    try {
      final places = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (places.isNotEmpty) {
        final pm = places.first;
        final parts = [pm.street, pm.locality, pm.administrativeArea, pm.country]
            .where((s) => s != null && s.isNotEmpty)
            .take(2)
            .join(', ');
        if (parts.isNotEmpty) return parts;
      }
    } catch (_) {}
    return '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
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
      centerOnUserAdjustedForSheet(
        context: context,
        mapController: _mapController,
        pos: latlng,
      );
      if (!widget.isGuest) {
        await context
            .read<PassengerProvider>()
            .updateLocation(pos.latitude, pos.longitude);
      }
      // Phase 1.7: now that location is sorted, prompt for notifications
      // (once per install). Done after location so users understand why we
      // want to ping them.
      if (mounted) {
        await FcmService.maybeRequestPermissionWithRationale(context);
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
      // Phase 1.7: show our in-app rationale before the OS prompt. Only
      // once per install so we don't nag — the flag survives across
      // permission resets, which is fine: returning users have already
      // accepted/declined the OS prompt itself by then.
      final storage = TokenStorage();
      final shown = await storage.hasShownLocationRationale();
      if (!shown && mounted) {
        final accepted = await PrePermissionSheet.askLocation(context);
        await storage.markLocationRationaleShown();
        if (!accepted) throw Exception('Location permission deferred');
      }
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

  List<LatLng> _parseWKT(String wkt) => parseLineStringWKT(wkt);

  void _showLanguageSheet() {
    LanguageSheet.show(context);
  }

  void _showBugReportSheet() {
    BugReportSheet.show(context);
  }

  void _showOnboardingReplay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen(replay: true)),
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
          onShowAccountSecurity: (name, email) {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 200),
                () => _openAccountSecurity(name, email));
          },
          onReportBug: () {
            Navigator.pop(context);
            Future.delayed(
                const Duration(milliseconds: 200), _showBugReportSheet);
          },
          onShowTutorial: () {
            Navigator.pop(context);
            Future.delayed(
                const Duration(milliseconds: 200), _showOnboardingReplay);
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
                        otherPartyName: AppLocalizations.of(context).driver,
                      ),
                    ),
                  )
              : null,
          onShowTrips: _showTripSearch,
          onShowPromotions: _showPromotions,
          onReportBug: _showBugReportSheet,
          onShowAccount: _showAccountSheet,
        ),
        body: Stack(
          // Every direct child below carries a stable key, and that is
          // load-bearing — do not "tidy" them away.
          //
          // Three children are conditional and sit ABOVE the sheet, and the last
          // two swap type (recenter button <-> map picker). Element.updateChildren
          // matches UNKEYED children by position: it scans top-down until a
          // mismatch, then bottom-up until a mismatch, and destroys whatever
          // unkeyed children are left in the middle. Confirming a map pick
          // inserts the match banner (idle -> searching) AND flips the tail in
          // the same frame, so the bottom-up scan stops immediately and the
          // DraggableScrollableSheet lands in that middle range.
          //
          // Destroying it is fatal: the replacement sheet's initState calls
          // _sheetCtrl._attach() before the old sheet's dispose() detaches,
          // which trips `assert(_attachedController == null)`, and the old
          // dispose() then runs _detach(disposeExtent: true) against the LIVE
          // sheet — leaving _sheetCtrl.isAttached false forever, so dragging,
          // snapping and every animateTo silently stop working.
          //
          // With keys, the sheet is matched by key instead of position and its
          // element (and _LookingCard's text field) survives.
          children: [
            FlutterMap(
              key: const ValueKey('map'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myPos ?? const LatLng(50.0647, 19.9450),
                initialZoom: 14,
              ),
              children: [
                Consumer<MapStyleProvider>(
                  builder: (_, mapStyle, __) => TileLayer(
                    urlTemplate: mapStyle.urlTemplate,
                    userAgentPackageName: kMapUserAgentPackage,
                    tileBuilder: mapStyle.tileBuilder,
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
                // Walking line: passenger origin → suggested pickup point on
                // the driver's road. Only rendered while a fresh offer is
                // pending and the WS payload included pickup coords.
                Consumer<PassengerProvider>(
                  builder: (_, p, __) {
                    final offer = p.pendingOffer;
                    if (p.state != PassengerStatus.offered ||
                        offer == null ||
                        offer.pickupLat == null ||
                        offer.pickupLng == null ||
                        _myPos == null) {
                      return const SizedBox.shrink();
                    }
                    final pickup = LatLng(offer.pickupLat!, offer.pickupLng!);
                    return Stack(
                      children: [
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_myPos!, pickup],
                              color: AppColors.teal,
                              strokeWidth: 2.5,
                              pattern: StrokePattern.dashed(
                                  segments: const [10, 6]),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pickup,
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.directions_walk_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                if (_nearbyDrivers.isNotEmpty)
                  MarkerLayer(
                    // `matched` = the server flagged this driver likely_match:
                    // the same forward-projection + carry filters corridor
                    // push uses consider them same-way for the passenger's
                    // destination. Everyone else — including drivers who are
                    // merely nearby while a destination IS set — renders as a
                    // small subtle dot, so the big green pin now means
                    // "algorithm-endorsed", not "close by".
                    //
                    // Selection HIGHLIGHTS rather than solo-focuses.
                    //
                    // This used to hide every unselected driver, to stop a
                    // cluster of overlapping pins being unreadable. The
                    // candidate list in the sheet now does that
                    // disambiguation, and hiding the others actively fights
                    // it: tapping a row should show you where that driver sits
                    // AMONG the rest, not blank the map. _DriverMarker already
                    // draws a brighter ring when selected.
                    markers: _nearbyDrivers.map((d) {
                      final isSelected =
                          _selectedDriver?.driverId == d.driverId;
                      final matched = d.likelyMatch;
                      final size = isSelected || matched ? 56.0 : 24.0;
                      return Marker(
                        point: d.origin,
                        width: size,
                        height: size,
                        child: GestureDetector(
                          // Selects + scrolls the list to this driver, instead
                          // of opening a modal over the map. The row's chevron
                          // is the way into the details sheet.
                          onTap: () => _onDriverMarkerTap(d),
                          child: _DriverMarker(
                            selected: isSelected,
                            matched: matched,
                          ),
                        ),
                      );
                    }).toList(),
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
                // Licence credit for the current tile style (always visible).
                Consumer<MapStyleProvider>(
                  builder: (_, mapStyle, __) =>
                      MapAttribution(text: mapStyle.attribution),
                ),
              ],
            ),

            // Top bar
            Positioned(
              key: const ValueKey('topBar'),
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
                                  color: AppColors.mapLabelText,
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
                              tooltip: AppLocalizations.of(context).language,
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
                              tooltip: AppLocalizations.of(context).account,
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

            if (p.awaitingRatingRequestId != null)
              Positioned(
                key: const ValueKey('ratingWaitBanner'),
                top: MediaQuery.of(context).viewPadding.top + 8,
                left: 0,
                right: 0,
                child: RatingWaitBanner(
                  otherPartyLabel: 'driver',
                  onDismiss: () => p.clearAwaitingRating(),
                ),
              ),

            // Connectivity / WS status pill — auto-hides when both healthy.
            ConnectivityPill(
              key: const ValueKey('connectivityPill'),
              wsState: p.wsState,
              locationFailing: p.locationSyncFailing,
            ),

            // Match-state banner (Round 2 §6): the one prominent, tappable
            // surface for searching → candidates → offer → requested →
            // matched → in-progress. Pinned under the top bar so every
            // transition is visible without touching the sheet.
            if (!widget.isGuest && p.matchUiState != MatchUiState.idle)
              Positioned(
                key: const ValueKey('matchStateBanner'),
                top: MediaQuery.of(context).viewPadding.top + 64,
                left: 16,
                right: 16,
                child: MatchStateBanner(
                  state: p.matchUiState,
                  likelyCount: p.likelyMatchCount,
                  driverName: p.acceptedDriverName,
                  relayLeg2: p.relayLeg2Search,
                  onTap: _onMatchBannerTap,
                ),
              ),

            if (_selectedDriver != null)
              Positioned(
                key: const ValueKey('selectedDriverChip'),
                // Sits below the match-state banner when one is showing.
                top: MediaQuery.of(context).viewPadding.top +
                    (p.matchUiState != MatchUiState.idle ? 156 : 72),
                left: 16,
                right: 16,
                child: Center(
                  child: _SelectedDriverChip(
                    name: _selectedDriver!.driverName,
                    onTap: () => _showDriverInfo(_selectedDriver!),
                    onClear: () =>
                        setState(() => _selectedDriver = null),
                  ),
                ),
              ),

            DraggableScrollableSheet(
              // The key that matters most — see the note on `children:` above.
              key: const ValueKey('statusSheet'),
              controller: _sheetCtrl,
              initialChildSize: 0.55,
              minChildSize: 0.26,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.55],
              builder: (_, scrollController) => _StatusPanel(
                provider: p,
                scrollController: scrollController,
                sheetCtrl: _sheetCtrl,
                isGuest: widget.isGuest,
                currentPos: _myPos,
                // Same-way drivers only — consistent with what corridor push
                // would offer, not raw proximity.
                nearbyCount:
                    _nearbyDrivers.where((d) => d.likelyMatch).length,
                candidates: _nearbyDrivers,
                selectedDriver: _selectedDriver,
                candidateRowKeys: _candidateRowKeys,
                onCandidateTap: _onCandidateRowTap,
                onCandidateDetails: _showDriverInfo,
                destName: _destName.isEmpty ? null : _destName,
                onDestinationSet: (pos, name) {
                  setState(() {
                    _destPos = pos;
                    _destName = name;
                    _selectedDriver = null; // new search invalidates selection
                  });
                  _fetchNearbyDrivers();
                },
                onClearDestination: () {
                  setState(() {
                    _destPos = null;
                    _destName = '';
                    _selectedDriver = null;
                  });
                  if (!widget.isGuest) {
                    context
                        .read<PassengerProvider>()
                        .clearSearchDestination();
                  }
                  _fetchNearbyDrivers();
                },
                onRefresh: () {
                  Haptics.light();
                  return _fetchNearbyDrivers();
                },
                onPickOnMap: _enterDestPickMode,
              ),
            ),

            // Floating "center on me" button — rides just above the sheet and
            // slides with it as it's dragged. Hidden while picking on the map
            // (the picker has its own action bar in that spot).
            if (!_pickingDest)
              MapRecenterButton(
                key: const ValueKey('recenterButton'),
                sheetController: _sheetCtrl,
                accentColor: AppColors.teal,
                onPressed: _recenterOnUser,
              ),

            // Map-pick overlay: fixed centre pin + confirm/cancel bar.
            if (_pickingDest)
              MapDestinationPicker(
                key: const ValueKey('mapDestinationPicker'),
                sheetController: _sheetCtrl,
                accent: AppColors.teal,
                title: AppLocalizations.of(context).moveMapToDestination,
                confirmLabel: AppLocalizations.of(context).setDestinationHere,
                onConfirm: _confirmDestPick,
                onCancel: _cancelDestPick,
              ),
          ],
        ),
      );
      },
    );
  }
}

/// Marker for matched drivers on the passenger map. Uses a vibrant green
/// (success color) and a larger footprint so it stays distinguishable when
/// several markers overlap. Tap target matches the marker size so even with
/// other passengers' devices nearby it is the easy hit.
///
/// When [selected] is true (user has opened this driver's info sheet), the
/// marker gets a brighter outer ring so the chosen driver is obvious on the
/// map even after the info sheet is dismissed.
class _DriverMarker extends StatelessWidget {
  /// True when the passenger tapped this driver — gets a tighter ring and
  /// a stronger glow so it pops on the otherwise empty (others-hidden) map.
  final bool selected;
  /// True when the backend returned this driver because their corridor
  /// covers the passenger's chosen destination. Drives the big-green vs
  /// small-grey-dot split: unmatched drivers are just nearby observers.
  final bool matched;
  const _DriverMarker({this.selected = false, this.matched = false});

  @override
  Widget build(BuildContext context) {
    if (!matched && !selected) {
      // Subtle informational dot. No glow, no icon — just a presence
      // signal so the passenger sees there's activity without confusing
      // it for an algorithm pick.
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: selected ? 4 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: selected ? 0.9 : 0.55),
            blurRadius: selected ? 22 : 14,
            spreadRadius: selected ? 4 : 2,
          ),
        ],
      ),
      child: const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 26),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final PassengerProvider provider;
  final bool isGuest;
  final LatLng? currentPos;
  final String? destName;
  // Count of nearby drivers; when a destination is set these are the
  // same-way drivers, surfaced on the destination card.
  final int nearbyCount;
  final ScrollController scrollController;
  final DraggableScrollableController sheetCtrl;
  final void Function(LatLng pos, String name) onDestinationSet;
  final VoidCallback onClearDestination;
  final Future<void> Function() onRefresh;
  // Enter "pick destination on the map" mode (from the search field's button).
  final VoidCallback onPickOnMap;
  // Live candidate drivers + the map/list selection they share.
  final List<_NearbyDriverInfo> candidates;
  final _NearbyDriverInfo? selectedDriver;
  final Map<String, GlobalKey> candidateRowKeys;
  final void Function(_NearbyDriverInfo) onCandidateTap;
  final void Function(_NearbyDriverInfo) onCandidateDetails;

  const _StatusPanel({
    required this.provider,
    required this.scrollController,
    required this.sheetCtrl,
    required this.onDestinationSet,
    required this.onClearDestination,
    required this.onRefresh,
    required this.onPickOnMap,
    required this.candidates,
    required this.candidateRowKeys,
    required this.onCandidateTap,
    required this.onCandidateDetails,
    this.selectedDriver,
    this.isGuest = false,
    this.currentPos,
    this.destName,
    this.nearbyCount = 0,
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
          SheetGrabHandle(
            controller: sheetCtrl,
            minChildSize: 0.26,
            maxChildSize: 0.85,
            snapSizes: const [0.55],
          ),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            // Pull-to-refresh kicks the periodic nearby-drivers fetch — gives
            // the user explicit control instead of waiting 10 s for the
            // polling timer. RefreshIndicator needs an inner scrollable that
            // can overscroll, which SingleChildScrollView does once we set
            // its physics to AlwaysScrollable.
            child: RefreshIndicator(
              color: AppColors.teal,
              backgroundColor: AppColors.surface,
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
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
                              distanceKm: provider.plannedDistanceKm,
                              nearbyCount: nearbyCount,
                              sheetCtrl: sheetCtrl,
                              onDestinationSet: onDestinationSet,
                              onClearDestination: onClearDestination,
                              onPickOnMap: onPickOnMap,
                              outstandingRequests:
                                  provider.outstandingRequests,
                              onCancelOutstanding: (id) =>
                                  provider.cancelOutstandingRequest(id),
                              candidates: candidates,
                              selectedDriver: selectedDriver,
                              candidateRowKeys: candidateRowKeys,
                              onCandidateTap: onCandidateTap,
                              onCandidateDetails: onCandidateDetails,
                            ),
                          PassengerStatus.offered => _OfferCard(
                              offer: provider.pendingOffer!,
                              onAccept: () => provider.acceptRide(),
                              onDecline: () => provider.declineRide(),
                            ),
                          PassengerStatus.accepted => _AcceptedCard(
                              requestId: provider.acceptedRequestId,
                              driverId: provider.acceptedDriverId,
                              driverName: provider.acceptedDriverName,
                              driverAge: provider.acceptedDriverAge,
                              driverPhotoUrl: provider.acceptedDriverPhotoUrl,
                              carSummary: provider.acceptedCarSummary,
                              carPlate: provider.acceptedCarPlate,
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
                              inRide: false,
                              onConfirmPickup: (code) =>
                                  provider.confirmPickup(code),
                              onCancel: () => provider.cancelRide(),
                            ),
                          PassengerStatus.inRide => _AcceptedCard(
                              requestId: provider.acceptedRequestId,
                              driverId: provider.acceptedDriverId,
                              driverName: provider.acceptedDriverName,
                              driverAge: provider.acceptedDriverAge,
                              driverPhotoUrl: provider.acceptedDriverPhotoUrl,
                              carSummary: provider.acceptedCarSummary,
                              carPlate: provider.acceptedCarPlate,
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
                              inRide: true,
                              onConfirmPickup: null,
                              // No cancel once on board: PassengerCancelRide
                              // filters on `status = 'accepted'`, so this button
                              // only ever produced a 400 here. The mid-ride
                              // escape is the SOS pill / check-in prompt.
                              onCancel: null,
                            ),
                          PassengerStatus.declined =>
                            const _DeclinedCard(),
                        },
                      ),
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
  final VoidCallback onReportBug;
  final VoidCallback onShowAccount;

  const _PassengerNavBar({
    required this.unreadMessages,
    required this.isGuest,
    required this.onShowTrips,
    required this.onShowPromotions,
    required this.onReportBug,
    required this.onShowAccount,
    this.onShowChat,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            label: l.navChat,
            color: AppColors.teal,
            badge: unreadMessages > 0 ? unreadMessages : null,
            onTap: onShowChat,
          ),
          if (FeatureFlags.plannedTrips)
            _NavIconBtn(
              icon: Icons.search_rounded,
              label: l.navFindTrips,
              color: AppColors.teal,
              onTap: isGuest ? null : onShowTrips,
            ),
          if (FeatureFlags.promotions)
            _NavIconBtn(
              icon: Icons.local_offer_rounded,
              label: l.navOffers,
              color: AppColors.teal,
              onTap: onShowPromotions,
            ),
          _NavIconBtn(
            icon: Icons.bug_report_rounded,
            label: l.navReportBug,
            color: AppColors.teal,
            onTap: isGuest ? null : onReportBug,
          ),
          _NavIconBtn(
            icon: Icons.manage_accounts_rounded,
            label: l.navAccount,
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
  // Planned route distance to the destination (km) and the count of nearby
  // same-way drivers — shown as ride info on the destination card.
  final double? distanceKm;
  final int nearbyCount;
  // The persistent sheet's controller — used to lift the sheet above the
  // keyboard when the destination field gains focus.
  final DraggableScrollableController sheetCtrl;
  final void Function(LatLng pos, String name) onDestinationSet;
  final VoidCallback onClearDestination;
  final VoidCallback onPickOnMap;
  final List<OutstandingRequest> outstandingRequests;
  final void Function(String requestId) onCancelOutstanding;
  // Live candidate drivers, and the selection shared with the map markers.
  final List<_NearbyDriverInfo> candidates;
  final _NearbyDriverInfo? selectedDriver;
  final Map<String, GlobalKey> candidateRowKeys;
  final void Function(_NearbyDriverInfo) onCandidateTap;
  final void Function(_NearbyDriverInfo) onCandidateDetails;

  const _LookingCard({
    required this.onDestinationSet,
    required this.onClearDestination,
    required this.onPickOnMap,
    required this.outstandingRequests,
    required this.onCancelOutstanding,
    required this.sheetCtrl,
    required this.candidates,
    required this.candidateRowKeys,
    required this.onCandidateTap,
    required this.onCandidateDetails,
    this.selectedDriver,
    this.currentPos,
    this.destName,
    this.distanceKm,
    this.nearbyCount = 0,
  });

  @override
  State<_LookingCard> createState() => _LookingCardState();
}

class _LookingCardState extends State<_LookingCard> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<_PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;
  final _placeSearch = PlaceSearch();

  @override
  void initState() {
    super.initState();
    // Rebuild so the clear (X) button toggles live as the user types.
    _ctrl.addListener(_onCtrlChanged);
    _focus.addListener(_onFocusChanged);
  }

  void _onCtrlChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    // The passenger Scaffold has resizeToAvoidBottomInset:false, so the sheet
    // won't move on its own when the keyboard opens. Lift it near-fullscreen so
    // the destination field stays visible above the keyboard.
    if (_focus.hasFocus &&
        widget.sheetCtrl.isAttached &&
        widget.sheetCtrl.size < 0.85) {
      widget.sheetCtrl.animateTo(
        0.85,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
    _ctrl.removeListener(_onCtrlChanged);
    _ctrl.dispose();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
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
    final found = await _placeSearch.search(
      query,
      near: widget.currentPos,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (found == null || !mounted) return; // superseded by a newer query
    setState(() {
      _suggestions = found
          .map((s) => _PlaceSuggestion(name: s.name, lat: s.lat, lng: s.lng))
          .toList();
      _loading = false;
    });
  }

  void _select(_PlaceSuggestion s) {
    _ctrl.text = s.name.split(',').first.trim();
    setState(() => _suggestions = []);
    final pos = LatLng(s.lat, s.lng);
    widget.onDestinationSet(pos, s.name);
    final preferAI = context.read<MatchingPreferenceProvider>().useAI;
    context.read<PassengerProvider>().setSearchDestination(pos, preferAI: preferAI);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasDestination = widget.destName != null;
    // Only genuinely-awaiting-driver requests belong in this panel. Accepted /
    // in-progress rides are represented by the accepted-ride card; showing them
    // here made them look like history / available offers.
    final pending = widget.outstandingRequests
        .where((r) => r.status == 'pending')
        .toList();
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
          focusNode: _focus,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: l.whereDoYouWantToGo,
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
            // Location icon doubles as the "pick a point on the map" button —
            // the tinted circle makes it read as tappable.
            prefixIcon: MapPickButton(
              accent: AppColors.teal,
              tooltip: l.pickOnMap,
              onPressed: widget.onPickOnMap,
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            // Clear (X) shows whenever there is text — while typing, not only
            // after a destination is committed.
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.teal),
                    ),
                  )
                : _ctrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: l.clear,
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _suggestions = []);
                          if (hasDestination) widget.onClearDestination();
                        },
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
        if (hasDestination) ...[
          const SizedBox(height: 14),
          _DestinationCard(
            name: widget.destName!,
            distanceKm: widget.distanceKm,
            driversNearby: widget.nearbyCount,
          ),
          const SizedBox(height: 10),
          _MatchTipsCard(destName: widget.destName!),
        ],
        // Where the match banner's tap now lands. Only shown once a
        // destination is set — without one there is no same-way verdict to
        // report and the list would just be "every car near you".
        if (hasDestination) ...[
          const SizedBox(height: 18),
          _CandidateDriversList(
            drivers: widget.candidates,
            selected: widget.selectedDriver,
            passengerPos: widget.currentPos,
            rowKeys: widget.candidateRowKeys,
            onSelect: widget.onCandidateTap,
            onOpenDetails: widget.onCandidateDetails,
          ),
        ],
        // The old inline "Searching…" tile lived here; the pinned
        // MatchStateBanner on the map (Round 2 §6) is the state surface now.
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 18),
          // Header so these tiles aren't mistaken for available rides — they
          // are the passenger's own pending requests, awaiting a driver, which
          // look visually similar to driver offer cards.
          Row(
            children: [
              const Icon(Icons.outbox_rounded,
                  color: AppColors.textSecondary, size: 15),
              const SizedBox(width: 6),
              Text(
                l.yourRequests,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              l.yourRequestsHint,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          ...pending.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OutstandingRequestTile(
                req: r,
                onCancel: () => widget.onCancelOutstanding(r.requestId),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Compact summary of the passenger's chosen destination, shown near the top
/// of the "looking" panel once a destination is set. Replaces the old CO₂/trip
/// stats card — in the ride-choosing flow what matters is *where you're going*
/// and the ride info for it (distance, est. time, same-way drivers), not
/// historical totals.
class _DestinationCard extends StatelessWidget {
  final String name;
  final double? distanceKm;
  final int driversNearby;
  const _DestinationCard({
    required this.name,
    this.distanceKm,
    this.driversNearby = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasDistance = distanceKm != null && distanceKm! > 0;
    // No server-side duration; estimate from distance at the assumed driver
    // speed — same helper the walk/pickup ETAs use.
    final mins =
        hasDistance ? minutesAt(distanceKm! * 1000, assumedDriverKmh) : null;
    final stats = <Widget>[
      if (hasDistance)
        _DestStat(
            icon: Icons.straighten_rounded,
            label: '${distanceKm!.toStringAsFixed(1)} km'),
      if (mins != null)
        _DestStat(icon: Icons.schedule_rounded, label: '~$mins min'),
      if (driversNearby > 0)
        _DestStat(
          icon: Icons.directions_car_rounded,
          label: l.driversHeadingYourWay(driversNearby),
          accent: true,
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.yourDestination,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 6, children: stats),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled stat chip on the destination card (distance / est. time /
/// same-way driver count). [accent] tints it teal to draw the eye to the
/// driver count.
class _DestStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  const _DestStat(
      {required this.icon, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.teal : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: accent ? AppColors.teal : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// "Tips to get matched" card. Fetches the backend match-advice diagnostic
/// (POST /passenger/match-advice) and renders its ordered suggestion codes as
/// localized tips. Hidden when there are no suggestions. Re-fetches when the
/// destination changes.
class _MatchTipsCard extends StatefulWidget {
  final String destName;
  const _MatchTipsCard({required this.destName});

  @override
  State<_MatchTipsCard> createState() => _MatchTipsCardState();
}

class _MatchTipsCardState extends State<_MatchTipsCard> {
  List<String> _codes = const [];
  double _tripKm = 0;
  int _nearestM = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void didUpdateWidget(_MatchTipsCard old) {
    super.didUpdateWidget(old);
    if (old.destName != widget.destName) _fetch();
  }

  Future<void> _fetch() async {
    final advice = await context.read<PassengerProvider>().fetchMatchAdvice();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _codes = (advice?['suggestions'] as List?)?.cast<String>() ?? const [];
      _tripKm = (advice?['trip_distance_km'] as num?)?.toDouble() ?? 0;
      _nearestM =
          ((advice?['nearest_route_m'] as num?)?.toDouble() ?? 0).round();
    });
  }

  String? _text(AppLocalizations l, String code) {
    switch (code) {
      case 'trip_too_short':
        return l.adviceTripTooShort(_tripKm.toStringAsFixed(1));
      case 'walk_closer':
        return l.adviceWalkCloser(_nearestM);
      case 'enable_long_walk':
        return l.adviceEnableLongWalk;
      case 'no_same_way_drivers':
        return l.adviceNoSameWayDrivers;
      case 'no_drivers':
        return l.adviceNoDrivers;
      case 'set_destination':
        return l.adviceSetDestination;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _codes.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final tips = _codes.map((c) => _text(l, c)).whereType<String>().toList();
    if (tips.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1606),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFFC857), size: 16),
              const SizedBox(width: 6),
              Text(
                l.adviceTitle,
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          for (final tip in tips) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
                                : AppLocalizations.of(context).driver,
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
                    ? AppLocalizations.of(context).waitingForDriver
                    : AppLocalizations.of(context).driverAccepted,
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
                  child: Text(AppLocalizations.of(context).cancel,
                      style: const TextStyle(
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
    return Semantics(
      container: true,
      label: l.semOffer(offer.driverName ?? l.passenger),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Driver avatar — photo or initials (Phase 1.3c). The Hero
            // tag is keyed by driverId so the avatar morphs smoothly when
            // the AnimatedSwitcher swaps offer → accepted card.
            UserAvatar(
              photoUrl: offer.driverPhotoUrl,
              name: offer.driverName,
              size: 48,
              heroTag: 'driver-avatar-${offer.driverId}',
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
                      if (offer.matchedByAI) ...[
                        const SizedBox(width: 8),
                        const AIMatchChip(),
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
        if (offer.walkDistanceM != null ||
            offer.driverDistanceToPickupM != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (offer.walkDistanceM != null)
                _PickupPill(
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.teal,
                  label: AppLocalizations.of(context).walkPill(
                      '${offer.walkDistanceM!.round()}',
                      '${minutesAt(offer.walkDistanceM!, walkSpeedKmh)}'),
                ),
              if (offer.walkDistanceM != null &&
                  offer.driverDistanceToPickupM != null)
                const SizedBox(width: 8),
              if (offer.driverDistanceToPickupM != null)
                _PickupPill(
                  icon: Icons.drive_eta_rounded,
                  color: AppColors.primary,
                  label: AppLocalizations.of(context).driverInMin(
                      '${minutesAt(offer.driverDistanceToPickupM!, assumedDriverKmh)}'),
                ),
            ],
          ),
        ],
        // Partial relay (Round 2 §1): the passenger explicitly opts into
        // "ride to the driver's route end, then continue" BEFORE accepting.
        // Never hidden in a sub-line — this changes what they're agreeing to.
        if (offer.isPartialRelay) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded,
                        color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.partialRideTitle,
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (offer.transitStopName?.isNotEmpty == true)
                      ? l.relayStopInfo(offer.transitStopName!,
                          (offer.transitStopDistM ?? 0).round())
                      : l.relayFallbackInfo,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Micro-detour (Round 2 §2): tell the passenger the driver comes to
        // their location — no walk needed.
        if (offer.isMicroDetour) ...[
          const SizedBox(height: 12),
          _PickupPill(
            icon: Icons.emoji_people_rounded,
            color: AppColors.success,
            label: l.microDetourPassengerNote,
          ),
        ],
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
                    child: Text(
                        // Relay accepts are labeled distinctly — the tap IS
                        // the opt-in to the two-leg plan.
                        offer.isPartialRelay ? l.acceptPartialRide : l.accept,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

class _PickupPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _PickupPill({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedCard extends StatefulWidget {
  final String? requestId;
  // Used to seed the Hero tag so the avatar morphs smoothly when the card
  // animates in/out of the AnimatedSwitcher.
  final String? driverId;
  final String? driverName;
  final int? driverAge;
  final String? driverPhotoUrl;
  final String? carSummary;
  final String? carPlate;
  final double? driverAvgRating;
  final int? driverRatingCount;
  final LatLng? passengerPos;
  final LatLng? driverPos;
  // Pickup handshake: present when the row is `accepted` and we haven't met
  // yet. When inRide is true, the card switches to the "on board" variant
  // and these are ignored.
  final bool inRide;
  final Future<PickupAttempt> Function(String code)? onConfirmPickup;
  final VoidCallback? onCancel;
  const _AcceptedCard({
    this.requestId,
    this.driverId,
    this.driverName,
    this.driverAge,
    this.driverPhotoUrl,
    this.carSummary,
    this.carPlate,
    this.driverAvgRating,
    this.driverRatingCount,
    this.passengerPos,
    this.driverPos,
    this.inRide = false,
    this.onConfirmPickup,
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

  /// Builds the three-leg polyline list (driver→pickup, pickup→destination,
  /// passenger→pickup walking) from the provider's road route. Falls back to
  /// a single straight line if the route fetch hasn't returned yet or
  /// failed.
  List<Polyline> _buildAcceptedPolylines({
    required LatLng passenger,
    required LatLng driver,
    required PassengerProvider provider,
  }) {
    final route = provider.pickupRoute;
    if (route == null) {
      return [
        Polyline(points: [passenger, driver], strokeWidth: 2, color: AppColors.teal),
      ];
    }
    final out = <Polyline>[];
    final pickup = parseLineStringWKT(route.pickupWkt);
    final continuation = parseLineStringWKT(route.continuationWkt);
    final walk = parseLineStringWKT(route.walkWkt);
    if (pickup.length >= 2) {
      out.add(Polyline(points: pickup, strokeWidth: 4, color: AppColors.teal));
    }
    if (continuation.length >= 2) {
      out.add(Polyline(
          points: continuation, strokeWidth: 3,
          color: AppColors.teal.withValues(alpha: 0.55)));
    }
    if (walk.length >= 2) {
      out.add(Polyline(
          points: walk, strokeWidth: 3, color: AppColors.teal,
          pattern: StrokePattern.dashed(segments: [6, 6])));
    }
    if (out.isEmpty) {
      out.add(Polyline(
          points: [passenger, driver], strokeWidth: 2, color: AppColors.teal));
    }
    return out;
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
    final driverLabel = widget.driverName ?? l.passenger;
    return Semantics(
      container: true,
      label: widget.inRide
          ? l.semInRide(driverLabel)
          : l.semAccepted(driverLabel),
      child: Column(
      children: [
        // SOS pill — always visible while a ride is accepted / in progress,
        // anchored top-right of the card so it's reachable mid-ride.
        Align(
          alignment: Alignment.centerRight,
          child: SosButton(
            lat: widget.passengerPos?.latitude,
            lng: widget.passengerPos?.longitude,
            driverName: widget.driverName,
            plate: widget.carPlate,
            requestId: widget.requestId,
          ),
        ),
        const SizedBox(height: 8),
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
              // Bloom: driver's profile photo (or initials fallback). Same
              // scale/rotate transition as the previous check icon so the
              // arrival moment still has weight (Phase 1.3c).
              RotationTransition(
                turns: _rotation,
                child: ScaleTransition(
                  scale: _scale,
                  child: UserAvatar(
                    photoUrl: widget.driverPhotoUrl,
                    name: widget.driverName,
                    size: 64,
                    heroTag: widget.driverId != null
                        ? 'driver-avatar-${widget.driverId}'
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.inRide ? l.youAreInTheRide : l.rideAccepted,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        // The passenger always types in the code (asymmetric handshake) — so
        // the block renders whenever we're in the `accepted` state, signaled
        // by a wired-up `onConfirmPickup` callback.
        if (!widget.inRide && widget.onConfirmPickup != null) ...[
          const SizedBox(height: 14),
          _PickupCodeBlock(onConfirm: widget.onConfirmPickup!),
        ],
        if (widget.driverName != null &&
            widget.driverName!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l.driverLabel}: ${widget.driverName}'
                '${widget.driverAge != null ? ' · ${l.ageYears(widget.driverAge!)}' : ''}',
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
        if (widget.carSummary != null || widget.carPlate != null) ...[
          const SizedBox(height: 8),
          // Structured "you're getting into this car" row. The plate chip is
          // the largest single element so it's the first thing a passenger
          // can match against the vehicle they see (Phase 1.1).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.carSummary != null) ...[
                const Icon(Icons.directions_car_rounded,
                    color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.carSummary!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.carPlate != null) const SizedBox(width: 10),
              ],
              if (widget.carPlate != null)
                LicensePlateChip(plate: widget.carPlate!),
            ],
          ),
        ],
        // Walk guidance. Deliberately NOT gated on driverPos: the pickup point
        // and walk distance arrive on the offer payload, long before the first
        // driver_location frame, and whether the passenger has to walk has
        // nothing to do with whether we've seen the car move yet. The mini-map
        // below still needs driverPos and keeps its own guard.
        if (widget.passengerPos != null) ...[
          const SizedBox(height: 14),
          Builder(builder: (context) {
            final p = context.watch<PassengerProvider>();
            if (p.pickupLat == null ||
                p.pickupLng == null ||
                p.walkDistanceM == null ||
                p.walkDistanceM! < WalkToPickupBanner.kStayPutMetres) {
              // Tier 1 — the "stay where you are" line below covers this.
              return const SizedBox.shrink();
            }
            // Tier 2 — worth saying, not worth a maps hand-off.
            if (p.walkDistanceM! < WalkToPickupBanner.minMetersForBanner) {
              return WalkToPickupCompact(walkDistanceM: p.walkDistanceM!);
            }
            // Tier 3 — full banner with walking directions.
            return WalkToPickupBanner(
              passengerLat: widget.passengerPos!.latitude,
              passengerLng: widget.passengerPos!.longitude,
              pickupLat: p.pickupLat!,
              pickupLng: p.pickupLng!,
              walkDistanceM: p.walkDistanceM!,
            );
          }),
        ],
        if (widget.passengerPos != null && widget.driverPos != null) ...[
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
                    userAgentPackageName: kMapUserAgentPackage,
                  ),
                  PolylineLayer(
                    polylines: _buildAcceptedPolylines(
                      passenger: widget.passengerPos!,
                      driver: widget.driverPos!,
                      provider: context.watch<PassengerProvider>(),
                    ),
                  ),
                  AnimatedMarkerPosition(
                    target: widget.driverPos!,
                    builder: (ctx, driverP) => MarkerLayer(
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
                          point: driverP,
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
                        if (context.watch<PassengerProvider>().pickupLat != null &&
                            context.watch<PassengerProvider>().pickupLng != null)
                          Marker(
                            point: LatLng(
                              context.watch<PassengerProvider>().pickupLat!,
                              context.watch<PassengerProvider>().pickupLng!,
                            ),
                            width: 44,
                            height: 44,
                            child: _PulsingPickupFlag(
                              // Pulse only when the passenger is within
                              // arrival range so the visual reward lands at
                              // the moment they're stepping up to the car.
                              active: _haversineKm(
                                    widget.passengerPos!,
                                    LatLng(
                                      context.read<PassengerProvider>().pickupLat!,
                                      context.read<PassengerProvider>().pickupLng!,
                                    ),
                                  ) <
                                  0.05,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const MapAttribution(),
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
        // Tier 1 ONLY. This used to render unconditionally, so a passenger with
        // a 400 m walk was shown the walk banner and "stay at your location"
        // at the same time. Exactly one of the three tiers may appear.
        Builder(builder: (context) {
          final walk = context.watch<PassengerProvider>().walkDistanceM;
          if (walk != null && walk >= WalkToPickupBanner.kStayPutMetres) {
            return const SizedBox.shrink();
          }
          return Text(
            l.driverNotified,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          );
        }),
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
      ),
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

/// Pickup-point flag with an optional gentle pulse halo. Pulses only when
/// `active` is true (passenger within ~50 m). Visual reward for arriving.
class _PulsingPickupFlag extends StatefulWidget {
  final bool active;
  const _PulsingPickupFlag({required this.active});

  @override
  State<_PulsingPickupFlag> createState() => _PulsingPickupFlagState();
}

class _PulsingPickupFlagState extends State<_PulsingPickupFlag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingPickupFlag old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flag = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
    );
    if (!widget.active) {
      return Center(child: flag);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: (1 - t) * 0.55),
                  width: 2,
                ),
              ),
              transform: Matrix4.identity()
                ..scaleByDouble(
                    0.55 + t * 0.45, 0.55 + t * 0.45, 1.0, 1.0),
              transformAlignment: Alignment.center,
            );
          },
        ),
        flag,
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
  final VoidCallback onReportBug;
  final VoidCallback onShowTutorial;

  const _AccountSheet({
    required this.role,
    required this.isGuest,
    required this.scrollController,
    required this.onSwitchRole,
    required this.onShowLanguage,
    required this.onShowMapStyle,
    required this.onShowAccountSecurity,
    required this.onSignOut,
    required this.onReportBug,
    required this.onShowTutorial,
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
            : friendlyError(
                context,
                ApiException(
                  (jsonDecode(resp.body) as Map)['error'] as String? ?? '',
                  statusCode: resp.statusCode,
                ))),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok && mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).networkError),
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
                          AppLocalizations.of(context).savedCO2(
                              (_co2Saved ?? 18.7).toStringAsFixed(1)),
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
                icon: Icons.forum_rounded,
                label: l.messagesTitle,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConversationsScreen()),
                  );
                },
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
              icon: Icons.help_outline_rounded,
              label: l.showTutorialAgain,
              onTap: widget.onShowTutorial,
            ),
            if (FeatureFlags.aiControls) ...[
              AIMatchingToggleTile(
                label: l.aiMatchingLabel,
                subtitle: l.aiMatchingSubtitle,
              ),
              const TestAITile(),
            ],
            if (FeatureFlags.promotions)
              _SheetTile(
                icon: Icons.local_offer_rounded,
                label: l.promotionsAndRewards,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PromotionsScreen()));
                },
              ),
            if (FeatureFlags.plannedTrips && !widget.isGuest)
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
            if (!widget.isGuest)
              _SheetTile(
                icon: Icons.bug_report_rounded,
                label: l.reportABug,
                onTap: widget.onReportBug,
              ),
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
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
            label: AppLocalizations.of(context).mapStyleStandard,
            icon: Icons.map_rounded,
            style: MapStyle.osm,
            selected: provider.style == MapStyle.osm,
          ),
          const SizedBox(height: 10),
          _MapOption(
            label: AppLocalizations.of(context).mapStyleSatellite,
            icon: Icons.satellite_alt_rounded,
            style: MapStyle.satellite,
            selected: provider.style == MapStyle.satellite,
          ),
          const SizedBox(height: 10),
          _MapOption(
            label: AppLocalizations.of(context).mapStyleDark,
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
  // No carPlate here on purpose. /passenger/nearby-drivers no longer returns
  // one: browsing drivers on the map is pre-match, and name + plate identifies
  // a specific person's car to anyone who can call the endpoint. The plate
  // arrives on the driver_response WS payload once a ride is accepted, which is
  // when it's actually needed to spot the arriving vehicle.
  final String routeWkt;
  // Server-side same-way hint (Round 2 §7): true when the corridor-push
  // filters (forward projection + walk cap + carry gate) would consider this
  // driver for the passenger's declared destination. False on old servers.
  final bool likelyMatch;
  // Off-route walk to this driver's route (m); -1 when unknown.
  final double walkM;
  // On-route distance carried toward the passenger's destination (m); 0 when
  // no destination is declared. Returned by the server all along, previously
  // discarded here.
  final double carryM;
  // Driver reputation. Count is 0 for an unrated driver — show "new", never
  // a 0.0 star average.
  final double avgRating;
  final int ratingCount;

  bool get hasRating => ratingCount > 0;

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
    required this.routeWkt,
    required this.likelyMatch,
    required this.walkM,
    required this.carryM,
    required this.avgRating,
    required this.ratingCount,
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
        routeWkt: j['route_wkt'] as String? ?? '',
        likelyMatch: j['likely_match'] as bool? ?? false,
        walkM: (j['walk_m'] as num?)?.toDouble() ?? -1,
        carryM: (j['carry_m'] as num?)?.toDouble() ?? 0,
        avgRating: (j['driver_avg_rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (j['driver_rating_count'] as num?)?.toInt() ?? 0,
      );

  // Empty when no car info — display sites substitute the localized
  // "No car info" copy (l.noCarInfo); a model class has no BuildContext.
  String get carSummary {
    final parts = [carColor, carMake, carModel].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }
}

/// Live list of the drivers currently heading the passenger's way.
///
/// Replaces a dead end: the match banner said "N drivers heading your way" and
/// tapping it only raised the sheet onto nothing. The data was already on the
/// client — `_nearbyDrivers` refreshes on the same 10 s poll that drives the map
/// markers — it simply had no list to render into.
///
/// Selection is bidirectional with the map: tapping a row highlights that
/// driver's pin, and tapping a pin scrolls this list to the matching row. Both
/// directions write the same `_selectedDriver` state.
class _CandidateDriversList extends StatelessWidget {
  final List<_NearbyDriverInfo> drivers;
  final _NearbyDriverInfo? selected;
  final LatLng? passengerPos;

  /// Per-row keys so a marker tap can `Scrollable.ensureVisible` the row.
  final Map<String, GlobalKey> rowKeys;
  final void Function(_NearbyDriverInfo) onSelect;
  final void Function(_NearbyDriverInfo) onOpenDetails;

  const _CandidateDriversList({
    required this.drivers,
    required this.rowKeys,
    required this.onSelect,
    required this.onOpenDetails,
    this.selected,
    this.passengerPos,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Same-way drivers first — that flag is the server's own corridor-push
    // verdict, so it is a better ordering than raw proximity. Ties break on
    // the shorter walk.
    final sorted = [...drivers]..sort((a, b) {
        if (a.likelyMatch != b.likelyMatch) return a.likelyMatch ? -1 : 1;
        final aw = a.walkM < 0 ? double.infinity : a.walkM;
        final bw = b.walkM < 0 ? double.infinity : b.walkM;
        return aw.compareTo(bw);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.candidateDriversTitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.candidateDriversEmpty,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          )
        else
          ...sorted.map((d) => Padding(
                key: rowKeys.putIfAbsent(d.driverId, () => GlobalKey()),
                padding: const EdgeInsets.only(bottom: 8),
                child: _CandidateDriverRow(
                  driver: d,
                  isSelected: selected?.driverId == d.driverId,
                  passengerPos: passengerPos,
                  onTap: () => onSelect(d),
                  onDetails: () => onOpenDetails(d),
                ),
              )),
      ],
    );
  }
}

class _CandidateDriverRow extends StatelessWidget {
  final _NearbyDriverInfo driver;
  final bool isSelected;
  final LatLng? passengerPos;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const _CandidateDriverRow({
    required this.driver,
    required this.isSelected,
    required this.onTap,
    required this.onDetails,
    this.passengerPos,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Estimated from the driver's origin: their live position is not exposed
    // pre-match, and would identify where a specific person is right now.
    final eta = passengerPos == null
        ? null
        : estimateDriverEtaMinutes(driver.origin, passengerPos!);
    return Material(
      color: isSelected
          ? AppColors.teal.withValues(alpha: 0.14)
          : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.teal : AppColors.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              UserAvatar(name: driver.driverName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driver.driverName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (driver.hasRating) ...[
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFC107), size: 14),
                          Text(
                            driver.avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ] else
                          _Pill(text: l.newDriverBadge,
                              color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.carSummary.isEmpty
                          ? l.noCarInfo
                          : driver.carSummary,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (driver.likelyMatch)
                          _Pill(text: l.sameWayBadge, color: AppColors.success),
                        if (eta != null)
                          Text(l.etaApprox(eta),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        if (driver.walkM >= 0)
                          Text(
                            l.walkShort(
                                WalkToPickupBanner.formatDistance(driver.walkM)),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDetails,
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                tooltip: l.driverDetails,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ── Driver info bottom sheet ──────────────────────────────────────────────────

class _DriverInfoSheet extends StatefulWidget {
  final _NearbyDriverInfo driver;
  // Passenger's chosen destination, if any. When set we estimate the walk from
  // the driver's no-detour drop-off (nearest point on their route) to here.
  final LatLng? destination;
  final VoidCallback onRequest;

  const _DriverInfoSheet({
    required this.driver,
    required this.onRequest,
    this.destination,
  });

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
    final l = AppLocalizations.of(context);
    final driver = widget.driver;
    // Walk left over after a no-detour drop-off: distance from the passenger's
    // destination to the nearest point on the driver's fixed route. Null when
    // no destination is set or the driver's route geometry is missing.
    final dest = widget.destination;
    final routePts = parseLineStringWKT(driver.routeWkt);
    final walkKm = (dest != null && routePts.isNotEmpty)
        ? distanceToRouteKm(dest, routePts)
        : null;
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driver.driverName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (driver.likelyMatch) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.success
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              l.likelyMatchChip,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.seatsCorridorSummary('${driver.seats}',
                          driver.corridorKm.toStringAsFixed(1)),
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
            label: l.destination,
            value: _destAddress ??
                '${driver.destination.latitude.toStringAsFixed(4)}, ${driver.destination.longitude.toStringAsFixed(4)}',
          ),
          if (walkKm != null) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFFFF9800),
              label: l.walkToDestination,
              value: l.walkEstimate(
                minutesAt(walkKm * 1000, walkSpeedKmh),
                (walkKm * 1000).round(),
              ),
              hint: l.walkToDestinationHint,
            ),
          ],
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.directions_car_rounded,
            color: AppColors.primary,
            label: l.carLabel,
            value: driver.carSummary.isEmpty ? l.noCarInfo : driver.carSummary,
          ),
          // Plate intentionally not shown pre-match — the server no longer
          // sends one here. It appears on the accepted-ride card, which is when
          // the passenger needs it to identify the arriving car.
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: widget.onRequest,
              icon: const Icon(Icons.hail_rounded, size: 20),
              label: Text(l.requestThisRide,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Pre-match chat (Round 2 §3): "I saw them on the map — let's
          // confirm before requesting." Server-side gate allows it because
          // this driver is in the caller's nearby candidate list.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peerId: widget.driver.driverId,
                      otherPartyName: widget.driver.driverName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(l.messageDriver,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: BorderSide(
                    color: AppColors.teal.withValues(alpha: 0.6)),
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
  // Optional secondary line under the value (e.g. an explanatory note).
  final String? hint;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.hint,
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
              if (hint != null) ...[
                const SizedBox(height: 3),
                Text(hint!,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.35)),
              ],
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

// _PickupCodeBlock renders the prompt "Ask your driver for the pickup code"
// and a button that opens a 4-digit entry dialog. The passenger never sees
// the code — they have to ask the driver verbally (asymmetric handshake,
// see D3 in the pickup-code plan).
class _PickupCodeBlock extends StatelessWidget {
  final Future<PickupAttempt> Function(String code) onConfirm;
  const _PickupCodeBlock({required this.onConfirm});

  Future<void> _showEntryDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(l.askDriverForCode,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '____',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.length == 4) {
                Navigator.pop(ctx, ctrl.text);
              }
            },
            child: Text(l.submit,
                style: const TextStyle(
                    color: AppColors.teal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (entered == null) return;
    final result = await onConfirm(entered);
    if (result.ok || !context.mounted) return;
    final l2 = AppLocalizations.of(context);
    // Say exactly what happened: how many tries are left, that the code is
    // locked (the driver can issue a new one), or the actual error — it
    // used to be "invalid code" for every failure, lockout included.
    final message = result.locked
        ? l2.pickupLocked
        : result.attemptsLeft != null
            ? l2.wrongCodeAttemptsLeft(result.attemptsLeft!)
            : result.error != null
                ? friendlyError(context, result.error!)
                : l2.invalidCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: result.locked ? 8 : 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.pin_rounded,
                  color: AppColors.teal, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.askDriverForCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showEntryDialog(context),
              icon: const Icon(Icons.keyboard_rounded, size: 18),
              label: Text(l.submit),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill that floats near the top of the map when a driver has been selected
/// but the info sheet is currently dismissed. Tapping it re-opens the info
/// sheet for the same driver — the user can swipe the bottom sheet down to
/// see the map, then come back to the chosen driver without losing context.
class _SelectedDriverChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  // Tapped to drop the selection and bring back the other drivers on the map.
  // Without it the user is stuck in solo-focus mode until they change destination.
  final VoidCallback onClear;

  const _SelectedDriverChip({
    required this.name,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drive_eta_rounded,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onClear,
              customBorder: const CircleBorder(),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

