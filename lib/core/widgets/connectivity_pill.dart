import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import '../app_localizations.dart';
import '../connectivity_provider.dart';
import '../websocket_client.dart';

/// Small top-anchored pill that surfaces network state to the user. Two
/// distinct flavors:
///   - **Red** ("No internet") — the device has no network at all
///   - **Amber** ("Reconnecting…") — device is online but our WebSocket has
///     dropped and the client is mid-backoff
///
/// The amber branch is intentionally debounced by [_reconnectGrace]: the
/// realtime socket cycles through brief disconnects all the time (a backoff
/// reconnect, a tunnel hiccup, the app resuming) and those recover within a
/// second or two. Surfacing every blip made the pill feel permanently stuck on
/// "Reconnecting…". We only show it once the socket has been unhealthy for the
/// full grace window — a genuine outage — and hide it the instant it recovers.
/// The red "No internet" branch is *not* debounced: a dead radio is an
/// unambiguous, immediately useful signal.
///
/// Designed to be dropped into a Stack just above the home-screen content.
/// Reads the per-role WS state directly from a `wsState` parameter so the
/// caller can choose between [DriverProvider.wsState] and
/// [PassengerProvider.wsState] without this widget needing to know about
/// either.
class ConnectivityPill extends StatefulWidget {
  final WsState wsState;
  const ConnectivityPill({super.key, required this.wsState});

  @override
  State<ConnectivityPill> createState() => _ConnectivityPillState();
}

class _ConnectivityPillState extends State<ConnectivityPill> {
  static const _reconnectGrace = Duration(seconds: 3);

  Timer? _graceTimer;
  bool _graceElapsed = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void didUpdateWidget(ConnectivityPill old) {
    super.didUpdateWidget(old);
    if (old.wsState != widget.wsState) _evaluate();
  }

  /// Drives the debounce. While the socket is unhealthy we arm a one-shot
  /// timer; only when it fires do we let the amber pill appear. Recovery
  /// cancels the timer and clears the flag so the next blip starts fresh.
  void _evaluate() {
    final healthy = widget.wsState == WsState.connected;
    if (healthy) {
      _graceTimer?.cancel();
      _graceTimer = null;
      if (_graceElapsed) setState(() => _graceElapsed = false);
      return;
    }
    // Already showing, or already counting down — nothing to do.
    if (_graceElapsed || _graceTimer != null) return;
    _graceTimer = Timer(_reconnectGrace, () {
      _graceTimer = null;
      if (mounted) setState(() => _graceElapsed = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final offline = !isOnline;
    final wsHealthy = widget.wsState == WsState.connected;

    // Red shows immediately; amber only after the grace window has elapsed.
    final show = offline || (!wsHealthy && _graceElapsed);
    if (!show) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final color = offline ? AppColors.error : const Color(0xFFFFB938);
    final label = offline ? l.noInternet : l.reconnecting;
    final icon = offline
        ? Icons.signal_wifi_off_rounded
        : Icons.sync_rounded;

    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 8,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(offline),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
