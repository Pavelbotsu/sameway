import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Three flavored SnackBars on a shared brand template: error, success, info.
///
/// They replace ad-hoc `ScaffoldMessenger.showSnackBar(SnackBar(...))` calls
/// throughout the app so styling is consistent and a retry CTA is easy to
/// thread through without bespoke widgets at every call site.
///
/// Floating, 12-dp radius, brand-colored top border. `onRetry` adds a
/// trailing TextButton that closes the bar and fires the callback.
class BrandedSnack {
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    _show(context, message,
        accent: AppColors.error,
        icon: Icons.error_outline_rounded,
        onRetry: onRetry,
        retryLabel: retryLabel);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message,
        accent: AppColors.success,
        icon: Icons.check_circle_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message,
        accent: AppColors.teal,
        icon: Icons.info_outline_rounded);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color accent,
    required IconData icon,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      elevation: 8,
      duration: Duration(seconds: onRetry == null ? 4 : 6),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.55), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      content: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: Text(retryLabel),
            ),
        ],
      ),
    ));
  }
}
