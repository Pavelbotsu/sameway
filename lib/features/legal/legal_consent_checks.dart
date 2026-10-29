import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/legal.dart';

/// The two attestations every account needs: 18+ and acceptance of the Terms
/// of Service + Privacy Policy. Controlled — the parent owns both values and
/// decides when to show [showError]. Used by signup and by TermsGateScreen.
class LegalConsentChecks extends StatelessWidget {
  final bool ageConfirmed;
  final bool termsAccepted;
  final ValueChanged<bool> onAgeChanged;
  final ValueChanged<bool> onTermsChanged;
  final bool showError;
  final Color accent;

  const LegalConsentChecks({
    super.key,
    required this.ageConfirmed,
    required this.termsAccepted,
    required this.onAgeChanged,
    required this.onTermsChanged,
    this.showError = false,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckRow(
          value: ageConfirmed,
          label: l.ageConfirmLabel,
          onChanged: onAgeChanged,
          accent: accent,
        ),
        _CheckRow(
          value: termsAccepted,
          label: l.acceptTermsLabel,
          onChanged: onTermsChanged,
          accent: accent,
        ),
        // Links on their own line: each language orders "Terms … and …
        // Privacy" differently, so inline links inside the sentence would
        // need per-language markup.
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Wrap(
            spacing: 4,
            children: [
              _LinkButton(label: l.termsOfService, url: kTermsUrl, color: accent),
              const Text('·', style: TextStyle(color: AppColors.textSecondary)),
              _LinkButton(label: l.privacyPolicy, url: kPrivacyPolicyUrl, color: accent),
            ],
          ),
        ),
        if (showError && !(ageConfirmed && termsAccepted))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
            child: Text(
              l.consentRequiredError,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final Color accent;

  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // MergeSemantics + the whole row tappable: screen readers announce one
    // "checkbox, <label>, checked" control instead of an unlabeled box.
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: accent,
                side: const BorderSide(color: AppColors.textSecondary),
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final String url;
  final Color color;

  const _LinkButton({required this.label, required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openLegalUrl(url),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
