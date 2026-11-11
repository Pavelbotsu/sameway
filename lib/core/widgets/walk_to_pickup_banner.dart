import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../app_localizations.dart';

/// Compact banner shown on the passenger's accepted card when the pickup
/// point is far enough away that the user needs explicit walking guidance
/// (default threshold: 300 m — anything shorter is a tap-out-the-door
/// situation, the in-app polyline plus the flag marker is enough).
///
/// The "Open in walking directions" link fires a Google Maps walking-mode
/// URL via url_launcher — an external fallback for unfamiliar streets.
class WalkToPickupBanner extends StatelessWidget {
  final double passengerLat;
  final double passengerLng;
  final double pickupLat;
  final double pickupLng;
  final double walkDistanceM;

  const WalkToPickupBanner({
    super.key,
    required this.passengerLat,
    required this.passengerLng,
    required this.pickupLat,
    required this.pickupLng,
    required this.walkDistanceM,
  });

  /// Threshold below which we don't render the banner. 300 m is short enough
  /// that the user almost certainly noticed walking is required from the
  /// flag marker + walking polyline alone.
  static const double minMetersForBanner = 300;

  /// Below this the pickup is effectively where the passenger already is, and
  /// "stay where you are" is the honest instruction.
  ///
  /// These two constants define three mutually exclusive tiers, and the caller
  /// ([_AcceptedCard]) must render exactly one:
  ///
  ///   walk < 100 m   -> "driver notified, stay where you are"
  ///   100 m - 300 m  -> [WalkToPickupCompact] — one line, no external link
  ///   walk > 300 m   -> this banner, with walking directions
  ///
  /// They used to overlap: the "stay where you are" line was unconditional, so
  /// a 400 m walk rendered the banner AND an instruction not to move.
  static const double kStayPutMetres = 100;

  static String formatDistance(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$passengerLat,$passengerLng'
      '&destination=$pickupLat,$pickupLng'
      '&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* SnackBar would be noise — silently skip */}
  }

  @override
  Widget build(BuildContext context) {
    // Defensive: the caller decides the tier, but never render the heavy banner
    // for a walk the compact line is meant to cover.
    if (walkDistanceM < minMetersForBanner) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    // Average walking speed 1.4 m/s ≈ 5 km/h.
    final minutes = (walkDistanceM / 1.4 / 60).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk_rounded,
              color: AppColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.walkToPickup(formatDistance(walkDistanceM)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  l.walkApproxMinutes(minutes),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _openMaps(context),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.openWalkingDirections,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Middle tier: a short walk the user still has to be told about, but not one
/// that warrants a full banner and an external maps hand-off. The pickup flag
/// and walking polyline on the map carry the rest of the message.
///
/// Exists because the two previous states were "silent" and "full banner", and
/// everything between 100 m and 300 m fell into the silent one — while the
/// card underneath said "stay at your location".
class WalkToPickupCompact extends StatelessWidget {
  final double walkDistanceM;

  const WalkToPickupCompact({super.key, required this.walkDistanceM});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_walk_rounded,
              color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l.walkToPickupShort(
                  WalkToPickupBanner.formatDistance(walkDistanceM)),
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
