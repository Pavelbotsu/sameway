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

  String _formatDistance(double m) {
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
                  l.walkToPickup(_formatDistance(walkDistanceM)),
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
