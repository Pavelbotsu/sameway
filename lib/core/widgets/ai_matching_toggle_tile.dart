import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import '../matching_preference_provider.dart';

/// Drop-in account-sheet row that flips the per-user AI-matching preference.
///
/// Designed to live next to the other account-sheet `_SheetTile` rows. We do
/// not import `_SheetTile` (it is file-private to each home screen) — this
/// widget re-renders the same row shape so the visual matches.
///
/// Removing the AI subsystem: delete this file and the call sites.
class AIMatchingToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  const AIMatchingToggleTile({
    super.key,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final pref = context.watch<MatchingPreferenceProvider>();
    return InkWell(
      onTap: () => pref.set(!pref.useAI),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: pref.useAI,
              onChanged: (v) => pref.set(v),
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
