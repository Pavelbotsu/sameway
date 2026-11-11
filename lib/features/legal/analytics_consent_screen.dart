import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/consent_service.dart';
import '../../core/legal.dart';

/// First-launch question about optional analytics / crash reports /
/// performance data. Shown once per device by SplashScreen; the answer can be
/// changed later in Account & Security. "Allow" and "No thanks" get equal
/// weight — consent must be as easy to refuse as to give.
class AnalyticsConsentScreen extends StatefulWidget {
  const AnalyticsConsentScreen({super.key});

  @override
  State<AnalyticsConsentScreen> createState() => _AnalyticsConsentScreenState();
}

class _AnalyticsConsentScreenState extends State<AnalyticsConsentScreen> {
  bool _saving = false;

  Future<void> _choose(bool granted) async {
    setState(() => _saving = true);
    await ConsentService.set(granted);
    if (mounted) Navigator.of(context).pop(granted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_outlined,
                    color: AppColors.teal, size: 40),
                const SizedBox(height: 16),
                Text(l.analyticsConsentTitle,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 12),
                Text(
                  l.analyticsConsentBody,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => openLegalUrl(context, kPrivacyPolicyUrl),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    l.privacyPolicy,
                    style: const TextStyle(
                      color: AppColors.teal,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _choose(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: buttonShape,
                    ),
                    child: Text(l.analyticsAllow,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _choose(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: buttonShape,
                    ),
                    child: Text(l.analyticsDeny,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
