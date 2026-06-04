import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/geo.dart';
import '../../../core/widgets/m3_expressive/m3_expressive.dart';
import '../../chat/chat_screen.dart';
import '../driver_provider.dart';
import '../driver_repository.dart';

const _kSwitchDuration = Duration(milliseconds: 280);
const _kSwitchCurve = Curves.easeOutCubic;

/// Bottom panel of the driver home screen. Renders one of three state-cases
/// (idle / guest / active route) and tweens between them via [AnimatedSwitcher]
/// using the same 280 ms easeOutCubic token the offer sheet animator uses.
class DriverBottomPanel extends StatelessWidget {
  final DriverProvider driver;
  final bool isGuest;
  final ScrollController scrollController;
  final VoidCallback onSetRoute;
  final VoidCallback onPlanTrip;
  final VoidCallback onFindTrips;
  final VoidCallback onDeleteRoute;
  final LatLng? myPos;

  const DriverBottomPanel({
    super.key,
    required this.driver,
    required this.isGuest,
    required this.scrollController,
    required this.onSetRoute,
    required this.onPlanTrip,
    required this.onFindTrips,
    required this.onDeleteRoute,
    this.myPos,
  });

  String _stateKey() {
    if (isGuest) return 'guest';
    if (driver.activeRoute != null) return 'active';
    return 'idle';
  }

