import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/geo.dart';
import '../../../core/widgets/animated_map_marker.dart';
import '../../../core/widgets/m3_expressive/m3_expressive.dart';
import '../../../core/widgets/sheet_grab_handle.dart';
import '../../../core/widgets/sos_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/wkt.dart';
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
  final DraggableScrollableController sheetCtrl;
  final VoidCallback onSetRoute;
  final VoidCallback onPlanTrip;
  final VoidCallback onFindTrips;
  final VoidCallback onDeleteRoute;
  final Future<void> Function() onRefresh;
  final LatLng? myPos;

  const DriverBottomPanel({
    super.key,
    required this.driver,
    required this.isGuest,
    required this.scrollController,
    required this.sheetCtrl,
    required this.onSetRoute,
    required this.onPlanTrip,
    required this.onFindTrips,
    required this.onDeleteRoute,
    required this.onRefresh,
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
          SheetGrabHandle(
            controller: sheetCtrl,
            minChildSize: 0.07,
            maxChildSize: 0.85,
            snapSizes: const [0.28, 0.55],
          ),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            // Pull-to-refresh re-runs the driver's GET /driver/requests so
            // a stuck request list can be force-refreshed without waiting
            // for the polling timer.
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
    final hasActivePassenger = driver.requests.any(
        (r) => r.status == 'accepted' || r.status == 'in_progress');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasActivePassenger) ...[
          Align(
            alignment: Alignment.centerRight,
            child: SosButton(
              lat: myPos?.latitude,
              lng: myPos?.longitude,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _RouteActiveCard(
          route: driver.activeRoute!,
          onDelete: () async {
            // If there are any active rides (accepted or in_progress),
            // confirm and end the route via the bulk done flow — that emits
            // ride_done WS for every remaining passenger so they each get
            // their rating prompt. Otherwise just delete the route silently.
            final hasActive = driver.requests.any(
                (r) => r.status == 'accepted' || r.status == 'in_progress');
            if (!hasActive) {
              onDeleteRoute();
              return;
            }
            final l = AppLocalizations.of(context);
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text(
                  'End route?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                content: const Text(
                  'Every passenger currently on board will be dropped off '
                  "and you'll stop receiving new matches.",
                  style: TextStyle(
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
                    child: const Text('End route',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
            if (proceed != true) return;
            await driver.completeRide(driver.activeRoute?.distanceKm ?? 0);
          },
        ),
        const SizedBox(height: 16),
        if (driver.requests.isNotEmpty)
          _RequestsList(
            requests: driver.requests,
            acceptedRequestId: driver.acceptedRequestId,
            myPos: myPos,
            onCancelRide: (id) =>
                context.read<DriverProvider>().cancelRide(id),
            onCompleteRide: (id, passengerId) async {
              // Per-passenger drop-off. Backend emits ride_done over WS, which
              // surgically removes just this ride from local state and sets
              // pendingRatingRequestId so the home screen's _ratingListener
              // opens RatingSheet. Other passengers (in_progress) on this
              // driver remain untouched.
              await context
                  .read<DriverProvider>()
                  .dropoff(id, distanceKm: driver.activeRoute?.distanceKm ?? 0);
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
            tooltip: AppLocalizations.of(context).cancel,
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
      'in_progress' => AppColors.teal,
      'declined' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  IconData get _statusIcon {
    return switch (request.status) {
      'accepted' => Icons.check_circle_rounded,
      'in_progress' => Icons.directions_car_rounded,
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
          if (request.status == 'accepted' ||
              request.status == 'in_progress') ...[
            if (request.status == 'accepted' &&
                request.pickupCode != null) ...[
              const SizedBox(height: 10),
              _DriverPickupCodeBlock(code: request.pickupCode!),
            ],
            const SizedBox(height: 12),
            _AcceptedRideMap(
              myPos: myPos,
              peerPos: passengerLoc == null
                  ? null
                  : LatLng(passengerLoc!.lat, passengerLoc!.lng),
              pickupPoint: LatLng(request.pickupLat, request.pickupLng),
              pickupRoute: context.watch<DriverProvider>().pickupRoute,
            ),
            const SizedBox(height: 12),
            _buildAcceptedActions(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedActions(BuildContext context) {
    final dialogL = AppLocalizations.of(context);
    final isInRide = request.status == 'in_progress';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The "Complete ride" button only appears after the pickup handshake
        // has completed (status == in_progress). For accepted-but-not-met
        // rides, the code-entry block above the map is the next action.
        if (isInRide)
          FilledButton.icon(
            onPressed: onComplete == null ? null : () => onComplete!.call(),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              'Drop off ${request.passengerName?.trim().isNotEmpty == true ? request.passengerName : "passenger"}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        if (isInRide) const SizedBox(height: 6),
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
          UserAvatar(
            photoUrl: request.passengerPhotoUrl,
            name: request.passengerName,
            size: 36,
            ring: false,
          ),
          const SizedBox(width: 10),
          Icon(_statusIcon, color: _statusColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(builder: (_) {
                  // Prefer the durable backend join (request.passengerName)
                  // over the volatile WS-hydrated info; either beats the UUID
                  // hash placeholder.
                  final name = (request.passengerName?.trim().isNotEmpty == true)
                      ? request.passengerName!
                      : (info?.name?.trim().isNotEmpty == true)
                          ? info!.name!
                          : 'Passenger';
                  return Text(
                    name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  );
                }),
                Builder(builder: (_) {
                  final avg = request.passengerAvgRating ?? info?.avgRating;
                  final count = request.passengerRatingCount ?? info?.ratingCount;
                  if (avg == null || count == null || count == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC857), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${avg.toStringAsFixed(1)} ($count)',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }),
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
  final LatLng? pickupPoint;
  final PickupRoute? pickupRoute;
  const _AcceptedRideMap({
    this.myPos,
    this.peerPos,
    this.pickupPoint,
    this.pickupRoute,
  });

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
        final points = <LatLng>[a, b];
        if (widget.pickupPoint != null) points.add(widget.pickupPoint!);
        _ctrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(36),
          ),
        );
      } catch (_) {}
    });
  }

  /// Builds the polyline list. With a `pickupRoute` we render three legs:
  /// driver → pickup (solid teal), pickup → continuation (lighter teal),
  /// passenger → pickup (dashed teal). On OSRM failure (route empty) we
  /// fall back to a single straight line so users still see something.
  List<Polyline> _buildPolylines(LatLng driverPos, LatLng peerPos) {
    final route = widget.pickupRoute;
    if (route == null) {
      return [
        Polyline(points: [driverPos, peerPos], strokeWidth: 2, color: AppColors.teal),
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
          points: [driverPos, peerPos], strokeWidth: 2, color: AppColors.teal));
    }
    return out;
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
                PolylineLayer(polylines: _buildPolylines(a, b)),
                AnimatedMarkerPosition(
                  target: b,
                  builder: (ctx, passengerP) => MarkerLayer(markers: [
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
                      point: passengerP,
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
                    if (widget.pickupPoint != null)
                      Marker(
                        point: widget.pickupPoint!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                  ]),
                ),
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

// _DriverPickupCodeBlock displays the 4-digit pickup code prominently. The
// driver tells the code to the passenger verbally when they meet at the
// pickup point; the passenger types it in on their side. The driver never
// has an input field — that's the whole point of the asymmetric handshake
// (proves the parties physically met). See D3 in the pickup-handshake plan.
class _DriverPickupCodeBlock extends StatelessWidget {
  final String code;
  const _DriverPickupCodeBlock({required this.code});

  Future<void> _copy(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.codeCopied),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tellCodeToPassenger,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l.copyCode,
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded,
                    color: AppColors.teal, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
