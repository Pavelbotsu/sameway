import 'package:flutter/material.dart';

import '../analytics.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../haptics.dart';
import 'sos_button.dart';

/// Shown once per ride when the two parties' fresh GPS fixes have been far
/// apart for ~30s while the ride is in progress (see `core/ride_check_in.dart`
/// for the decision logic and, more importantly, for why staleness must never
/// count as separation).
///
/// Modelled on [SosSheet] deliberately — same container, grab handle, badge and
/// two-CTA shape — because SOS is where "no" leads, and the two should read as
/// one flow rather than two unrelated dialogs.
///
/// Not dismissible by tapping outside: a prompt that can be swiped away without
/// an answer teaches people to swipe it away. Both answers are one tap.
class RideCheckInSheet extends StatelessWidget {
  /// Localized label for the counterparty ("driver" / "passenger") — the app is
  /// role-symmetric here, only the wording differs.
  final String otherPartyLabel;

  /// Position of the user seeing this sheet, forwarded to [SosSheet] so a share
  /// carries a real location.
  final double? lat;
  final double? lng;

  /// Ride context for the SOS share message. Null on the driver's side — they
  /// are the driver, so their own name and plate are not useful to send.
  final String? driverName;
  final String? plate;

  /// Records the flag server-side. Awaited before SOS opens but must never
  /// throw — the provider implementations swallow errors for exactly this
  /// reason.
  final Future<void> Function(String reason) onNeedHelp;

  const RideCheckInSheet({
    super.key,
    required this.otherPartyLabel,
    required this.onNeedHelp,
    this.lat,
    this.lng,
    this.driverName,
    this.plate,
  });

  static Future<void> show(
    BuildContext context, {
    required String otherPartyLabel,
    required Future<void> Function(String reason) onNeedHelp,
    double? lat,
    double? lng,
    String? driverName,
    String? plate,
  }) {
    Haptics.heavy();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RideCheckInSheet(
        otherPartyLabel: otherPartyLabel,
        onNeedHelp: onNeedHelp,
        lat: lat,
        lng: lng,
        driverName: driverName,
        plate: plate,
      ),
    );
  }

  Future<void> _allGood(BuildContext context) async {
    Analytics.logEvent('ride_check_in_answered', {'answer': 'ok'});
    Navigator.pop(context);
  }

  Future<void> _needHelp(BuildContext context) async {
    Analytics.logEvent('ride_check_in_answered', {'answer': 'help'});
    await onNeedHelp('check_in_not_ok');
    if (!context.mounted) return;
    // Close this sheet first so SOS isn't stacked on top of it — otherwise
    // dismissing SOS drops the user back onto the check-in they just answered.
    Navigator.pop(context);
    await SosSheet.show(
      context,
      lat: lat,
      lng: lng,
      driverName: driverName,
      plate: plate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      // Back button must not count as "I'm fine". The only ways out are the two
      // buttons below.
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          22,
          24,
          MediaQuery.of(context).viewPadding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.55),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.support_rounded,
                    color: AppColors.teal, size: 30),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l.checkInTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.checkInBody(otherPartyLabel),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            // "I'm fine" is the primary, non-alarming action: this prompt fires
            // most often when a ride simply ended without anyone tapping drop
            // off, and the common case should be the easy one.
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => _allGood(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.checkInAllGood,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _needHelp(context),
                icon: const Icon(Icons.shield_rounded, size: 20),
                label: Text(
                  l.checkInNeedHelp,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
