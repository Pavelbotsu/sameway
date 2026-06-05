import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../token_storage.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/driver/driver_provider.dart';
import '../../features/passenger/passenger_provider.dart';

class RoleSwitchSheet extends StatefulWidget {
  final String currentRole; // 'driver' | 'passenger'
  final VoidCallback onSwitched;

  const RoleSwitchSheet({
    super.key,
    required this.currentRole,
    required this.onSwitched,
  });

  @override
  State<RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

class _RoleSwitchSheetState extends State<RoleSwitchSheet> {
  bool _loading = false;

  // Returns null if no confirmation is needed, otherwise the human-readable
  // reason the current role has live state that will be terminated.
  String? _liveStateReason() {
    if (widget.currentRole == 'driver') {
      final driver = context.read<DriverProvider?>();
      if (driver == null) return null;
      if (driver.activeRoute != null) return 'active driver route';
      if (driver.acceptedRequestId != null) return 'accepted passenger ride';
    } else {
      final passenger = context.read<PassengerProvider?>();
      if (passenger == null) return null;
      if (passenger.acceptedRequestId != null) return 'accepted driver ride';
      if (passenger.outstandingRequests.isNotEmpty) {
        return 'pending ride requests';
      }
      if (passenger.isSearching) return 'active destination search';
    }
    return null;
  }

  Future<bool> _confirmEndLiveState(String reason) async {
    final isDriver = widget.currentRole == 'driver';
    final actionLabel = isDriver
        ? 'End route & switch'
        : 'Cancel requests & switch';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          isDriver ? 'End your driver route?' : 'Cancel passenger search?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You have an $reason. Switching will end it and notify the other party.',
          style: const TextStyle(
              color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isDriver ? 'Stay as driver' : 'Stay as passenger',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionLabel,
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _doSwitch() async {
    // Capture providers up-front so we can safely await without the analyzer
    // flagging context-across-async-gap.
    final driver = context.read<DriverProvider?>();
    final passenger = context.read<PassengerProvider?>();

    final reason = _liveStateReason();
    if (reason != null) {
      final ok = await _confirmEndLiveState(reason);
      if (!ok) return;
    }

    final other = widget.currentRole == 'driver' ? 'passenger' : 'driver';
    setState(() => _loading = true);
    try {
      // Reset the *outgoing* role's client-side state before we hop screens so
      // the next screen lands clean and any next render doesn't show stale UI.
      // The backend already deleted the corresponding active_* row in
      // SwitchRole, so this is a UI-only clean.
      if (widget.currentRole == 'driver') {
        await driver?.deleteRoute();
      } else {
        await passenger?.goOffline();
      }

      final api = ApiClient(TokenStorage());
      final result = await AuthRepository(api).switchRole(role: other);
      await TokenStorage().save(
        token: result.token,
        role: result.role,
        userId: result.userId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSwitched();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to switch role: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDriver = widget.currentRole == 'driver';
    final currentColor = isDriver ? AppColors.primary : AppColors.teal;
    final otherColor = isDriver ? AppColors.teal : AppColors.primary;
    final currentIcon =
        isDriver ? Icons.drive_eta_rounded : Icons.person_rounded;
    final otherIcon =
        isDriver ? Icons.person_rounded : Icons.drive_eta_rounded;
    final currentLabel = isDriver ? l.driver : l.passenger;
    final otherLabel =
        isDriver ? l.switchToPassenger : l.switchToDriver;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
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
          Text(
            l.switchRoleTo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: currentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: currentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(currentIcon, color: currentColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${l.currentRole}: ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  currentLabel,
                  style: TextStyle(
                    color: currentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _doSwitch,
              style: ElevatedButton.styleFrom(
                backgroundColor: otherColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(otherIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          otherLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
