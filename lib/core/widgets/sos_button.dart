import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../app_localizations.dart';
import '../haptics.dart';

/// Compact red "SOS" pill the rider/driver can tap during an active ride.
/// Tap opens [SosSheet] for confirmation — never auto-dials, so a butt
/// press in a pocket can't accidentally call 911.
class SosButton extends StatelessWidget {
  /// Lat/lng of the user firing the SOS — embedded in the share message so
  /// the contact can locate them.
  final double? lat;
  final double? lng;
  // Optional context attached to the share message — empty when not
  // applicable (e.g. driver firing SOS doesn't have their own plate).
  final String? driverName;
  final String? plate;

  const SosButton({
    super.key,
    this.lat,
    this.lng,
    this.driverName,
    this.plate,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: AppColors.error,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => SosSheet.show(
          context,
          lat: lat,
          lng: lng,
          driverName: driverName,
          plate: plate,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                l.sos,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation sheet with two CTAs:
///   - **Call emergency services** — `tel:` URI to the local emergency
///     number (from localized strings; 911 in en, 112 elsewhere by default).
///     Just opens the dialer — we do NOT auto-dial, the user still has to
///     press the green button.
///   - **Share trip with contact** — opens the system share sheet prefilled
///     with a Google Maps location URL, driver name, plate.
class SosSheet extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String? driverName;
  final String? plate;

  const SosSheet({
    super.key,
    this.lat,
    this.lng,
    this.driverName,
    this.plate,
  });

  static Future<void> show(
    BuildContext context, {
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
      builder: (_) => SosSheet(
        lat: lat,
        lng: lng,
        driverName: driverName,
        plate: plate,
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    final number = AppLocalizations.of(context).sosEmergencyNumber;
    final uri = Uri.parse('tel:$number');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* dialer unavailable — silently no-op */}
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _share(BuildContext context) async {
    final mapsUrl = (lat != null && lng != null)
        ? 'https://maps.google.com/?q=$lat,$lng'
        : 'unknown location';
    final body = AppLocalizations.of(context)
        .sosShareBody(mapsUrl, driverName, plate);
    try {
      // ignore: deprecated_member_use
      await Share.share(body);
    } catch (_) {/* share sheet unavailable — silently no-op */}
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.55),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_rounded,
                color: AppColors.error, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            l.sosTitle,
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
            l.sosBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _call(context),
              icon: const Icon(Icons.local_phone_rounded, size: 20),
              label: Text(
                l.sosCall,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(
                l.sosShare,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l.cancel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
