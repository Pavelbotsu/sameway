import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/error_handling.dart';
import '../../core/token_storage.dart';
import '../../core/widgets/branded_snack_bar.dart';
import '../../core/widgets/car_edit_sheet.dart';

/// What the backend still needs before a driver may publish a route or a
/// planned trip (see handlers.driverReady).
enum DriverSetupNeed { declaration, carDetails }

/// Maps the backend's error code to a setup step, or null if unrelated.
DriverSetupNeed? driverSetupNeedFor(Object e) {
  if (e is! ApiException) return null;
  return switch (e.code) {
    'driver_declaration_required' => DriverSetupNeed.declaration,
    'car_details_required' => DriverSetupNeed.carDetails,
    _ => null,
  };
}

/// Shows the sheet for [need]. Returns true when the user completed it, so
/// the caller can retry the original request.
Future<bool> resolveDriverSetup(BuildContext context, DriverSetupNeed need) async {
  switch (need) {
    case DriverSetupNeed.declaration:
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DriverDeclarationSheet(),
      );
      return ok == true;
    case DriverSetupNeed.carDetails:
      BrandedSnack.showInfo(context, AppLocalizations.of(context).carDetailsRequired);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CarEditSheet(),
      );
      // The sheet saves on its own; the retry tells whether it was enough.
      return true;
  }
}

/// Runs [request] and walks the driver through any missing setup step
/// (declaration, then car details), retrying after each. Returns the
/// request's error if it still fails, or null on success.
Future<Object?> withDriverSetup(
    BuildContext context, Future<void> Function() request) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      await request();
      return null;
    } catch (e) {
      final need = driverSetupNeedFor(e);
      if (need == null || !context.mounted) return e;
      if (!await resolveDriverSetup(context, need)) return e;
      if (!context.mounted) return e;
    }
  }
  return null;
}

/// The driver's self-declaration: licence, insurance, roadworthy car,
/// cost-sharing only. Same model as BlaBlaCar (no document check). Pops
/// true once the backend recorded it.
class DriverDeclarationSheet extends StatefulWidget {
  const DriverDeclarationSheet({super.key});

  @override
  State<DriverDeclarationSheet> createState() => _DriverDeclarationSheetState();
}

class _DriverDeclarationSheetState extends State<DriverDeclarationSheet> {
  final _checked = [false, false, false, false];
  bool _showError = false;
  bool _saving = false;

  Future<void> _confirm() async {
    if (_checked.contains(false)) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient(TokenStorage()).post('/auth/driver-declaration', {
        'licence': true,
        'insurance': true,
        'roadworthy': true,
        'cost_sharing': true,
      }, auth: true);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      BrandedSnack.showError(context, friendlyError(context, e));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [
      l.driverDeclLicence,
      l.driverDeclInsurance,
      l.driverDeclRoadworthy,
      l.driverDeclCostSharing,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.driverDeclTitle,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.driverDeclBody,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),
            for (var i = 0; i < labels.length; i++)
              CheckboxListTile(
                value: _checked[i],
                onChanged: (v) => setState(() => _checked[i] = v ?? false),
                title: Text(labels[i],
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
            if (_showError && _checked.contains(false))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.driverDeclAllRequired,
                    style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
          ],
        ),
      ),
    );
  }
}