  Widget _stateBody(BuildContext context) {
    if (isGuest) {
      return _GuestPanel(key: const ValueKey('guest'), onSetRoute: onSetRoute);
    }
    if (driver.activeRoute != null) {
      return _ActivePanel(
        key: const ValueKey('active'),
        driver: driver,
        myPos: myPos,
        onDeleteRoute: onDeleteRoute,
      );
    }
    return _IdlePanel(
      key: const ValueKey('idle'),
      driver: driver,
      onSetRoute: onSetRoute,
      onPlanTrip: onPlanTrip,
      onFindTrips: onFindTrips,
    );
  }

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
                MediaQuery.of(context).padding.bottom + 36,
              ),
              child: AnimatedSwitcher(
                duration: _kSwitchDuration,
                switchInCurve: _kSwitchCurve,
                switchOutCurve: _kSwitchCurve,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    axisAlignment: -1,
                    sizeFactor: anim,
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_stateKey()),
                  child: _stateBody(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── State-case panels ──────────────────────────────────────────────────────

class _IdlePanel extends StatelessWidget {
  final DriverProvider driver;
  final VoidCallback onSetRoute;
  final VoidCallback onPlanTrip;
  final VoidCallback onFindTrips;

  const _IdlePanel({
    super.key,
    required this.driver,
    required this.onSetRoute,
    required this.onPlanTrip,
    required this.onFindTrips,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.readyToShare,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.setRouteDesc,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        // Split CTA — primary "Set Route" + dropdown with Plan / Find Planned.
        Center(
          child: SplitButton(
            label: l.setRoute,
            icon: Icons.add_road_rounded,
            height: 54,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: driver.isLoading ? null : onSetRoute,
            menuItems: [
              SplitMenuItem(
                label: l.planATrip,
                icon: Icons.event_available_rounded,
                onPressed: onPlanTrip,
              ),
              SplitMenuItem(
                label: l.findPlannedTrips,
                icon: Icons.search_rounded,
                onPressed: onFindTrips,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: driver.isLoading
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: Column(
                    children: [
                      const WaveProgressIndicator(),
                      const SizedBox(height: 6),
                      Text(
                        l.settingRoute,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _GuestPanel extends StatelessWidget {
  final VoidCallback onSetRoute;
  const _GuestPanel({super.key, required this.onSetRoute});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.explore_rounded,
              color: AppColors.primary, size: 26),
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
          l.signInShareDesc,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onSetRoute,
            child: Text(l.signInToShareRoute),
          ),
        ),
      ],
    );
  }
}

class _ActivePanel extends StatelessWidget {
  final DriverProvider driver;
  final VoidCallback onDeleteRoute;
  final LatLng? myPos;

  const _ActivePanel({
    super.key,
    required this.driver,
    required this.onDeleteRoute,
    this.myPos,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RouteActiveCard(route: driver.activeRoute!, onDelete: onDeleteRoute),
        const SizedBox(height: 16),
        if (driver.requests.isNotEmpty)
          _RequestsList(
            requests: driver.requests,
            acceptedRequestId: driver.acceptedRequestId,
            myPos: myPos,
            onCancelRide: (id) =>
                context.read<DriverProvider>().cancelRide(id),
            onCompleteRide: (id, passengerId) async {
              // Fire-and-forget: backend will emit `ride_done` over WS, which
              // sets pendingRatingRequestId on the provider. The home screen's
              // _ratingListener then opens RatingSheet — single source of truth
              // for both the local complete and any redundant WS event.
              await context
                  .read<DriverProvider>()
                  .completeRide(driver.activeRoute?.distanceKm ?? 0);
            },
          )
        else
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_outline_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  l.noRideRequests,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.noRideRequestsDesc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Subcomponents (kept private to this file) ──────────────────────────────

class _RouteActiveCard extends StatelessWidget {
  final RouteResult route;
  final VoidCallback onDelete;
  const _RouteActiveCard({required this.route, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                Text(
                  l.routeActive,
                  style: const TextStyle(
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
  final String? acceptedRequestId;
  final LatLng? myPos;
  final void Function(String requestId) onCancelRide;
  final void Function(String requestId, String passengerId) onCompleteRide;
  const _RequestsList({
    required this.requests,
    required this.onCancelRide,
    required this.onCompleteRide,
    this.acceptedRequestId,
    this.myPos,
  });

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
        ...requests.map((r) => _RequestTile(
              request: r,
              acceptedRequestId: acceptedRequestId,
              info: context.read<DriverProvider>().infoFor(r.id),
              passengerLoc:
                  context.watch<DriverProvider>().passengerLocations[r.id],
              myPos: myPos,
              onCancel: r.status == 'accepted'
                  ? () => onCancelRide(r.id)
                  : null,
              onComplete: r.status == 'accepted'
                  ? () => onCompleteRide(r.id, r.passengerID)
                  : null,
              onRespond: r.status == 'pending'
                  ? (accepted) => context
                      .read<DriverProvider>()
                      .respondToRequest(r.id, accepted: accepted)
                  : null,
            )),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final RideRequest request;
  final String? acceptedRequestId;
  final PassengerMatchInfo? info;
  final PeerLatLng? passengerLoc;
  final LatLng? myPos;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final void Function(bool accepted)? onRespond;
  const _RequestTile({
    required this.request,
    this.acceptedRequestId,
    this.info,
    this.passengerLoc,
    this.myPos,
    this.onCancel,
    this.onComplete,
    this.onRespond,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(context),
          if (request.status == 'pending' && onRespond != null) ...[
            const SizedBox(height: 10),
            _buildAcceptDeclineRow(context),
          ],
          if (request.status == 'accepted') ...[
            const SizedBox(height: 12),
            _AcceptedRideMap(
              myPos: myPos,
              peerPos: passengerLoc == null
                  ? null
                  : LatLng(passengerLoc!.lat, passengerLoc!.lng),
            ),
            const SizedBox(height: 12),
            _buildAcceptedActions(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedActions(BuildContext context) {
    final destKm = context
        .watch<DriverProvider>()
        .distanceToDestinationKm(myPos);
    final farFromDest = destKm != null && destKm > 0.15;
    final label = farFromDest
        ? 'Complete ride (${destKm.toStringAsFixed(1)} km away)'
        : 'Complete ride';
    final dialogL = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onComplete == null
              ? null
              : () async {
                  if (farFromDest) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text(
                          'End ride here?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        content: Text(
                          "You're ${destKm.toStringAsFixed(1)} km from your "
                          'destination. End the ride anyway?',
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              'Keep driving',
                              style: TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'End ride',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (proceed != true) return;
                  }
                  onComplete?.call();
                },
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: onCancel == null
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Text(dialogL.cancelRideQ,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        content: Text(
                          dialogL.cancelRideMessageDriver,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(dialogL.keepRide,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(dialogL.cancel,
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) onCancel?.call();
                  },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cancel ride',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptDeclineRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onRespond?.call(false),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Decline'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => onRespond?.call(true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Accept'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (info?.name?.trim().isNotEmpty == true)
                      ? info!.name!
                      : 'Passenger ${request.passengerID.substring(0, 8)}…',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (info?.hasRating == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC857), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${info!.avgRating!.toStringAsFixed(1)} (${info!.ratingCount})',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          if (request.status == 'accepted') ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    rideRequestId: acceptedRequestId ?? request.id,
                    otherPartyName: 'Passenger',
                  ),
                ),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: AppColors.primary, size: 18),
              ),
            ),
          ],
        ],
    );
  }
}

class _AcceptedRideMap extends StatefulWidget {
  final LatLng? myPos;
  final LatLng? peerPos;
  const _AcceptedRideMap({this.myPos, this.peerPos});

  @override
  State<_AcceptedRideMap> createState() => _AcceptedRideMapState();
}

class _AcceptedRideMapState extends State<_AcceptedRideMap> {
  final MapController _ctrl = MapController();

  @override
  void didUpdateWidget(covariant _AcceptedRideMap old) {
    super.didUpdateWidget(old);
    if (widget.myPos != old.myPos || widget.peerPos != old.peerPos) {
      _fit();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    final a = widget.myPos;
    final b = widget.peerPos;
    if (a == null || b == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _ctrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([a, b]),
            padding: const EdgeInsets.all(36),
          ),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.myPos;
    final b = widget.peerPos;
    if (a == null || b == null) {
      // Show a placeholder shimmer-style box until both positions arrive.
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            a == null
                ? 'Waiting for your location…'
                : 'Waiting for passenger location…',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    final distance = geoDistanceKm(a, b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _ctrl,
              options: MapOptions(
                initialCenter: LatLng(
                  (a.latitude + b.latitude) / 2,
                  (a.longitude + b.longitude) / 2,
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
                PolylineLayer(polylines: [
                  Polyline(
                    points: [a, b],
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: a,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.directions_car_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                  Marker(
                    point: b,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${distance.toStringAsFixed(1)} km between you',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

