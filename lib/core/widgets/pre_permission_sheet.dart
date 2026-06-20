import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_localizations.dart';

/// Bottom sheet that explains *why* we're about to ask for a permission, so
/// the OS prompt doesn't appear cold. Returns `true` from
/// [PrePermissionSheet.ask] when the user taps "Continue" (caller should
/// then trigger the actual OS prompt), `false` on "Not now" or dismissal.
///
/// Two pre-baked flavors via static factories — keeps call sites short.
class PrePermissionSheet extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  const PrePermissionSheet({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  /// Shows the sheet and returns whether the user accepted. Safe to call
  /// even on cold start — uses `showModalBottomSheet` so it doesn't require
  /// a Scaffold above it.
  static Future<bool> ask(BuildContext context, PrePermissionSheet sheet) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
    return ok == true;
  }

  /// Location-permission rationale. Use before `Geolocator.requestPermission`.
  static Future<bool> askLocation(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ask(
      context,
      PrePermissionSheet(
        icon: Icons.my_location_rounded,
        accent: AppColors.teal,
        title: l.permLocationTitle,
        body: l.permLocationBody,
      ),
    );
  }

  /// Notification-permission rationale. Use before
  /// `FirebaseMessaging.requestPermission` / `Permission.notification`.
  static Future<bool> askNotifications(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ask(
      context,
      PrePermissionSheet(
        icon: Icons.notifications_active_rounded,
        accent: AppColors.primary,
        title: l.permNotifTitle,
        body: l.permNotifBody,
      ),
    );
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
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
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
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l.permContinue,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l.permNotNow,
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
