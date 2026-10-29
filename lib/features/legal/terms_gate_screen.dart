import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/error_handling.dart';
import '../../core/widgets/branded_snack_bar.dart';
import '../auth/auth_provider.dart';
import '../driver/driver_home_screen.dart';
import '../onboarding/role_selection_screen.dart';
import '../passenger/passenger_home_screen.dart';
import 'legal_consent_checks.dart';

/// Blocks a signed-in account that hasn't accepted the current Terms of
/// Service / Privacy Policy or confirmed 18+ (accounts created before consent
/// existed, or after a kTermsVersion bump). The only ways out are accepting
/// or signing out.
class TermsGateScreen extends StatefulWidget {
  final String role;
  const TermsGateScreen({super.key, required this.role});

  /// Where to send a freshly authenticated user: the gate if consent is still
  /// owed, otherwise straight to the role's home screen.
  static Widget destination({required String role, required bool needsConsent}) {
    if (needsConsent) return TermsGateScreen(role: role);
    return homeFor(role);
  }

  static Widget homeFor(String role) =>
      role == 'driver' ? const DriverHomeScreen() : const PassengerHomeScreen();

  @override
  State<TermsGateScreen> createState() => _TermsGateScreenState();
}

class _TermsGateScreenState extends State<TermsGateScreen> {
  bool _age = false;
  bool _terms = false;
  bool _showError = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!(_age && _terms)) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().acceptTerms();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TermsGateScreen.homeFor(widget.role)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      BrandedSnack.showError(context, friendlyError(context, e));
      setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.primary, size: 40),
                const SizedBox(height: 16),
                Text(l.termsGateTitle,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 12),
                Text(
                  l.termsGateBody,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 28),
                LegalConsentChecks(
                  ageConfirmed: _age,
                  termsAccepted: _terms,
                  onAgeChanged: (v) => setState(() => _age = v),
                  onTermsChanged: (v) => setState(() => _terms = v),
                  showError: _showError,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _saving ? null : _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(l.continueLabel,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _signOut,
                    child: Text(l.signOut,
                        style: const TextStyle(color: AppColors.textSecondary)),
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
