import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../../l10n/l10n.dart';

class RatingWaitBanner extends StatelessWidget {
  /// Who we wait for: the driver (true) or the passenger (false).
  final bool otherIsDriver;
  final VoidCallback? onDismiss;

  const RatingWaitBanner({
    super.key,
    required this.otherIsDriver,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.common_waitingForRating(
                    otherIsDriver ? 'driver' : 'passenger'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                tooltip: AppLocalizations.of(context).dismiss,
              ),
          ],
        ),
      ),
    );
  }
}
