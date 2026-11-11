import 'package:flutter/material.dart';

import '../../features/passenger/passenger_provider.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../widgets/m3_expressive/m3_expressive.dart';

/// Prominent, tappable match-state banner pinned to the passenger map
/// (Round 2 §6). One card, one state at a time:
///
///   searching → candidatesAvailable → offerReceived → requested → matched
///   → inProgress
///
/// Replaces the old always-identical "searching" sub-line: every transition
/// is visible without opening the bottom sheet, and tapping raises the sheet
/// to the matching detail (offer card / request list / accepted card).
class MatchStateBanner extends StatelessWidget {
  final MatchUiState state;
  final int likelyCount;
  final String? driverName; // matched driver, when known
  // Partial-relay leg 2: leg 1 is done, the search continues from the
  // dropoff — the searching copy says so explicitly.
  final bool relayLeg2;
  final VoidCallback onTap;

  const MatchStateBanner({
    super.key,
    required this.state,
    required this.onTap,
    this.likelyCount = 0,
    this.driverName,
    this.relayLeg2 = false,
  });

  @override
  Widget build(BuildContext context) {
    if (state == MatchUiState.idle) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    final (icon, accent, title, subtitle) = switch (state) {
      MatchUiState.searching => (
          Icons.travel_explore_rounded,
          AppColors.teal,
          relayLeg2 ? l.relayLeg2Searching : l.matchStateSearching,
          l.matchStateSearchingDesc,
        ),
      MatchUiState.candidatesAvailable => (
          Icons.directions_car_rounded,
          AppColors.success,
          l.driversHeadingYourWay(likelyCount),
          l.matchStateCandidatesDesc,
        ),
      MatchUiState.offerReceived => (
          Icons.local_offer_rounded,
          AppColors.primary,
          l.matchStateOffer,
          l.matchStateOfferDesc,
        ),
      MatchUiState.requested => (
          Icons.outbox_rounded,
          AppColors.teal,
          l.matchStateRequested,
          l.matchStateRequestedDesc,
        ),
      MatchUiState.matched => (
          Icons.check_circle_rounded,
          AppColors.success,
          driverName == null
              ? l.matchStateMatched
              : l.matchStateMatchedWith(driverName!),
          l.matchStateMatchedDesc,
        ),
      MatchUiState.inProgress => (
          Icons.route_rounded,
          AppColors.success,
          l.matchStateInProgress,
          l.matchStateInProgressDesc,
        ),
      MatchUiState.idle => (Icons.circle, AppColors.teal, '', ''),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_less_rounded,
                    color: accent.withValues(alpha: 0.8), size: 20),
              ],
            ),
            if (state == MatchUiState.searching) ...[
              const SizedBox(height: 10),
              const WaveProgressIndicator(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
